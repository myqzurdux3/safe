# Signaler une faille

**N'ouvrez pas d'issue publique pour une faille de sécurité.** Une issue est
visible de tous, y compris de qui voudrait s'en servir avant qu'un correctif
n'existe.

Utilisez l'onglet **Security → Report a vulnerability** de ce dépôt, qui ouvre
un canal privé avec le mainteneur.

## Ce qui intéresse

Tout ce qui permet d'accéder au contenu d'un coffre sans son mot de passe
maître, ou de le faire fuiter hors de l'appareil: faiblesse du format de
fichier, de la dérivation, de l'usage de l'AEAD, du stockage des pièces
jointes, fuite par le presse-papier, par le clavier, par les sauvegardes du
système, par les captures d'écran.

## Ce qui n'en est pas une

Le modèle de menace est décrit dans
[docs/superpowers/specs/2026-08-14-safe-design.md](../docs/superpowers/specs/2026-08-14-safe-design.md).
Sont hors périmètre, et assumés:

- un appareil déjà compromis: root, enregistreur de frappe, débogueur attaché;
- les valeurs déchiffrées vivant dans des `String` Dart, que le langage ne
  permet pas d'effacer de façon déterministe;
- l'APK signé avec la clé de debug tant que le dépôt ne fournit pas de clé de
  release — c'est documenté dans `DEPLOY.md`, avec la marche à suivre;
- la perte du mot de passe maître, qui est irrécupérable par construction.

## Dans votre rapport

N'incluez **jamais** un vrai coffre, un vrai mot de passe, ni une capture
d'écran montrant vos entrées. Un coffre de démonstration et les étapes pour le
reproduire suffisent.

Ce projet est maintenu sur du temps personnel: la réponse peut prendre
plusieurs jours. Il n'a jamais fait l'objet d'un audit par un tiers.
