import 'dart:io';
import 'dart:typed_data';

import 'private_directory.dart';

/// Où vivent les pièces jointes chiffrées, une par identifiant.
///
/// Séparé de [VaultStore] parce que les contraintes diffèrent: le coffre est
/// réécrit en entier à chaque modification, un blob est écrit une fois et lu à
/// la demande.
/// Forme attendue d'un identifiant de blob: exactement les 16 octets tirés par
/// `VaultCrypto.newBlobId`, en hexadécimal.
final RegExp _blobIdShape = RegExp(r'^[0-9a-f]{32}$');

/// Vérifie qu'un identifiant ne peut pas désigner autre chose qu'un blob.
///
/// L'identifiant vient du contenu du coffre, qui est authentifié — mais pas
/// forcément écrit par nous: `VaultTransfer.importBytes` accepte un fichier
/// fourni par un tiers avec son mot de passe. Sans cette garde, un identifiant
/// comme `../../secret` fait lire, écrire ou **effacer** un fichier hors du
/// dossier des pièces jointes.
String checkBlobId(String id) {
  if (!_blobIdShape.hasMatch(id)) {
    throw ArgumentError.value(id, 'id', 'Identifiant de pièce jointe invalide');
  }
  return id;
}

abstract interface class BlobStore {
  Future<void> put(String id, Uint8List bytes);

  /// Lève si le blob n'existe pas.
  Future<Uint8List> get(String id);

  /// Sans effet si le blob a déjà disparu.
  Future<void> delete(String id);

  /// Met un blob de côté au lieu de l'effacer.
  ///
  /// Pour les orphelins trouvés automatiquement: le contenu ne se rattrape pas,
  /// et un blob peut être orphelin sans être du déchet — après un import, tous
  /// ceux de l'ancien coffre le deviennent d'un coup.
  Future<void> quarantine(String id);

  /// Efface les temporaires laissés par un [put] interrompu, et rend leur
  /// nombre. Eux sont du déchet certain: incomplets et référencés par personne.
  Future<int> sweepTemporaries();

  /// Identifiants présents; sert au nettoyage des orphelins.
  Future<Set<String>> ids();
}

/// Pièces jointes sur le disque, dans `<coffre>/blobs/`.
class BlobFileStore implements BlobStore {
  BlobFileStore(this.directory);

  final Directory directory;

  File _file(String id) => File('${directory.path}/${checkBlobId(id)}.blob');

  @override
  Future<void> put(String id, Uint8List bytes) async {
    final destination = _file(id);
    await createPrivateDirectory(directory);
    final temp = File('${destination.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(destination.path);
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

  /// Où vont les orphelins: à côté, pas à la poubelle.
  Directory get quarantineDirectory => Directory('${directory.path}/orphelins');

  @override
  Future<void> quarantine(String id) async {
    final source = _file(id);
    if (!await source.exists()) {
      return;
    }
    await createPrivateDirectory(quarantineDirectory);
    await source.rename('${quarantineDirectory.path}/$id.blob');
  }

  @override
  Future<int> sweepTemporaries() async {
    if (!await directory.exists()) {
      return 0;
    }
    var efface = 0;
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.endsWith('.blob.tmp')) {
        await entity.delete();
        efface++;
      }
    }
    return efface;
  }

  @override
  Future<Set<String>> ids() async {
    if (!await directory.exists()) {
      return {};
    }
    const suffixe = '.blob';
    final trouves = <String>{};
    // `list` et non `listSync`: appelé au déverrouillage, juste après une
    // dérivation déjà coûteuse, et sur l'isolat qui dessine l'interface.
    await for (final entity in directory.list()) {
      final name = entity.uri.pathSegments.last;
      if (entity is File && name.endsWith(suffixe)) {
        // `substring` et non `replaceAll`, qui retirerait *toutes* les
        // occurrences du suffixe.
        trouves.add(name.substring(0, name.length - suffixe.length));
      }
    }
    return trouves;
  }
}
