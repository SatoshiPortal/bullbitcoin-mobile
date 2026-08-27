import 'package:bb_mobile/core/failures/failure.dart';

sealed class GetPaidSettingsFailure extends Failure {
  const GetPaidSettingsFailure();
}

final class GetPaidSettingsUnavailableFailure extends GetPaidSettingsFailure {
  const GetPaidSettingsUnavailableFailure();
}
