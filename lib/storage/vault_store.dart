import 'dart:typed_data';

/// Là où vivent les octets chiffrés du coffre.
///
/// L'interface existe pour que la session ne dépende pas du système de
/// fichiers: l'implémentation réelle est [VaultFile], et les tests d'interface
/// branchent une version en mémoire — les entrées/sorties réelles ne se
/// terminent jamais sous l'horloge simulée des tests de widgets.
abstract interface class VaultStore {
  /// Un coffre existe-t-il déjà ?
  Future<bool> exists();

  /// Rend les octets du coffre; lève si aucun coffre n'existe.
  Future<Uint8List> read();

  /// Remplace le coffre par [bytes], sans état intermédiaire observable.
  ///
  /// [keepPrevious] à `false` interdit de conserver la génération précédente:
  /// après un changement de mot de passe, une copie que l'ancien mot de passe
  /// ouvre encore annulerait le changement.
  Future<void> write(Uint8List bytes, {bool keepPrevious = true});
}
