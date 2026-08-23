import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// Le nom de l'application, qui ne se traduit pas.
  ///
  /// In fr, this message translates to:
  /// **'safe'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @close.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get close;

  /// No description provided for @add.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get add;

  /// No description provided for @back.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get back;

  /// No description provided for @copy.
  ///
  /// In fr, this message translates to:
  /// **'Copier'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In fr, this message translates to:
  /// **'Copié'**
  String get copied;

  /// No description provided for @copyAction.
  ///
  /// In fr, this message translates to:
  /// **'copier'**
  String get copyAction;

  /// No description provided for @copyFailed.
  ///
  /// In fr, this message translates to:
  /// **'Copie impossible'**
  String get copyFailed;

  /// No description provided for @vaultLocked.
  ///
  /// In fr, this message translates to:
  /// **'Coffre verrouillé'**
  String get vaultLocked;

  /// No description provided for @unlockWelcome.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue.'**
  String get unlockWelcome;

  /// No description provided for @unlockWelcomeBack.
  ///
  /// In fr, this message translates to:
  /// **'Content de te revoir.'**
  String get unlockWelcomeBack;

  /// No description provided for @unlockCreateSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce mot de passe est la seule clef du coffre. S\'il est perdu, il n\'y a aucun moyen de récupérer son contenu.'**
  String get unlockCreateSubtitle;

  /// No description provided for @unlockSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Ton coffre est fermé.'**
  String get unlockSubtitle;

  /// No description provided for @unlockPasswordHint.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe maître'**
  String get unlockPasswordHint;

  /// No description provided for @unlockConfirmHint.
  ///
  /// In fr, this message translates to:
  /// **'Confirmation'**
  String get unlockConfirmHint;

  /// No description provided for @unlockCreate.
  ///
  /// In fr, this message translates to:
  /// **'Créer le coffre'**
  String get unlockCreate;

  /// No description provided for @unlockOpen.
  ///
  /// In fr, this message translates to:
  /// **'Déverrouiller'**
  String get unlockOpen;

  /// No description provided for @unlockShow.
  ///
  /// In fr, this message translates to:
  /// **'Afficher'**
  String get unlockShow;

  /// No description provided for @unlockHide.
  ///
  /// In fr, this message translates to:
  /// **'Masquer'**
  String get unlockHide;

  /// No description provided for @unlockTooShort.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe doit faire au moins {count} caractères'**
  String unlockTooShort(int count);

  /// No description provided for @unlockMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Les mots de passe ne correspondent pas'**
  String get unlockMismatch;

  /// No description provided for @unlockWrongPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe incorrect'**
  String get unlockWrongPassword;

  /// No description provided for @unlockOpenFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir le coffre: {error}'**
  String unlockOpenFailed(String error);

  /// No description provided for @unlockAutoLockFooter.
  ///
  /// In fr, this message translates to:
  /// **'Verrouillage auto après {delay}.'**
  String unlockAutoLockFooter(String delay);

  /// No description provided for @delayMinutes.
  ///
  /// In fr, this message translates to:
  /// **'{count} min'**
  String delayMinutes(int count);

  /// No description provided for @delaySeconds.
  ///
  /// In fr, this message translates to:
  /// **'{count} s'**
  String delaySeconds(int count);

  /// No description provided for @tabVault.
  ///
  /// In fr, this message translates to:
  /// **'Coffre'**
  String get tabVault;

  /// No description provided for @tabGenerator.
  ///
  /// In fr, this message translates to:
  /// **'Générateur'**
  String get tabGenerator;

  /// No description provided for @homeNewEntry.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle fiche'**
  String get homeNewEntry;

  /// No description provided for @homeLock.
  ///
  /// In fr, this message translates to:
  /// **'Verrouiller'**
  String get homeLock;

  /// No description provided for @homeSettings.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get homeSettings;

  /// No description provided for @searchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get searchHint;

  /// No description provided for @vaultEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune fiche pour l\'instant.'**
  String get vaultEmpty;

  /// No description provided for @searchEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat.'**
  String get searchEmpty;

  /// No description provided for @attachmentCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} pièce jointe} other{{count} pièces jointes}}'**
  String attachmentCount(int count);

  /// No description provided for @generatorRegenerate.
  ///
  /// In fr, this message translates to:
  /// **'Régénérer'**
  String get generatorRegenerate;

  /// No description provided for @generatorLength.
  ///
  /// In fr, this message translates to:
  /// **'LONGUEUR'**
  String get generatorLength;

  /// No description provided for @generatorHistory.
  ///
  /// In fr, this message translates to:
  /// **'GÉNÉRÉ AVANT'**
  String get generatorHistory;

  /// No description provided for @generatorHistoryNote.
  ///
  /// In fr, this message translates to:
  /// **'Effacé au verrouillage. Jamais écrit sur le disque.'**
  String get generatorHistoryNote;

  /// No description provided for @generatorSetLetters.
  ///
  /// In fr, this message translates to:
  /// **'Lettres'**
  String get generatorSetLetters;

  /// No description provided for @generatorSetDigits.
  ///
  /// In fr, this message translates to:
  /// **'+ chiffres'**
  String get generatorSetDigits;

  /// No description provided for @generatorSetSymbols.
  ///
  /// In fr, this message translates to:
  /// **'+ symboles'**
  String get generatorSetSymbols;

  /// No description provided for @entryTabReading.
  ///
  /// In fr, this message translates to:
  /// **'Lecture'**
  String get entryTabReading;

  /// No description provided for @entryTabRaw.
  ///
  /// In fr, this message translates to:
  /// **'Texte brut'**
  String get entryTabRaw;

  /// No description provided for @entryRawHint.
  ///
  /// In fr, this message translates to:
  /// **'Colle ou tape ici. Tout est accepté.'**
  String get entryRawHint;

  /// No description provided for @entryEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Cette fiche est vide.\nPassez en « Texte brut » pour la remplir.'**
  String get entryEmpty;

  /// No description provided for @entryBlockCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} bloc} other{{count} blocs}}'**
  String entryBlockCount(int count);

  /// No description provided for @entryLineCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} ligne} other{{count} lignes}}'**
  String entryLineCount(int count);

  /// No description provided for @entryCopyBlock.
  ///
  /// In fr, this message translates to:
  /// **'copier le bloc'**
  String get entryCopyBlock;

  /// No description provided for @entryNameEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Le nom ne peut pas être vide'**
  String get entryNameEmpty;

  /// No description provided for @entryNameTaken.
  ///
  /// In fr, this message translates to:
  /// **'Ce nom existe déjà'**
  String get entryNameTaken;

  /// No description provided for @entrySaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement impossible'**
  String get entrySaveFailed;

  /// No description provided for @entrySaved.
  ///
  /// In fr, this message translates to:
  /// **'Enregistré'**
  String get entrySaved;

  /// No description provided for @entryDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette fiche ?'**
  String get entryDeleteTitle;

  /// No description provided for @entryDeleteBody.
  ///
  /// In fr, this message translates to:
  /// **'La fiche « {name} », son texte et ses pièces jointes seront définitivement retirés du coffre.'**
  String entryDeleteBody(String name);

  /// No description provided for @entryDeleteFailed.
  ///
  /// In fr, this message translates to:
  /// **'Suppression impossible'**
  String get entryDeleteFailed;

  /// No description provided for @newEntryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle fiche'**
  String get newEntryTitle;

  /// No description provided for @newEntryNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la fiche'**
  String get newEntryNameHint;

  /// No description provided for @newEntryBodyHint.
  ///
  /// In fr, this message translates to:
  /// **'Colle ou tape ici.\nTout est accepté.'**
  String get newEntryBodyHint;

  /// No description provided for @newEntryPaste.
  ///
  /// In fr, this message translates to:
  /// **'Coller'**
  String get newEntryPaste;

  /// No description provided for @newEntrySaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement impossible: réessayez'**
  String get newEntrySaveFailed;

  /// No description provided for @newEntryLockedDiscarded.
  ///
  /// In fr, this message translates to:
  /// **'Le coffre s\'est verrouillé: la saisie a été effacée'**
  String get newEntryLockedDiscarded;

  /// No description provided for @newEntryLockedNotSaved.
  ///
  /// In fr, this message translates to:
  /// **'Le coffre s\'est verrouillé: rien n\'a été enregistré'**
  String get newEntryLockedNotSaved;

  /// No description provided for @syntaxLink.
  ///
  /// In fr, this message translates to:
  /// **'Syntaxe'**
  String get syntaxLink;

  /// No description provided for @syntaxUnderstood.
  ///
  /// In fr, this message translates to:
  /// **'Compris'**
  String get syntaxUnderstood;

  /// No description provided for @syntaxOpensBlock.
  ///
  /// In fr, this message translates to:
  /// **'ouvre un bloc'**
  String get syntaxOpensBlock;

  /// No description provided for @syntaxEmptyLine.
  ///
  /// In fr, this message translates to:
  /// **'(ligne vide)'**
  String get syntaxEmptyLine;

  /// No description provided for @syntaxClosesBlock.
  ///
  /// In fr, this message translates to:
  /// **'le referme'**
  String get syntaxClosesBlock;

  /// No description provided for @syntaxPlainText.
  ///
  /// In fr, this message translates to:
  /// **'texte seul'**
  String get syntaxPlainText;

  /// No description provided for @syntaxStaysComment.
  ///
  /// In fr, this message translates to:
  /// **'reste un commentaire, à sa place'**
  String get syntaxStaysComment;

  /// No description provided for @discardTitle.
  ///
  /// In fr, this message translates to:
  /// **'Abandonner les modifications ?'**
  String get discardTitle;

  /// No description provided for @discardBody.
  ///
  /// In fr, this message translates to:
  /// **'La saisie en cours ne sera pas enregistrée.'**
  String get discardBody;

  /// No description provided for @discardKeepEditing.
  ///
  /// In fr, this message translates to:
  /// **'Continuer la saisie'**
  String get discardKeepEditing;

  /// No description provided for @discardConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Abandonner'**
  String get discardConfirm;

  /// No description provided for @attachmentsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pièces jointes'**
  String get attachmentsTitle;

  /// No description provided for @attachmentsSaveFirst.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrez l\'entrée pour pouvoir y joindre des photos ou des documents.'**
  String get attachmentsSaveFirst;

  /// No description provided for @attachmentsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune pièce jointe. Maximum {size} par fichier.'**
  String attachmentsEmpty(String size);

  /// No description provided for @attachmentAdd.
  ///
  /// In fr, this message translates to:
  /// **'Pièce jointe'**
  String get attachmentAdd;

  /// No description provided for @attachmentTooBig.
  ///
  /// In fr, this message translates to:
  /// **'Fichier trop gros ({size}); maximum {max}'**
  String attachmentTooBig(String size, String max);

  /// No description provided for @attachmentAddFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de joindre ce fichier'**
  String get attachmentAddFailed;

  /// No description provided for @attachmentReadFailed.
  ///
  /// In fr, this message translates to:
  /// **'Lecture impossible: pièce jointe absente ou coffre verrouillé'**
  String get attachmentReadFailed;

  /// No description provided for @attachmentSavedPlain.
  ///
  /// In fr, this message translates to:
  /// **'Enregistré en clair dans {path}'**
  String attachmentSavedPlain(String path);

  /// No description provided for @attachmentExportFailed.
  ///
  /// In fr, this message translates to:
  /// **'Export impossible: pièce jointe absente ou coffre verrouillé'**
  String get attachmentExportFailed;

  /// No description provided for @attachmentDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette pièce jointe ?'**
  String get attachmentDeleteTitle;

  /// No description provided for @attachmentDeleteBody.
  ///
  /// In fr, this message translates to:
  /// **'« {name} » sera effacée définitivement.'**
  String attachmentDeleteBody(String name);

  /// No description provided for @attachmentDeleteFailed.
  ///
  /// In fr, this message translates to:
  /// **'Suppression impossible: le coffre s\'est peut-être verrouillé'**
  String get attachmentDeleteFailed;

  /// No description provided for @attachmentExportLabel.
  ///
  /// In fr, this message translates to:
  /// **'Exporter « {name} » en clair'**
  String attachmentExportLabel(String name);

  /// No description provided for @attachmentDeleteLabel.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer « {name} »'**
  String attachmentDeleteLabel(String name);

  /// No description provided for @sizeBytes.
  ///
  /// In fr, this message translates to:
  /// **'{count} o'**
  String sizeBytes(int count);

  /// No description provided for @sizeKilobytes.
  ///
  /// In fr, this message translates to:
  /// **'{value} ko'**
  String sizeKilobytes(double value);

  /// No description provided for @sizeMegabytes.
  ///
  /// In fr, this message translates to:
  /// **'{value} Mo'**
  String sizeMegabytes(double value);

  /// No description provided for @settingsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get settingsTitle;

  /// No description provided for @settingsChangePassword.
  ///
  /// In fr, this message translates to:
  /// **'Changer le mot de passe maître'**
  String get settingsChangePassword;

  /// No description provided for @settingsChangePasswordSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Le coffre est entièrement ré-chiffré'**
  String get settingsChangePasswordSubtitle;

  /// No description provided for @settingsLockNow.
  ///
  /// In fr, this message translates to:
  /// **'Verrouiller maintenant'**
  String get settingsLockNow;

  /// No description provided for @settingsLockNowSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Referme le coffre et efface la clef de la mémoire'**
  String get settingsLockNowSubtitle;

  /// No description provided for @settingsAutoLock.
  ///
  /// In fr, this message translates to:
  /// **'Verrouillage automatique'**
  String get settingsAutoLock;

  /// No description provided for @settingsAutoLockSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Après {delay} sans activité'**
  String settingsAutoLockSubtitle(String delay);

  /// No description provided for @settingsLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Suit la langue de l\'appareil'**
  String get settingsLanguageSubtitle;

  /// No description provided for @settingsLanguageForced.
  ///
  /// In fr, this message translates to:
  /// **'Choisie, quelle que soit celle de l\'appareil'**
  String get settingsLanguageForced;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsBlockScreenshots.
  ///
  /// In fr, this message translates to:
  /// **'Bloquer les captures d\'écran'**
  String get settingsBlockScreenshots;

  /// No description provided for @settingsBlockScreenshotsOn.
  ///
  /// In fr, this message translates to:
  /// **'Captures d\'écran refusées, et vignette vide dans les applications récentes'**
  String get settingsBlockScreenshotsOn;

  /// No description provided for @settingsBlockScreenshotsOff.
  ///
  /// In fr, this message translates to:
  /// **'Captures d\'écran autorisées: le contenu du coffre apparaîtra aussi dans les applications récentes'**
  String get settingsBlockScreenshotsOff;

  /// No description provided for @settingsBlockRefused.
  ///
  /// In fr, this message translates to:
  /// **'Blocage refusé par le système: les captures restent possibles'**
  String get settingsBlockRefused;

  /// No description provided for @settingsNotSaved.
  ///
  /// In fr, this message translates to:
  /// **'Réglage non enregistré: le fichier n\'a pas pu être écrit'**
  String get settingsNotSaved;

  /// No description provided for @settingsRestore.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer la sauvegarde précédente'**
  String get settingsRestore;

  /// No description provided for @settingsRestoreSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Revient à l\'état d\'avant la dernière modification'**
  String get settingsRestoreSubtitle;

  /// No description provided for @settingsExport.
  ///
  /// In fr, this message translates to:
  /// **'Exporter le coffre'**
  String get settingsExport;

  /// No description provided for @settingsExportSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Fichier chiffré: inutilisable sans le mot de passe. Les pièces jointes ne sont pas incluses'**
  String get settingsExportSubtitle;

  /// No description provided for @settingsImport.
  ///
  /// In fr, this message translates to:
  /// **'Importer un coffre'**
  String get settingsImport;

  /// No description provided for @settingsImportSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Remplace le coffre actuel après vérification'**
  String get settingsImportSubtitle;

  /// No description provided for @settingsNote.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe maître ne peut pas être récupéré. Gardez une copie exportée du coffre en lieu sûr: elle reste chiffrée.\n\nL\'export ne contient que le nom et le texte de chaque fiche. Les pièces jointes vivent dans des fichiers séparés: exportez-les une par une depuis la fiche concernée.'**
  String get settingsNote;

  /// No description provided for @settingsPasswordChanged.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe maître changé'**
  String get settingsPasswordChanged;

  /// No description provided for @settingsChangeFailed.
  ///
  /// In fr, this message translates to:
  /// **'Changement impossible: le coffre n\'a pas pu être ré-chiffré'**
  String get settingsChangeFailed;

  /// No description provided for @settingsNewPasswordTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe maître'**
  String get settingsNewPasswordTitle;

  /// No description provided for @settingsNewPasswordHint.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe'**
  String get settingsNewPasswordHint;

  /// No description provided for @settingsConfirmHint.
  ///
  /// In fr, this message translates to:
  /// **'Confirmation'**
  String get settingsConfirmHint;

  /// No description provided for @settingsChange.
  ///
  /// In fr, this message translates to:
  /// **'Changer'**
  String get settingsChange;

  /// No description provided for @settingsPasswordTooShort.
  ///
  /// In fr, this message translates to:
  /// **'Au moins {count} caractères'**
  String settingsPasswordTooShort(int count);

  /// No description provided for @settingsNoBackup.
  ///
  /// In fr, this message translates to:
  /// **'Aucune sauvegarde exploitable à côté du coffre'**
  String get settingsNoBackup;

  /// No description provided for @settingsRestoreTitle.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer la sauvegarde ?'**
  String get settingsRestoreTitle;

  /// No description provided for @settingsRestoreBody.
  ///
  /// In fr, this message translates to:
  /// **'La sauvegarde contient {backup} entrée(s); le coffre actuel en a {current}.\n\nLe coffre actuel devient à son tour la sauvegarde: cette opération est donc annulable en la refaisant.\n\nLes pièces jointes ne sont pas concernées; celles qui ne seraient plus référencées partent dans le dossier des orphelins.'**
  String settingsRestoreBody(int backup, int current);

  /// No description provided for @settingsRestored.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde restaurée'**
  String get settingsRestored;

  /// No description provided for @settingsRestoreFailed.
  ///
  /// In fr, this message translates to:
  /// **'Restauration impossible: la sauvegarde n\'a pas pu être lue'**
  String get settingsRestoreFailed;

  /// No description provided for @settingsExportSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer un fichier'**
  String get settingsExportSave;

  /// No description provided for @settingsExportSaveSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Tu choisis le dossier'**
  String get settingsExportSaveSubtitle;

  /// No description provided for @settingsExportShare.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get settingsExportShare;

  /// No description provided for @settingsExportShareSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Passer le fichier à une application'**
  String get settingsExportShareSubtitle;

  /// No description provided for @settingsExported.
  ///
  /// In fr, this message translates to:
  /// **'Coffre exporté vers {name}'**
  String settingsExported(String name);

  /// No description provided for @settingsExportFailed.
  ///
  /// In fr, this message translates to:
  /// **'Export impossible: le fichier n\'a pas pu être écrit'**
  String get settingsExportFailed;

  /// No description provided for @settingsImportPasswordTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe du coffre importé'**
  String get settingsImportPasswordTitle;

  /// No description provided for @settingsImportPasswordHint.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get settingsImportPasswordHint;

  /// No description provided for @settingsImported.
  ///
  /// In fr, this message translates to:
  /// **'Coffre importé — déverrouillez-le avec son mot de passe'**
  String get settingsImported;

  /// No description provided for @settingsImportNotAVault.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier n\'est pas un coffre safe'**
  String get settingsImportNotAVault;

  /// No description provided for @settingsImportWrongPassword.
  ///
  /// In fr, this message translates to:
  /// **'Import refusé: mot de passe incorrect ou fichier abîmé'**
  String get settingsImportWrongPassword;

  /// No description provided for @settingsImportFailed.
  ///
  /// In fr, this message translates to:
  /// **'Import impossible: le coffre n\'a pas pu être remplacé'**
  String get settingsImportFailed;
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return LEn();
    case 'fr':
      return LFr();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
