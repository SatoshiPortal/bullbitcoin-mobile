import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

abstract interface class AmountInputPreferenceRepository {
  @useResult
  Future<Result<void, SettingsFailure>> setStartInFiat(bool fiat);
}
