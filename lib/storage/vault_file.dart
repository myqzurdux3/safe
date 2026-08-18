import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'vault_store.dart';

import 'private_directory.dart';

/// Le fichier coffre sur le disque.
///
/// Ne sait rien du chiffrement: elle transporte des octets opaques. Sa seule
/// responsabilité est qu'une écriture interrompue ne laisse jamais un coffre à
/// moitié écrit.
class VaultFile implements VaultStore {
  VaultFile(this.directory);

  /// Dossier où vit le coffre, selon la plateforme.
  ///
  /// Linux: `$XDG_DATA_HOME/safe`, sinon `~/.local/share/safe`.
  /// Android: dossier privé de l'application — jamais le stockage externe, qui
  /// serait lisible par d'autres apps.
  static Future<Directory> defaultDirectory() async {
    if (Platform.isLinux) {
      return linuxDirectory(Platform.environment);
    }
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}/safe');
  }

  /// Le dossier Linux, déduit de [environment].
  ///
  /// Lève un [StateError] si ni `XDG_DATA_HOME` ni `HOME` ne sont définis:
  /// l'interpolation d'un `null` donnait le chemin littéral
  /// `null/.local/share/safe`, relatif au répertoire courant — le coffre
  /// atterrissait n'importe où sans que rien ne le signale.
  static Directory linuxDirectory(Map<String, String> environment) {
    final xdg = environment['XDG_DATA_HOME'];
    if (xdg != null && xdg.isNotEmpty) {
      return Directory('$xdg/safe');
    }
    final home = environment['HOME'];
    if (home == null || home.isEmpty) {
      throw StateError(
        'Impossible de situer le coffre: ni XDG_DATA_HOME ni HOME ne sont '
        'définis',
      );
    }
    return Directory('$home/.local/share/safe');
  }

  final Directory directory;

  File get file => File('${directory.path}/vault.safe');

  File get backupFile => File('${directory.path}/vault.safe.bak');

  /// Un temporaire par écriture: un nom fixe serait partagé par deux écritures
  /// qui se chevauchent, qui entrelaceraient alors leurs octets dans le même
  /// fichier, ou échoueraient au `rename` — la source ayant déjà été renommée
  /// par l'autre.
  File _newTempFile() => File('${directory.path}/vault.safe.${_writes++}.tmp');

  int _writes = 0;

  @override
  Future<bool> exists() => file.exists();

  /// Lève une [FileSystemException] si aucun coffre n'existe.
  @override
  Future<Uint8List> read() => file.readAsBytes();

  /// Remplace le coffre par [bytes], de façon atomique.
  ///
  /// Le `rename` final est atomique sur un même système de fichiers: à tout
  /// instant, `vault.safe` est soit l'ancien contenu complet, soit le nouveau.
  ///
  /// La copie de sauvegarde n'est pas là pour ça — le `rename` suffit — mais
  /// pour rattraper une suppression regrettée. Elle est donc supprimée quand
  /// [keepPrevious] est `false`.
  @override
  Future<void> write(Uint8List bytes, {bool keepPrevious = true}) async {
    await createPrivateDirectory(directory);
    final temp = _newTempFile();
    try {
      final handle = await temp.open(mode: FileMode.writeOnly);
      try {
        await handle.writeFrom(bytes);
        await handle.flush();
      } finally {
        await handle.close();
      }
      if (keepPrevious && await file.exists()) {
        await file.copy(backupFile.path);
      }
      await temp.rename(file.path);
      if (!keepPrevious && await backupFile.exists()) {
        // Effacée seulement après le `rename`: tant que le nouveau coffre n'est
        // pas en place, l'ancienne copie reste le seul filet.
        await backupFile.delete();
      }
    } catch (_) {
      // Une écriture qui échoue ne doit pas laisser son temporaire derrière
      // elle: personne ne le relira jamais, et il contient le coffre entier.
      if (await temp.exists()) {
        await temp.delete();
      }
      rethrow;
    }
  }
}
