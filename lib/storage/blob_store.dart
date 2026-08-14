import 'dart:io';
import 'dart:typed_data';

/// Où vivent les pièces jointes chiffrées, une par identifiant.
///
/// Séparé de [VaultStore] parce que les contraintes diffèrent: le coffre est
/// réécrit en entier à chaque modification, un blob est écrit une fois et lu à
/// la demande.
abstract interface class BlobStore {
  Future<void> put(String id, Uint8List bytes);

  /// Lève si le blob n'existe pas.
  Future<Uint8List> get(String id);

  /// Sans effet si le blob a déjà disparu.
  Future<void> delete(String id);

  /// Identifiants présents; sert au nettoyage des orphelins.
  Future<Set<String>> ids();
}

/// Pièces jointes sur le disque, dans `<coffre>/blobs/`.
class BlobFileStore implements BlobStore {
  BlobFileStore(this.directory);

  final Directory directory;

  File _file(String id) => File('${directory.path}/$id.blob');

  @override
  Future<void> put(String id, Uint8List bytes) async {
    await directory.create(recursive: true);
    final temp = File('${directory.path}/$id.blob.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(_file(id).path);
  }

  @override
  Future<Uint8List> get(String id) => _file(id).readAsBytes();

  @override
  Future<void> delete(String id) async {
    final file = _file(id);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<Set<String>> ids() async {
    if (!await directory.exists()) {
      return {};
    }
    return {
      for (final entity in directory.listSync())
        if (entity is File && entity.path.endsWith('.blob'))
          entity.uri.pathSegments.last.replaceAll('.blob', ''),
    };
  }
}
