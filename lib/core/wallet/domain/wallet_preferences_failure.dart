import 'package:bb_mobile/core/failures/failure.dart';

sealed class WalletPreferencesFailure extends Failure {
  const WalletPreferencesFailure([super.logMessage]);
}

final class WalletPreferencesStorageFailure extends WalletPreferencesFailure {
  const WalletPreferencesStorageFailure([super.logMessage]);
}
