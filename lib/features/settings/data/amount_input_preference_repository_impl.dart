import 'package:bb_mobile/features/settings/data/settings_datasource.dart';
import 'package:bb_mobile/features/settings/domain/repositories/amount_input_preference_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

class AmountInputPreferenceRepositoryImpl
    implements AmountInputPreferenceRepository {
  final SettingsDatasource _datasource;

  const AmountInputPreferenceRepositoryImpl(this._datasource);

  @override
  Future<Result<void, SettingsFailure>> setStartInFiat(bool fiat) async {
    try {
      await _datasource.setStartAmountsInFiat(fiat);
      return const Ok(null);
    } on Exception catch (error, stack) {
      log.severe(
        message: 'Failed to persist amount input preference',
        error: error.runtimeType,
        trace: stack,
      );
      return const Err(SettingsStorageFailure());
    }
  }
}
