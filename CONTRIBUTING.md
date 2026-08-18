# Contribuer

## Avant de proposer quoi que ce soit

```bash
dart format lib test
flutter analyze     # doit finir par « No issues found! »
flutter test        # doit finir par « All tests passed! »
```

Les trois passent sur `master`. Une proposition qui les casse ne sera pas lue.

## Un test qui échoue d'abord

Pour une correction comme pour une fonctionnalité: écrire le test, le voir
échouer, puis corriger. Un test qui n'a jamais été rouge ne prouve rien — il
peut passer pour une raison qui n'a rien à voir avec ce qu'il prétend vérifier.

Les tests d'interface tournent sous une horloge simulée où les entrées/sorties
réelles ne se terminent jamais: utiliser `MemoryVaultStore`, `MemoryBlobStore` et
`MemorySettingsStore` de `test/support/session_fixture.dart`. Les vraies
écritures disque ont leurs propres tests, dans `test/storage/`.

## Sécurité

Ce dépôt est un coffre-fort. Trois règles qui ne se négocient pas:

1. **Aucun secret en clair sur le disque**, à aucun moment — sauf export
   explicite d'une pièce jointe, seule exception, documentée.
2. **Aucune erreur avalée en silence** sur un chemin qui touche à une
   protection. Une protection dont l'échec ne se voit pas est pire qu'une erreur
   affichée: l'utilisateur fait confiance à quelque chose d'absent.
3. **Ne jamais élargir le modèle de menace sans le dire.** Le document de
   conception (`docs/superpowers/specs/`) énumère ce qui est couvert et ce qui
   ne l'est pas; une modification qui déplace cette frontière doit le mettre à
   jour dans le même commit.

## Style

- Commentaires, chaînes visibles, messages de commit: en français.
- Les commentaires expliquent le *pourquoi*, jamais le *quoi*: si un commentaire
  paraphrase la ligne suivante, il faut le supprimer.
- `dart format` tranche la mise en forme; ne pas la retoucher à la main.
- Un commit par correction, avec son test.
