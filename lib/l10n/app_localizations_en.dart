// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'safe';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String get add => 'Add';

  @override
  String get back => 'Back';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get copyAction => 'copy';

  @override
  String get copyFailed => 'Couldn\'t copy';

  @override
  String get vaultLocked => 'Vault locked';

  @override
  String get unlockWelcome => 'Welcome.';

  @override
  String get unlockWelcomeBack => 'Good to see you again.';

  @override
  String get unlockCreateSubtitle =>
      'This password is the only key to the vault. If it is lost, there is no way to recover what is inside.';

  @override
  String get unlockSubtitle => 'Your vault is closed.';

  @override
  String get unlockPasswordHint => 'Master password';

  @override
  String get unlockConfirmHint => 'Confirm';

  @override
  String get unlockCreate => 'Create the vault';

  @override
  String get unlockOpen => 'Unlock';

  @override
  String get unlockShow => 'Show';

  @override
  String get unlockHide => 'Hide';

  @override
  String unlockTooShort(int count) {
    return 'The password must be at least $count characters';
  }

  @override
  String get unlockMismatch => 'The passwords do not match';

  @override
  String get unlockWrongPassword => 'Wrong password';

  @override
  String unlockOpenFailed(String error) {
    return 'Couldn\'t open the vault: $error';
  }

  @override
  String unlockAutoLockFooter(String delay) {
    return 'Auto-lock after $delay.';
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
  String get tabVault => 'Vault';

  @override
  String get tabGenerator => 'Generator';

  @override
  String get homeNewEntry => 'New entry';

  @override
  String get homeLock => 'Lock';

  @override
  String get homeSettings => 'Settings';

  @override
  String get searchHint => 'Search';

  @override
  String get vaultEmpty => 'Nothing in the vault yet.';

  @override
  String get searchEmpty => 'No results.';

  @override
  String attachmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attachments',
      one: '$count attachment',
    );
    return '$_temp0';
  }

  @override
  String get generatorRegenerate => 'Generate again';

  @override
  String get generatorLength => 'LENGTH';

  @override
  String get generatorHistory => 'GENERATED BEFORE';

  @override
  String get generatorHistoryNote => 'Cleared on lock. Never written to disk.';

  @override
  String get generatorSetLetters => 'Letters';

  @override
  String get generatorSetDigits => '+ digits';

  @override
  String get generatorSetSymbols => '+ symbols';

  @override
  String get entryTabReading => 'Reading';

  @override
  String get entryTabRaw => 'Plain text';

  @override
  String get entryRawHint => 'Paste or type here. Anything goes.';

  @override
  String get entryEmpty =>
      'This entry is empty.\nSwitch to “Plain text” to fill it in.';

  @override
  String entryBlockCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocks',
      one: '$count block',
    );
    return '$_temp0';
  }

  @override
  String entryLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '$count line',
    );
    return '$_temp0';
  }

  @override
  String get entryCopyBlock => 'copy the block';

  @override
  String get entryNameEmpty => 'The name cannot be empty';

  @override
  String get entryNameTaken => 'That name already exists';

  @override
  String get entrySaveFailed => 'Couldn\'t save';

  @override
  String get entrySaved => 'Saved';

  @override
  String get entryDeleteTitle => 'Delete this entry?';

  @override
  String entryDeleteBody(String name) {
    return 'The entry “$name”, its text and its attachments will be removed from the vault for good.';
  }

  @override
  String get entryDeleteFailed => 'Couldn\'t delete';

  @override
  String get newEntryTitle => 'New entry';

  @override
  String get newEntryNameHint => 'Entry name';

  @override
  String get newEntryBodyHint => 'Paste or type here.\nAnything goes.';

  @override
  String get newEntryPaste => 'Paste';

  @override
  String get newEntrySaveFailed => 'Couldn\'t save: try again';

  @override
  String get newEntryLockedDiscarded =>
      'The vault locked: what you typed was cleared';

  @override
  String get newEntryLockedNotSaved => 'The vault locked: nothing was saved';

  @override
  String get syntaxLink => 'Syntax';

  @override
  String get syntaxUnderstood => 'Got it';

  @override
  String get syntaxOpensBlock => 'opens a block';

  @override
  String get syntaxEmptyLine => '(blank line)';

  @override
  String get syntaxClosesBlock => 'closes it';

  @override
  String get syntaxPlainText => 'plain line';

  @override
  String get syntaxStaysComment => 'stays a note, where you put it';

  @override
  String get discardTitle => 'Discard changes?';

  @override
  String get discardBody => 'What you have typed will not be saved.';

  @override
  String get discardKeepEditing => 'Keep editing';

  @override
  String get discardConfirm => 'Discard';

  @override
  String get attachmentsTitle => 'Attachments';

  @override
  String get attachmentsSaveFirst =>
      'Save the entry before attaching photos or documents to it.';

  @override
  String attachmentsEmpty(String size) {
    return 'No attachments. $size per file at most.';
  }

  @override
  String get attachmentAdd => 'Attachment';

  @override
  String attachmentTooBig(String size, String max) {
    return 'File too large ($size); $max at most';
  }

  @override
  String get attachmentAddFailed => 'Couldn\'t attach this file';

  @override
  String get attachmentReadFailed =>
      'Couldn\'t read it: the attachment is missing, or the vault is locked';

  @override
  String attachmentSavedPlain(String path) {
    return 'Saved unencrypted to $path';
  }

  @override
  String get attachmentExportFailed =>
      'Couldn\'t export: the attachment is missing, or the vault is locked';

  @override
  String get attachmentDeleteTitle => 'Delete this attachment?';

  @override
  String attachmentDeleteBody(String name) {
    return '“$name” will be erased for good.';
  }

  @override
  String get attachmentDeleteFailed =>
      'Couldn\'t delete: the vault may have locked';

  @override
  String attachmentExportLabel(String name) {
    return 'Export “$name” unencrypted';
  }

  @override
  String attachmentDeleteLabel(String name) {
    return 'Delete “$name”';
  }

  @override
  String sizeBytes(int count) {
    return '$count B';
  }

  @override
  String sizeKilobytes(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return '$valueString kB';
  }

  @override
  String sizeMegabytes(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return '$valueString MB';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsChangePassword => 'Change the master password';

  @override
  String get settingsChangePasswordSubtitle =>
      'The whole vault is re-encrypted';

  @override
  String get settingsLockNow => 'Lock now';

  @override
  String get settingsLockNowSubtitle =>
      'Closes the vault and wipes the key from memory';

  @override
  String get settingsAutoLock => 'Automatic lock';

  @override
  String settingsAutoLockSubtitle(String delay) {
    return 'After $delay without activity';
  }

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSubtitle => 'Follows the device language';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsBlockScreenshots => 'Block screenshots';

  @override
  String get settingsBlockScreenshotsOn =>
      'Screenshots refused, and a blank thumbnail in the recent apps list';

  @override
  String get settingsBlockScreenshotsOff =>
      'Screenshots allowed: the vault\'s contents will also show in the recent apps list';

  @override
  String get settingsBlockRefused =>
      'The system refused: screenshots are still possible';

  @override
  String get settingsNotSaved =>
      'Setting not saved: the file could not be written';

  @override
  String get settingsRestore => 'Restore the previous backup';

  @override
  String get settingsRestoreSubtitle =>
      'Goes back to the state before the last change';

  @override
  String get settingsExport => 'Export the vault';

  @override
  String get settingsExportSubtitle =>
      'Encrypted file: useless without the password. Attachments are not included';

  @override
  String get settingsImport => 'Import a vault';

  @override
  String get settingsImportSubtitle =>
      'Replaces the current vault, once verified';

  @override
  String get settingsNote =>
      'The master password cannot be recovered. Keep an exported copy of the vault somewhere safe: it stays encrypted.\n\nAn export holds only the name and the text of each entry. Attachments live in separate files: export them one by one from the entry itself.';

  @override
  String get settingsPasswordChanged => 'Master password changed';

  @override
  String get settingsChangeFailed =>
      'Couldn\'t change it: the vault could not be re-encrypted';

  @override
  String get settingsNewPasswordTitle => 'New master password';

  @override
  String get settingsNewPasswordHint => 'New password';

  @override
  String get settingsConfirmHint => 'Confirm';

  @override
  String get settingsChange => 'Change';

  @override
  String settingsPasswordTooShort(int count) {
    return 'At least $count characters';
  }

  @override
  String get settingsNoBackup => 'No usable backup next to the vault';

  @override
  String get settingsRestoreTitle => 'Restore the backup?';

  @override
  String settingsRestoreBody(int backup, int current) {
    return 'The backup holds $backup entrie(s); the current vault holds $current.\n\nThe current vault becomes the backup in turn, so doing this again undoes it.\n\nAttachments are untouched; any that end up unreferenced move to the orphans folder.';
  }

  @override
  String get settingsRestored => 'Backup restored';

  @override
  String get settingsRestoreFailed =>
      'Couldn\'t restore: the backup could not be read';

  @override
  String get settingsExportSave => 'Save to a file';

  @override
  String get settingsExportSaveSubtitle => 'You pick the folder';

  @override
  String get settingsExportShare => 'Share';

  @override
  String get settingsExportShareSubtitle => 'Hand the file to another app';

  @override
  String settingsExported(String name) {
    return 'Vault exported to $name';
  }

  @override
  String get settingsExportFailed =>
      'Couldn\'t export: the file could not be written';

  @override
  String get settingsImportPasswordTitle => 'Password of the imported vault';

  @override
  String get settingsImportPasswordHint => 'Password';

  @override
  String get settingsImported =>
      'Vault imported — unlock it with its own password';

  @override
  String get settingsImportNotAVault => 'This file is not a safe vault';

  @override
  String get settingsImportWrongPassword =>
      'Import refused: wrong password, or the file is damaged';

  @override
  String get settingsImportFailed =>
      'Couldn\'t import: the vault could not be replaced';
}
