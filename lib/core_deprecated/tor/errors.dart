import 'package:bb_mobile/core_deprecated/recoverbull/errors.dart';

class TorNotStartedError extends RecoverBullError {
  TorNotStartedError() : super('Tor is not started');
}
