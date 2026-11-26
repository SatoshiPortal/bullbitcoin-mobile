import 'package:file_system/file_system.dart';
import 'package:go_router/go_router.dart';
import 'package:label_editor/src/ui/page.dart';
import 'package:labels/labels.dart';

import 'domain/export_labels_to_file_usecase.dart';
import 'domain/import_labels_from_file_usecase.dart';

const labelEditorRouteName = 'labels';

final class LabelEditorFeature {
  final List<GoRoute> routes;

  const LabelEditorFeature._(this.routes);

  factory LabelEditorFeature.mount({required Labels Function() labels}) =>
      LabelEditorFeature._([
        GoRoute(
          name: labelEditorRouteName,
          path: '/labels',
          builder: (context, state) {
            final capability = labels();
            const files = FileSystem.open();
            return Bip329LabelsPage(
              exportLabels: ExportLabelsToFileUsecase(
                labels: capability,
                fileSystem: files,
              ),
              importLabels: ImportLabelsFromFileUsecase(
                labels: capability,
                fileSystem: files,
              ),
            );
          },
        ),
      ]);
}
