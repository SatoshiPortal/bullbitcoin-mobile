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
}
