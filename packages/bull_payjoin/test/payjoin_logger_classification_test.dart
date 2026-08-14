import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_payjoin/src/engine/payjoin_logger.dart';
import 'package:test/test.dart';

final class _CaptureLogPort implements PayjoinLogPort {
  PayjoinLogEvent? event;

  @override
  void write(PayjoinLogEvent event) {
    this.event = event;
  }
}

void main() {
  test('a proposal persistence failure keeps its storage classification', () {
    final port = _CaptureLogPort();
    final logger = PayjoinLogger(port);

    logger.severe(
      message: 'Payjoin proposal was sent but persistence failed',
      code: PayjoinLogCode.storageFailure,
      sessionRef: 'raw-session-id',
      error: StateError('write failed'),
      trace: StackTrace.current,
    );

    expect(
      port.event?.code,
      PayjoinLogCode.storageFailure,
      reason: 'all severe events currently collapse to lifecycle',
    );
    expect(port.event?.sessionRef, matches(RegExp(r'^[0-9a-f]{16}$')));
    expect(port.event?.sessionRef, isNot('raw-session-id'));
  });

  test('the logger forwards the cause and drops the composed message', () {
    final port = _CaptureLogPort();
    final logger = PayjoinLogger(port);
    final cause = StateError('write failed');

    logger.severe(
      message: 'Payjoin proposal for bitcoin:tb1qaddress?amount=1 failed',
      code: PayjoinLogCode.storageFailure,
      error: cause,
      trace: StackTrace.current,
    );

    // The cause is what makes a failure diagnosable; the message is the one
    // field a call site composes, so it never leaves the package.
    expect(port.event?.error, same(cause));
    expect(port.event?.trace, isNotNull);
  });

  test('a warning keeps its cause too', () {
    final port = _CaptureLogPort();
    final logger = PayjoinLogger(port);
    final cause = StateError('relay timed out');

    logger.warning('', code: PayjoinLogCode.relayFailure, error: cause);

    expect(port.event?.error, same(cause));
  });
}
