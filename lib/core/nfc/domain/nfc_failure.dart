import 'package:bb_mobile/core/failures/failure.dart';

sealed class NfcFailure extends Failure {
  const NfcFailure([super.logMessage]);
}

final class NfcUnsupportedFailure extends NfcFailure {
  const NfcUnsupportedFailure([super.logMessage]);
}

final class NfcDisabledFailure extends NfcFailure {
  const NfcDisabledFailure([super.logMessage]);
}

final class NfcCancelledFailure extends NfcFailure {
  const NfcCancelledFailure([super.logMessage]);
}

final class NfcTimeoutFailure extends NfcFailure {
  const NfcTimeoutFailure([super.logMessage]);
}

final class NfcBusyFailure extends NfcFailure {
  const NfcBusyFailure([super.logMessage]);
}

final class NfcTagLostFailure extends NfcFailure {
  const NfcTagLostFailure([super.logMessage]);
}

final class NfcUnsupportedTagFailure extends NfcFailure {
  const NfcUnsupportedTagFailure([super.logMessage]);
}

final class NfcInvalidPayloadFailure extends NfcFailure {
  const NfcInvalidPayloadFailure([super.logMessage]);
}

final class NfcWriteFailure extends NfcFailure {
  const NfcWriteFailure([super.logMessage]);
}

final class NfcUnexpectedFailure extends NfcFailure {
  const NfcUnexpectedFailure([super.logMessage]);
}
