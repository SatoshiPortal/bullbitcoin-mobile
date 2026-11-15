import 'package:bb_mobile/features/labels/labels_facade.dart' show LabelsFacade;
import 'package:bb_mobile/features/scan_anything/domain/scan_anything_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;

class ImportScannedLabelsUsecase {
  final LabelsFacade _labelsFacade;

  const ImportScannedLabelsUsecase({required this._labelsFacade});

  @useResult
  Future<Result<int, ScanAnythingFailure>> execute(String jsonl) async =>
      switch (await _labelsFacade.importBip329(jsonl)) {
        Ok(:final value) => Ok(value),
        Err(:final failure) => Err(
          ScanAnythingLabelsImportFailure('${failure.runtimeType}'),
        ),
      };
}
