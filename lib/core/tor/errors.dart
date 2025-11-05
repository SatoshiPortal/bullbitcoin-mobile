import 'package:bb_mobile/core/recoverbull/errors.dart';

class TorNotStartedError extends RecoverBullError {
  TorNotStartedError() : super('Tor is not started');
}
