import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:sodium/sodium_sumo.dart';

import '../crypto/vault_crypto.dart';
import '../model/vault.dart';
import '../storage/blob_store.dart';
import '../storage/vault_store.dart';
import '../util/clipboard.dart';

/// Taille maximale d'une pièce jointe.
///
/// Une pièce jointe est déchiffrée d'un bloc en mémoire à l'ouverture: au-delà
/// de cette taille, l'app se ferait tuer sur un téléphone modeste.
const int maxAttachmentBytes = 25 * 1024 * 1024;

/// Levée quand un fichier dépasse [maxAttachmentBytes].
class AttachmentTooLargeException implements Exception {
  const AttachmentTooLargeException(this.size);

  /// Taille refusée, en octets.
  final int size;

  @override
  String toString() =>
      'AttachmentTooLargeException($size > $maxAttachmentBytes)';
}

/// État du coffre pour toute l'application: verrouillé ou déverrouillé.
///
/// Détient la clé dérivée tant que la session est ouverte, ce qui évite de
/// repayer Argon2id à chaque sauvegarde. Le mot de passe lui-même n'est jamais
/// conservé.
class VaultSession extends ChangeNotifier {
  VaultSession({
    required VaultCrypto crypto,
    required VaultStore storage,
    required BlobStore blobs,
    required SecureClipboard clipboard,
    Duration autoLockDelay = const Duration(minutes: 2),
    KdfParams kdfParams = KdfParams.defaults,
  }) : _crypto = crypto,
       _storage = storage,
       _blobs = blobs,
       _clipboard = clipboard,
       _autoLockDelay = autoLockDelay,
       _kdfParams = kdfParams;

  final VaultCrypto _crypto;
  final VaultStore _storage;
  final BlobStore _blobs;
  final SecureClipboard _clipboard;
  final KdfParams _kdfParams;

  Duration _autoLockDelay;
  Timer? _autoLockTimer;

  /// Numéro de la session ouverte, incrémenté à chaque verrouillage.
  ///
  /// Une écriture dure: le coffre peut être verrouillé pendant qu'elle est en
  /// vol. Sans ce jeton, la suite de l'écriture réaffecte `_vault` et rouvre le
  /// coffre après coup — contenu déchiffré réaffiché, alors que la clé, elle, a
  /// bien été libérée. Chaque opération relève le numéro avant son `await` et
  /// abandonne son effet en mémoire s'il a changé.
  int _generation = 0;

  /// File d'attente des écritures.
  ///
  /// Deux sauvegardes en vol en même temps se marchent dessus: chacune part
  /// d'une photo du coffre prise avant son attente, et la dernière arrivée
  /// écrase les modifications de l'autre. Elles sont donc enchaînées, et toute
  /// modification calcule son nouveau coffre *dans* la file, à partir de l'état
  /// courant.
  Future<void> _writes = Future<void>.value();

  /// Depuis quand l'utilisateur n'a rien fait.
  ///
  /// Deux horloges, parce qu'aucune ne suffit seule: le `Stopwatch` est
  /// monotone et resiste a un changement d'heure systeme, mais il n'avance pas
  /// pendant la veille profonde d'Android; l'horloge murale couvre la veille,
  /// mais recule si on change l'heure. On retient l'ecart le plus grand des
  /// deux, ce qui verrouille toujours au plus tot.
  final Stopwatch _idleWatch = Stopwatch();
  DateTime _lastActivity = DateTime.now();
  SecureKey? _key;
  Uint8List? _salt;
  KdfParams? _fileParams;
  Vault? _vault;

  /// Contenu déchiffré, ou `null` quand le coffre est verrouillé.
  Vault? get vault => _vault;

  bool get isUnlocked => _vault != null;

  Duration get autoLockDelay => _autoLockDelay;

  /// Change le délai d'inactivité et réarme la minuterie en cours.
  set autoLockDelay(Duration value) {
    _autoLockDelay = value;
    if (isUnlocked) {
      // Repartir de la dernière activité, pas de maintenant: choisir « 30 s »
      // dans les réglages ne doit pas offrir 30 s de sursis supplémentaire.
      final remaining = value - idleTime;
      _autoLockTimer?.cancel();
      _autoLockTimer = remaining.isNegative
          ? Timer(Duration.zero, lock)
          : Timer(remaining, lock);
    }
    notifyListeners();
  }

  /// Y a-t-il déjà un coffre sur le disque ? Décide entre création et
  /// déverrouillage au démarrage.
  Future<bool> vaultExists() => _storage.exists();

  /// Crée un coffre vide protégé par [password] et ouvre la session.
  Future<void> create(String password) async {
    final salt = _crypto.newSalt();
    final key = _crypto.deriveKey(password, salt, _kdfParams);
    const empty = Vault([]);
    final generation = _generation;
    try {
      await _storage.write(_crypto.seal(empty, key, salt, _kdfParams));
    } catch (_) {
      key.dispose();
      rethrow;
    }
    if (generation != _generation) {
      key.dispose();
      return;
    }
    _adopt(key: key, salt: salt, params: _kdfParams, vault: empty);
  }

  /// Ouvre le coffre existant.
  ///
  /// Lève [WrongPasswordException] si le mot de passe ne convient pas, et
  /// [FormatException] si le fichier n'est pas un coffre lisible.
  Future<void> unlock(String password) async {
    final bytes = await _storage.read();
    final header = VaultHeader.parse(bytes);
    final key = _crypto.deriveKey(password, header.salt, header.params);
    final Vault opened;
    try {
      opened = _crypto.openWithKey(bytes, key);
    } catch (_) {
      key.dispose();
      rethrow;
    }
    _adopt(
      key: key,
      salt: header.salt,
      params: header.params,
      vault: opened,
    );
    await purgeOrphanBlobs();
  }

  /// Ferme la session: clé libérée, contenu oublié, presse-papier nettoyé.
  void lock() {
    _generation++;
    _autoLockTimer?.cancel();
    _autoLockTimer = null;
    _key?.dispose();
    _key = null;
    _salt = null;
    _fileParams = null;
    _vault = null;
    unawaited(_clipboard.clearNow());
    notifyListeners();
  }

  /// Chiffre et écrit [vault], puis en fait le contenu courant.
  ///
  /// Si le coffre est verrouillé pendant l'écriture, celle-ci va jusqu'au bout
  /// — ce qui est écrit reste écrit — mais la session ne se rouvre pas.
  Future<void> save(Vault vault) {
    // Chiffré tout de suite, mis en file ensuite: le coffre peut être
    // verrouillé — et la clé libérée — avant que la file ne se libère, alors
    // que la sauvegarde, elle, a bien été demandée avant.
    final sealed = _seal(vault);
    final generation = _generation;
    return _serialized(() => _commit(vault, sealed, generation));
  }

  /// Enchaîne [action] derrière les écritures déjà en cours.
  ///
  /// L'erreur est rendue à l'appelant, mais ne bloque pas la file: une écriture
  /// ratée ne doit pas condamner les suivantes.
  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _writes.then((_) => action());
    _writes = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Modifie le coffre à partir de son état courant, une fois la file libre.
  ///
  /// [change] n'est appelée qu'au moment d'écrire: elle voit donc l'état réel,
  /// pas une photo prise avant l'attente. Lève si le coffre a été verrouillé
  /// entre-temps — on ne modifie pas un coffre fermé.
  Future<void> _mutate(Vault Function(Vault current) change) =>
      _serialized(() {
        final current = _vault;
        if (current == null) {
          throw StateError('Le coffre est verrouillé');
        }
        final next = change(current);
        return _commit(next, _seal(next), _generation);
      });

  /// Chiffre [vault] avec la clé de session. Lève si le coffre est verrouillé.
  Uint8List _seal(Vault vault) {
    final key = _key;
    final salt = _salt;
    final params = _fileParams;
    if (key == null || salt == null || params == null) {
      throw StateError('Le coffre est verrouillé');
    }
    return _crypto.seal(vault, key, salt, params);
  }

  /// Écrit les octets déjà chiffrés, puis adopte [vault] — sauf si la session
  /// a été verrouillée depuis [generation].
  Future<void> _commit(Vault vault, Uint8List sealed, int generation) async {
    await _storage.write(sealed);
    if (generation != _generation) {
      return;
    }
    _vault = vault;
    _restartAutoLock();
    notifyListeners();
  }

  /// Ré-chiffre le coffre courant sous [newPassword], avec un sel neuf.
  ///
  /// Comme [save]: le chiffrement se fait tout de suite, seule l'écriture passe
  /// par la file. Un verrouillage pendant l'écriture ne l'annule donc pas — le
  /// nouveau mot de passe est bien celui du fichier — mais ne rouvre pas la
  /// session.
  Future<void> changePassword(String newPassword) {
    final current = _vault;
    if (current == null) {
      throw StateError('Le coffre est verrouillé');
    }
    final salt = _crypto.newSalt();
    final key = _crypto.deriveKey(newPassword, salt, _kdfParams);
    final Uint8List sealed;
    try {
      sealed = _crypto.seal(current, key, salt, _kdfParams);
    } catch (_) {
      key.dispose();
      rethrow;
    }
    final generation = _generation;
    return _serialized(() async {
      try {
        // Pas de copie de l'ancienne génération: l'ancien mot de passe
        // l'ouvrirait encore, et changer de mot de passe se fait justement
        // parce qu'il a fuité.
        await _storage.write(sealed, keepPrevious: false);
      } catch (_) {
        key.dispose();
        rethrow;
      }
      if (generation != _generation) {
        key.dispose();
        return;
      }
      _adopt(key: key, salt: salt, params: _kdfParams, vault: current);
    });
  }

  /// Attache un fichier à l'entrée [entryKey].
  ///
  /// Le contenu part chiffré dans son propre blob; seules ses métadonnées
  /// entrent dans le coffre. Lève [AttachmentTooLargeException] au-delà de
  /// [maxAttachmentBytes], et [StateError] si la clef n'existe pas.
  Future<VaultAttachment> attach({
    required String entryKey,
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    if (bytes.length > maxAttachmentBytes) {
      throw AttachmentTooLargeException(bytes.length);
    }
    final key = _key;
    final vault = _vault;
    if (key == null || vault == null) {
      throw StateError('Le coffre est verrouillé');
    }
    if (vault.entries.where((e) => e.key == entryKey).isEmpty) {
      throw StateError('Aucune entrée nommée $entryKey');
    }

    final attachment = VaultAttachment(
      id: _crypto.newBlobId(),
      name: name,
      mimeType: mimeType,
      size: bytes.length,
      created: DateTime.now().toUtc(),
    );
    // Le blob d'abord, la référence ensuite: l'ordre inverse laisserait le
    // coffre pointer vers un fichier absent si l'écriture échouait.
    await _blobs.put(attachment.id, _crypto.sealBytes(bytes, key));
    await _mutate((current) {
      // Relu ici et pas plus haut: écrire une pièce jointe prend du temps, et
      // l'utilisateur a pu enregistrer autre chose entre-temps.
      final entry = current.entries.where((e) => e.key == entryKey).firstOrNull;
      if (entry == null) {
        throw StateError('Aucune entrée nommée $entryKey');
      }
      return current.upsert(
        VaultEntry(
          key: entry.key,
          value: entry.value,
          created: entry.created,
          updated: DateTime.now().toUtc(),
          attachments: [...entry.attachments, attachment],
        ),
      );
    });
    return attachment;
  }

  /// Déchiffre le contenu d'une pièce jointe.
  Future<Uint8List> readAttachment(VaultAttachment attachment) async {
    final key = _key;
    if (key == null) {
      throw StateError('Le coffre est verrouillé');
    }
    return _crypto.openBytes(await _blobs.get(attachment.id), key);
  }

  /// Détache un fichier et efface son blob.
  Future<void> removeAttachment({
    required String entryKey,
    required VaultAttachment attachment,
  }) async {
    // La référence d'abord, le blob ensuite: si l'effacement échoue, il ne
    // reste qu'un orphelin, nettoyé au prochain déverrouillage.
    await _mutate((current) {
      final entry = current.entries.where((e) => e.key == entryKey).firstOrNull;
      if (entry == null) {
        throw StateError('Aucune entrée nommée $entryKey');
      }
      return current.upsert(
        VaultEntry(
          key: entry.key,
          value: entry.value,
          created: entry.created,
          updated: DateTime.now().toUtc(),
          attachments: [
            for (final existing in entry.attachments)
              if (existing.id != attachment.id) existing,
          ],
        ),
      );
    });
    await _blobs.delete(attachment.id);
  }

  /// Supprime une entrée et toutes ses pièces jointes.
  Future<void> deleteEntry(String entryKey) async {
    var detachees = const <VaultAttachment>[];
    await _mutate((current) {
      detachees =
          current.entries.where((e) => e.key == entryKey).firstOrNull
              ?.attachments ??
          const <VaultAttachment>[];
      return current.remove(entryKey);
    });
    for (final attachment in detachees) {
      await _blobs.delete(attachment.id);
    }
  }

  /// Met de côté les blobs qu'aucune entrée ne référence, et rend leur nombre.
  ///
  /// Une écriture interrompue entre le blob et le coffre laisse un orphelin.
  /// Mais un blob peut être orphelin sans être du déchet: après un import — le
  /// seul chemin de synchronisation entre Linux et Android, et l'export ne
  /// contient pas les pièces jointes — tous ceux de l'ancien coffre le
  /// deviennent d'un coup. Les effacer détruirait définitivement des pièces
  /// jointes que personne n'a demandé à supprimer, alors elles sont déplacées
  /// dans `blobs/orphelins/`.
  ///
  /// Les temporaires d'un `put` interrompu, eux, sont effacés: ils sont
  /// incomplets et ne valent rien.
  Future<int> purgeOrphanBlobs() async {
    final vault = _vault;
    if (vault == null) {
      return 0;
    }
    final referenced = {
      for (final entry in vault.entries)
        for (final attachment in entry.attachments) attachment.id,
    };
    await _blobs.sweepTemporaries();
    var removed = 0;
    for (final id in await _blobs.ids()) {
      if (!referenced.contains(id)) {
        await _blobs.quarantine(id);
        removed++;
      }
    }
    return removed;
  }

  /// Signale une activité de l'utilisateur: repousse le verrouillage.
  void touch() {
    if (isUnlocked) {
      _restartAutoLock();
    }
  }

  /// Temps écoulé depuis la dernière activité réelle.
  Duration get idleTime {
    final monotonic = _idleWatch.elapsed;
    final wall = DateTime.now().difference(_lastActivity);
    return wall > monotonic ? wall : monotonic;
  }

  /// Passer en arrière-plan ne verrouille pas: seul le délai d'inactivité
  /// décide.
  ///
  /// Le temps passé en arrière-plan compte comme de l'inactivité. La minuterie
  /// continue de tourner, mais Android peut geler le processus et l'empêcher de
  /// se déclencher: au retour, on recalcule donc l'inactivité réelle plutôt que
  /// de faire confiance à la minuterie.
  ///
  /// La contrepartie — un coffre ouvert survit en arrière-plan — est compensée
  /// par `FLAG_SECURE` côté Android, qui vide la vignette du sélecteur
  /// d'applications.
  ///
  /// `detached` reste un verrouillage immédiat: le processus s'arrête.
  void handleLifecycle(AppLifecycleState state) {
    if (!isUnlocked) {
      return;
    }
    if (state == AppLifecycleState.detached) {
      lock();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      if (idleTime >= _autoLockDelay) {
        lock();
      } else {
        // Réarmer sur le temps restant, sans remettre le compteur à zéro:
        // revenir sur l'app n'est pas une activité.
        _autoLockTimer?.cancel();
        _autoLockTimer = Timer(_autoLockDelay - idleTime, lock);
      }
    }
  }

  void _adopt({
    required SecureKey key,
    required Uint8List salt,
    required KdfParams params,
    required Vault vault,
  }) {
    _key?.dispose();
    _key = key;
    _salt = salt;
    _fileParams = params;
    _vault = vault;
    _restartAutoLock();
    notifyListeners();
  }

  void _restartAutoLock() {
    _autoLockTimer?.cancel();
    _lastActivity = DateTime.now();
    _idleWatch
      ..reset()
      ..start();
    _autoLockTimer = Timer(_autoLockDelay, lock);
  }

  @override
  void dispose() {
    _autoLockTimer?.cancel();
    _key?.dispose();
    _key = null;
    _vault = null;
    _clipboard.dispose();
    super.dispose();
  }
}
