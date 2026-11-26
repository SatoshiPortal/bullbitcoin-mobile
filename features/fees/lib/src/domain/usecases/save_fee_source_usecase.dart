import 'package:fees/fees.dart';
import 'package:primitives/primitives.dart';

import '../fee_source_settings_failure.dart';

class SaveFeeSourceUsecase {
  final Fees _fees;

  const SaveFeeSourceUsecase(this._fees);

  Future<Result<void, FeeSourceSettingsFailure>> execute(
    FeeSource source,
  ) async =>
      (await _fees.saveSource(source))
          .mapErr((_) => const FeeSourceSettingsSaveFailure());
}
