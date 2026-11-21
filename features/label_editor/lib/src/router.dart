import 'package:file_system/file_system.dart';
import 'package:go_router/go_router.dart';
import 'package:label_editor/src/ui/page.dart';
import 'package:labels/labels.dart';

import 'domain/export_labels_to_file_usecase.dart';
import 'domain/import_labels_from_file_usecase.dart';

enum LabelsRoute {
  labels('/labels');

  final String path;

  const LabelsRoute(this.path);
}

class LabelsRouter {
  static GoRoute route(LabelsFacade Function() getLabels) => GoRoute(
    name: LabelsRoute.labels.name,
    path: LabelsRoute.labels.path,
    builder: (context, state) {
      final labels = getLabels();
      const files = FileSystem.open();
      return Bip329LabelsPage(
        exportLabels: ExportLabelsToFileUsecase(
          labels: labels,
          fileSystem: files,
        ),
        importLabels: ImportLabelsFromFileUsecase(
          labels: labels,
          fileSystem: files,
        ),
      );
    },
  );
}
