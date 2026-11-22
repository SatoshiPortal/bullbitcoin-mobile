import 'package:fees/fees.dart';
import 'package:primitives/primitives.dart';

import '../fee_source_settings_failure.dart';

class LoadFeeSourceUsecase {
  final Fees _fees;

  const LoadFeeSourceUsecase(this._fees);

  Future<Result<FeeSource, FeeSourceSettingsFailure>> execute() async =>
      (await _fees.readSource()).mapErr(
        (_) => const FeeSourceSettingsLoadFailure(),
      );
}
