import 'package:bb_mobile/core/failures/failure.dart';

/// Closed set of failures shown in the server-list section of the Electrum
/// settings screen. Lifted from the core [ElectrumFailure] by the bloc and
/// rendered via the presentation `toTranslated` extension — the raw reason
/// stays in [Failure.logMessage] (logs only) and never reaches the UI.
sealed class ElectrumServersFailure extends Failure {
  const ElectrumServersFailure([super.logMessage]);
}

final class ElectrumServersLoadFailure extends ElectrumServersFailure {
  const ElectrumServersLoadFailure([super.logMessage]);
}

final class ElectrumServersSavePriorityFailure extends ElectrumServersFailure {
  const ElectrumServersSavePriorityFailure([super.logMessage]);
}

final class ElectrumServersAddFailure extends ElectrumServersFailure {
  const ElectrumServersAddFailure([super.logMessage]);
}

final class ElectrumServersDeleteFailure extends ElectrumServersFailure {
  const ElectrumServersDeleteFailure([super.logMessage]);
}

final class ElectrumServersAlreadyExistsFailure extends ElectrumServersFailure {
  const ElectrumServersAlreadyExistsFailure([super.logMessage]);
}

final class ElectrumServersUnreachableFailure extends ElectrumServersFailure {
  const ElectrumServersUnreachableFailure([super.logMessage]);
}

final class ElectrumServersExternalTorProxyUnavailableFailure
    extends ElectrumServersFailure {
  const ElectrumServersExternalTorProxyUnavailableFailure([
    super.logMessage,
  ]);
}

final class ElectrumServersUnexpectedFailure extends ElectrumServersFailure {
  const ElectrumServersUnexpectedFailure([super.logMessage]);
}

/// Closed set of failures shown in the advanced-options sheet. The `Invalid*`
/// variants carry the offending [value] (sanitized user input) for its
/// message; the rest carry only [Failure.logMessage].
sealed class AdvancedOptionsFailure extends Failure {
  const AdvancedOptionsFailure([super.logMessage]);
}

final class AdvancedOptionsInvalidStopGapFailure
    extends AdvancedOptionsFailure {
  final String value;

  const AdvancedOptionsInvalidStopGapFailure(this.value, [super.logMessage]);
}

final class AdvancedOptionsInvalidTimeoutFailure
    extends AdvancedOptionsFailure {
  final String value;

  const AdvancedOptionsInvalidTimeoutFailure(this.value, [super.logMessage]);
}

final class AdvancedOptionsInvalidRetryFailure extends AdvancedOptionsFailure {
  final String value;

  const AdvancedOptionsInvalidRetryFailure(this.value, [super.logMessage]);
}

final class AdvancedOptionsSaveFailure extends AdvancedOptionsFailure {
  const AdvancedOptionsSaveFailure([super.logMessage]);
}

final class AdvancedOptionsUnexpectedFailure extends AdvancedOptionsFailure {
  const AdvancedOptionsUnexpectedFailure([super.logMessage]);
}
