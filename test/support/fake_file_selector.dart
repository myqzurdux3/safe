import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Sélecteur de fichiers simulé.
///
/// Les écrans qui ouvrent un fichier ou en enregistrent un passent tous par
/// cette interface de plateforme. La remplacer permet de tester l'ajout d'une
/// pièce jointe, l'export et l'import sans boîte de dialogue native — laquelle
/// ne s'ouvre de toute façon pas sous l'horloge simulée des tests.
class FakeFileSelector extends FileSelectorPlatform
    with MockPlatformInterfaceMixin {
  FakeFileSelector({this.fileToOpen, this.saveTo});

  /// Ce que rend le sélecteur d'ouverture; `null` simule une annulation.
  XFile? fileToOpen;

  /// Où « enregistrer »; `null` simule une annulation.
  String? saveTo;

  /// Nombre d'ouvertures demandées, pour repérer un double appui.
  int openCount = 0;
  int saveCount = 0;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    openCount++;
    return fileToOpen;
  }

  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async {
    saveCount++;
    final destination = saveTo;
    return destination == null ? null : FileSaveLocation(destination);
  }
}
