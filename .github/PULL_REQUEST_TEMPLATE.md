## Ce que ça change

<!-- En une ou deux phrases. Le pourquoi, pas le quoi: le diff dit déjà le quoi. -->

## Le test qui échouait avant

<!--
Nom du test, et ce qu'il montrait sur le code d'avant. Un test qui n'a jamais
été rouge ne prouve rien: il peut passer pour une raison sans rapport avec ce
qu'il prétend vérifier. Voir CONTRIBUTING.md.
-->

## Vérifications

- [ ] `dart format lib test` ne change rien
- [ ] `flutter analyze` finit par « No issues found! »
- [ ] `flutter test` finit par « All tests passed! »
- [ ] Aucun secret réel dans le diff, les tests ou les captures

## Sécurité

<!--
À remplir si le changement touche au chiffrement, au stockage, au presse-papier,
au verrouillage, aux permissions de fichiers ou au code natif. Si le modèle de
menace décrit dans docs/superpowers/specs/ bouge, mettez-le à jour dans le même
commit. Sinon, écrivez « sans effet » et dites pourquoi.
-->
