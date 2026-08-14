import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'vault_store.dart';

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
      final xdg = Platform.environment['XDG_DATA_HOME'];
      final base = (xdg != null && xdg.isNotEmpty)
          ? xdg
          : '${Platform.environment['HOME']}/.local/share';
      return Directory('$base/safe');
    }
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}/safe');
  }

  final Directory directory;

  File get file => File('${directory.path}/vault.safe');

  File get backupFile => File('${directory.path}/vault.safe.bak');

  File get _tempFile => File('${directory.path}/vault.safe.tmp');

  @override
  Future<bool> exists() => file.exists();

  /// Lève une [FileSystemException] si aucun coffre n'existe.
  @override
  Future<Uint8List> read() => file.readAsBytes();

  /// Remplace le coffre par [bytes], de façon atomique.
  ///
  /// Le `rename` final est atomique sur un même système de fichiers: à tout
  /// instant, `vault.safe` est soit l'ancien contenu complet, soit le nouveau.
  @override
  Future<void> write(Uint8List bytes) async {
    await directory.create(recursive: true);
    final handle = await _tempFile.open(mode: FileMode.writeOnly);
    try {
      await handle.writeFrom(bytes);
      await handle.flush();
    } finally {
      await handle.close();
    }
    if (await file.exists()) {
      await file.copy(backupFile.path);
    }
    await _tempFile.rename(file.path);
  }
}
