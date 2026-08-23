// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class LFr extends L {
  LFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'safe';

  @override
  String get cancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get save => 'Enregistrer';

  @override
  String get close => 'Fermer';

  @override
  String get add => 'Ajouter';

  @override
  String get back => 'Retour';

  @override
  String get copy => 'Copier';

  @override
  String get copied => 'Copié';

  @override
  String get copyAction => 'copier';

  @override
  String get copyFailed => 'Copie impossible';

  @override
  String get vaultLocked => 'Coffre verrouillé';

  @override
  String get unlockWelcome => 'Bienvenue.';

  @override
  String get unlockWelcomeBack => 'Content de te revoir.';

  @override
  String get unlockCreateSubtitle =>
      'Ce mot de passe est la seule clef du coffre. S\'il est perdu, il n\'y a aucun moyen de récupérer son contenu.';

  @override
  String get unlockSubtitle => 'Ton coffre est fermé.';

  @override
  String get unlockPasswordHint => 'Mot de passe maître';

  @override
  String get unlockConfirmHint => 'Confirmation';

  @override
  String get unlockCreate => 'Créer le coffre';

  @override
  String get unlockOpen => 'Déverrouiller';

  @override
  String get unlockShow => 'Afficher';

  @override
  String get unlockHide => 'Masquer';

  @override
  String unlockTooShort(int count) {
    return 'Le mot de passe doit faire au moins $count caractères';
  }

  @override
  String get unlockMismatch => 'Les mots de passe ne correspondent pas';

  @override
  String get unlockWrongPassword => 'Mot de passe incorrect';

  @override
  String unlockOpenFailed(String error) {
    return 'Impossible d\'ouvrir le coffre: $error';
  }

  @override
  String unlockAutoLockFooter(String delay) {
    return 'Verrouillage auto après $delay.';
  }

  @override
  String delayMinutes(int count) {
    return '$count min';
  }

  @override
  String delaySeconds(int count) {
    return '$count s';
  }

  @override
  String get tabVault => 'Coffre';

  @override
  String get tabGenerator => 'Générateur';

  @override
  String get homeNewEntry => 'Nouvelle fiche';

  @override
  String get homeLock => 'Verrouiller';

  @override
  String get homeSettings => 'Réglages';

  @override
  String get searchHint => 'Rechercher';

  @override
  String get vaultEmpty => 'Aucune fiche pour l\'instant.';

  @override
  String get searchEmpty => 'Aucun résultat.';

  @override
  String attachmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pièces jointes',
      one: '$count pièce jointe',
    );
    return '$_temp0';
  }

  @override
  String get generatorRegenerate => 'Régénérer';

  @override
  String get generatorLength => 'LONGUEUR';

  @override
  String get generatorHistory => 'GÉNÉRÉ AVANT';

  @override
  String get generatorHistoryNote =>
      'Effacé au verrouillage. Jamais écrit sur le disque.';

  @override
  String get generatorSetLetters => 'Lettres';

  @override
  String get generatorSetDigits => '+ chiffres';

  @override
  String get generatorSetSymbols => '+ symboles';

  @override
  String get entryTabReading => 'Lecture';

  @override
  String get entryTabRaw => 'Texte brut';

  @override
  String get entryRawHint => 'Colle ou tape ici. Tout est accepté.';

  @override
  String get entryEmpty =>
      'Cette fiche est vide.\nPassez en « Texte brut » pour la remplir.';

  @override
  String entryBlockCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocs',
      one: '$count bloc',
    );
    return '$_temp0';
  }

  @override
  String entryLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes',
      one: '$count ligne',
    );
    return '$_temp0';
  }

  @override
  String get entryCopyBlock => 'copier le bloc';

  @override
  String get entryNameEmpty => 'Le nom ne peut pas être vide';

  @override
  String get entryNameTaken => 'Ce nom existe déjà';

  @override
  String get entrySaveFailed => 'Enregistrement impossible';

  @override
  String get entrySaved => 'Enregistré';

  @override
  String get entryDeleteTitle => 'Supprimer cette fiche ?';

  @override
  String entryDeleteBody(String name) {
    return 'La fiche « $name », son texte et ses pièces jointes seront définitivement retirés du coffre.';
  }

  @override
  String get entryDeleteFailed => 'Suppression impossible';

  @override
  String get newEntryTitle => 'Nouvelle fiche';

  @override
  String get newEntryNameHint => 'Nom de la fiche';

  @override
  String get newEntryBodyHint => 'Colle ou tape ici.\nTout est accepté.';

  @override
  String get newEntryPaste => 'Coller';

  @override
  String get newEntrySaveFailed => 'Enregistrement impossible: réessayez';

  @override
  String get newEntryLockedDiscarded =>
      'Le coffre s\'est verrouillé: la saisie a été effacée';

  @override
  String get newEntryLockedNotSaved =>
      'Le coffre s\'est verrouillé: rien n\'a été enregistré';

  @override
  String get syntaxLink => 'Syntaxe';

  @override
  String get syntaxUnderstood => 'Compris';

  @override
  String get syntaxOpensBlock => 'ouvre un bloc';

  @override
  String get syntaxEmptyLine => '(ligne vide)';

  @override
  String get syntaxClosesBlock => 'le referme';

  @override
  String get syntaxPlainText => 'texte seul';

  @override
  String get syntaxStaysComment => 'reste un commentaire, à sa place';

  @override
  String get discardTitle => 'Abandonner les modifications ?';

  @override
  String get discardBody => 'La saisie en cours ne sera pas enregistrée.';

  @override
  String get discardKeepEditing => 'Continuer la saisie';

  @override
  String get discardConfirm => 'Abandonner';

  @override
  String get attachmentsTitle => 'Pièces jointes';

  @override
  String get attachmentsSaveFirst =>
      'Enregistrez l\'entrée pour pouvoir y joindre des photos ou des documents.';

  @override
  String attachmentsEmpty(String size) {
    return 'Aucune pièce jointe. Maximum $size par fichier.';
  }

  @override
  String get attachmentAdd => 'Pièce jointe';

  @override
  String attachmentTooBig(String size, String max) {
    return 'Fichier trop gros ($size); maximum $max';
  }

  @override
  String get attachmentAddFailed => 'Impossible de joindre ce fichier';

  @override
  String get attachmentReadFailed =>
      'Lecture impossible: pièce jointe absente ou coffre verrouillé';

  @override
  String attachmentSavedPlain(String path) {
    return 'Enregistré en clair dans $path';
  }

  @override
  String get attachmentExportFailed =>
      'Export impossible: pièce jointe absente ou coffre verrouillé';

  @override
  String get attachmentDeleteTitle => 'Supprimer cette pièce jointe ?';

  @override
  String attachmentDeleteBody(String name) {
    return '« $name » sera effacée définitivement.';
  }

  @override
  String get attachmentDeleteFailed =>
      'Suppression impossible: le coffre s\'est peut-être verrouillé';

  @override
  String attachmentExportLabel(String name) {
    return 'Exporter « $name » en clair';
  }

  @override
  String attachmentDeleteLabel(String name) {
    return 'Supprimer « $name »';
  }

  @override
  String sizeBytes(int count) {
    return '$count o';
  }

  @override
  String sizeKilobytes(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return '$valueString ko';
  }

  @override
  String sizeMegabytes(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return '$valueString Mo';
  }

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settingsChangePassword => 'Changer le mot de passe maître';

  @override
  String get settingsChangePasswordSubtitle =>
      'Le coffre est entièrement ré-chiffré';

  @override
  String get settingsLockNow => 'Verrouiller maintenant';

  @override
  String get settingsLockNowSubtitle =>
      'Referme le coffre et efface la clef de la mémoire';

  @override
  String get settingsAutoLock => 'Verrouillage automatique';

  @override
  String settingsAutoLockSubtitle(String delay) {
    return 'Après $delay sans activité';
  }

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLanguageSubtitle => 'Suit la langue de l\'appareil';

  @override
  String get settingsLanguageForced =>
      'Choisie, quelle que soit celle de l\'appareil';

  @override
  String get settingsLanguageSystem => 'Système';

  @override
  String get settingsBlockScreenshots => 'Bloquer les captures d\'écran';

  @override
  String get settingsBlockScreenshotsOn =>
      'Captures d\'écran refusées, et vignette vide dans les applications récentes';

  @override
  String get settingsBlockScreenshotsOff =>
      'Captures d\'écran autorisées: le contenu du coffre apparaîtra aussi dans les applications récentes';

  @override
  String get settingsBlockRefused =>
      'Blocage refusé par le système: les captures restent possibles';

  @override
  String get settingsNotSaved =>
      'Réglage non enregistré: le fichier n\'a pas pu être écrit';

  @override
  String get settingsRestore => 'Restaurer la sauvegarde précédente';

  @override
  String get settingsRestoreSubtitle =>
      'Revient à l\'état d\'avant la dernière modification';

  @override
  String get settingsExport => 'Exporter le coffre';

  @override
  String get settingsExportSubtitle =>
      'Fichier chiffré: inutilisable sans le mot de passe. Les pièces jointes ne sont pas incluses';

  @override
  String get settingsImport => 'Importer un coffre';

  @override
  String get settingsImportSubtitle =>
      'Remplace le coffre actuel après vérification';

  @override
  String get settingsNote =>
      'Le mot de passe maître ne peut pas être récupéré. Gardez une copie exportée du coffre en lieu sûr: elle reste chiffrée.\n\nL\'export ne contient que le nom et le texte de chaque fiche. Les pièces jointes vivent dans des fichiers séparés: exportez-les une par une depuis la fiche concernée.';

  @override
  String get settingsPasswordChanged => 'Mot de passe maître changé';

  @override
  String get settingsChangeFailed =>
      'Changement impossible: le coffre n\'a pas pu être ré-chiffré';

  @override
  String get settingsNewPasswordTitle => 'Nouveau mot de passe maître';

  @override
  String get settingsNewPasswordHint => 'Nouveau mot de passe';

  @override
  String get settingsConfirmHint => 'Confirmation';

  @override
  String get settingsChange => 'Changer';

  @override
  String settingsPasswordTooShort(int count) {
    return 'Au moins $count caractères';
  }

  @override
  String get settingsNoBackup =>
      'Aucune sauvegarde exploitable à côté du coffre';

  @override
  String get settingsRestoreTitle => 'Restaurer la sauvegarde ?';

  @override
  String settingsRestoreBody(int backup, int current) {
    return 'La sauvegarde contient $backup entrée(s); le coffre actuel en a $current.\n\nLe coffre actuel devient à son tour la sauvegarde: cette opération est donc annulable en la refaisant.\n\nLes pièces jointes ne sont pas concernées; celles qui ne seraient plus référencées partent dans le dossier des orphelins.';
  }

  @override
  String get settingsRestored => 'Sauvegarde restaurée';

  @override
  String get settingsRestoreFailed =>
      'Restauration impossible: la sauvegarde n\'a pas pu être lue';

  @override
  String get settingsExportSave => 'Enregistrer un fichier';

  @override
  String get settingsExportSaveSubtitle => 'Tu choisis le dossier';

  @override
  String get settingsExportShare => 'Partager';

  @override
  String get settingsExportShareSubtitle =>
      'Passer le fichier à une application';

  @override
  String settingsExported(String name) {
    return 'Coffre exporté vers $name';
  }

  @override
  String get settingsExportFailed =>
      'Export impossible: le fichier n\'a pas pu être écrit';

  @override
  String get settingsImportPasswordTitle => 'Mot de passe du coffre importé';

  @override
  String get settingsImportPasswordHint => 'Mot de passe';

  @override
  String get settingsImported =>
      'Coffre importé — déverrouillez-le avec son mot de passe';

  @override
  String get settingsImportNotAVault => 'Ce fichier n\'est pas un coffre safe';

  @override
  String get settingsImportWrongPassword =>
      'Import refusé: mot de passe incorrect ou fichier abîmé';

  @override
  String get settingsImportFailed =>
      'Import impossible: le coffre n\'a pas pu être remplacé';
}
