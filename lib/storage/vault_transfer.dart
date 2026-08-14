import 'dart:typed_data';

import '../crypto/vault_crypto.dart';
import 'vault_store.dart';

/// Export et import du coffre chiffré.
///
/// L'export sort le fichier tel quel: sans le mot de passe il ne vaut rien,
/// donc il peut voyager par n'importe quel canal. C'est le seul chemin de
/// synchronisation entre Linux et Android, assumé manuel.
class VaultTransfer {
  VaultTransfer({required VaultCrypto crypto, required VaultStore storage})
    : _crypto = crypto,
      _storage = storage;

  final VaultCrypto _crypto;
  final VaultStore _storage;

  /// Rend les octets chiffrés du coffre courant.
  Future<Uint8List> exportBytes() => _storage.read();

  /// Remplace le coffre courant par [bytes].
  ///
  /// Le déchiffrement est vérifié **avant** toute écriture: un mot de passe
  /// faux ou un fichier abîmé laisse le coffre existant intact. Lève
  /// [FormatException] si le fichier n'est pas un coffre, et
  /// [WrongPasswordException] si [password] ne l'ouvre pas.
  Future<void> importBytes(Uint8List bytes, String password) async {
    _crypto.open(bytes, password);
    await _storage.write(bytes);
  }
}
