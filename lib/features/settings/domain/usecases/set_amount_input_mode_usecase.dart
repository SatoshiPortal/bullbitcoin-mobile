import 'package:bb_mobile/features/settings/domain/repositories/amount_input_preference_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class SetAmountInputModeUsecase {
  final AmountInputPreferenceRepository _repository;

  const SetAmountInputModeUsecase(this._repository);

  @useResult
  Future<Result<void, SettingsFailure>> execute({required bool fiat}) =>
      _repository.setStartInFiat(fiat);
}
