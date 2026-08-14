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
      _restartAutoLock();
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
    await _storage.write(_crypto.seal(empty, key, salt, _kdfParams));
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
  Future<void> save(Vault vault) async {
    final key = _key;
    final salt = _salt;
    final params = _fileParams;
    if (key == null || salt == null || params == null) {
      throw StateError('Le coffre est verrouillé');
    }
    await _storage.write(_crypto.seal(vault, key, salt, params));
    _vault = vault;
    _restartAutoLock();
    notifyListeners();
  }

  /// Ré-chiffre le coffre courant sous [newPassword], avec un sel neuf.
  Future<void> changePassword(String newPassword) async {
    final current = _vault;
    if (current == null) {
      throw StateError('Le coffre est verrouillé');
    }
    final salt = _crypto.newSalt();
    final key = _crypto.deriveKey(newPassword, salt, _kdfParams);
    await _storage.write(_crypto.seal(current, key, salt, _kdfParams));
    _adopt(key: key, salt: salt, params: _kdfParams, vault: current);
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
    final entry = vault.entries.where((e) => e.key == entryKey).firstOrNull;
    if (entry == null) {
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
    await save(
      vault.upsert(
        VaultEntry(
          key: entry.key,
          value: entry.value,
          created: entry.created,
          updated: DateTime.now().toUtc(),
          attachments: [...entry.attachments, attachment],
        ),
      ),
    );
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
    final vault = _vault;
    if (vault == null) {
      throw StateError('Le coffre est verrouillé');
    }
    final entry = vault.entries.where((e) => e.key == entryKey).firstOrNull;
    if (entry == null) {
      throw StateError('Aucune entrée nommée $entryKey');
    }
    // La référence d'abord, le blob ensuite: si l'effacement échoue, il ne
    // reste qu'un orphelin, nettoyé au prochain déverrouillage.
    await save(
      vault.upsert(
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
      ),
    );
    await _blobs.delete(attachment.id);
  }

  /// Supprime une entrée et toutes ses pièces jointes.
  Future<void> deleteEntry(String entryKey) async {
    final vault = _vault;
    if (vault == null) {
      throw StateError('Le coffre est verrouillé');
    }
    final entry = vault.entries.where((e) => e.key == entryKey).firstOrNull;
    await save(vault.remove(entryKey));
    for (final attachment in entry?.attachments ?? const <VaultAttachment>[]) {
      await _blobs.delete(attachment.id);
    }
  }

  /// Efface les blobs qu'aucune entrée ne référence.
  ///
  /// Une écriture interrompue entre le blob et le coffre laisse un fichier
  /// orphelin: il occupe de la place et survit à la suppression de l'entrée.
  Future<int> purgeOrphanBlobs() async {
    final vault = _vault;
    if (vault == null) {
      return 0;
    }
    final referenced = {
      for (final entry in vault.entries)
        for (final attachment in entry.attachments) attachment.id,
    };
    var removed = 0;
    for (final id in await _blobs.ids()) {
      if (!referenced.contains(id)) {
        await _blobs.delete(id);
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

  /// Verrouille dès que l'application quitte le premier plan.
  ///
  /// `inactive` couvre le sélecteur d'applications d'Android, où le contenu
  /// serait autrement visible en vignette.
  void handleLifecycle(AppLifecycleState state) {
    if (!isUnlocked) {
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      lock();
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
