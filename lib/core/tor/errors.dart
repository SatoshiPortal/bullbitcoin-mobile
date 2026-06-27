import 'package:bb_mobile/core/errors/bull_exception.dart';

class TorNotStartedError extends BullException {
  TorNotStartedError() : super('Tor is not started');
}
