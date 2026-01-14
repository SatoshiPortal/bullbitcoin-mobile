import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/labels/domain/label.dart';

abstract class LabelsRepositoryPort {
  LabelsRepositoryPort({required SqliteDatabase database});

  Future<void> store(List<Label> labels);

  Future<List<Label>> fetchByLabel(String label);

  Future<List<Label>> fetchByReference(String reference);

  Future<void> trashLabel({required String label, required String reference});

  Future<List<Label>> fetchAll();
}
