import 'dart:typed_data';

import 'package:safe/crypto/vault_crypto.dart';
import 'package:safe/model/vault.dart';

/// Sceller un coffre à partir d'un mot de passe — pour les tests seulement.
///
/// L'application ne fait jamais cela d'un bloc: `VaultSession` tire un sel,
/// dérive la clef **dans un isolat** (`deriveKeyAsync`) pour que l'interface
/// ne gèle pas et qu'Android ne tue pas l'application pour non-réponse, puis
/// scelle. Ce raccourci synchrone vivait dans `VaultCrypto`, où seuls les
/// tests l'appelaient: il est descendu ici plutôt que de rester du code mort
/// livré avec l'application.
///
/// Les trois appels sont exactement ceux de la production, dans le même
/// ordre et avec les mêmes arguments: les octets produits sont les mêmes, et
/// ce que les tests de chiffrement vérifient ne change pas d'un bit.
extension SealForTests on VaultCrypto {
  Uint8List sealWithPassword(
    Vault vault,
    String password, {
    KdfParams params = KdfParams.defaults,
  }) {
    final salt = newSalt();
    final key = deriveKey(password, salt, params);
    try {
      return seal(vault, key, salt, params);
    } finally {
      key.dispose();
    }
  }
}
