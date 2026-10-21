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
  test('routine traces and persisted milestones use the wallet levels', () {
    final port = _CaptureLogPort();
    final logger = PayjoinLogger(port);

    logger.info(
      code: PayjoinLogCode.sessionResumed,
      role: PayjoinLogRole.sender,
      sessionRef: '0123456789abcdef',
    );
    expect(port.event?.level, PayjoinLogLevel.info);
    expect(port.event?.code, PayjoinLogCode.sessionResumed);
    expect(port.event?.role, PayjoinLogRole.sender);
    expect(port.event?.sessionRef, '0123456789abcdef');

    logger.fine(
      code: PayjoinLogCode.sessionStarted,
      role: PayjoinLogRole.sender,
    );
    expect(port.event?.level, PayjoinLogLevel.fine);
    expect(port.event?.code, PayjoinLogCode.sessionStarted);
    expect(port.event?.role, PayjoinLogRole.sender);
  });

  test('a proposal persistence failure keeps its storage classification', () {
    final port = _CaptureLogPort();
    final logger = PayjoinLogger(port);

    logger.severe(
      code: PayjoinLogCode.storageFailure,
      sessionRef: 'raw-session-id',
      error: StateError('write failed'),
      trace: StackTrace.current,
    );

    expect(
      port.event?.code,
      PayjoinLogCode.storageFailure,
      reason: 'a storage failure must stay distinguishable from other faults',
    );
    expect(port.event?.sessionRef, matches(RegExp(r'^[0-9a-f]{16}$')));
    expect(port.event?.sessionRef, isNot('raw-session-id'));
  });

  test('the logger forwards structured cause and trace metadata', () {
    final port = _CaptureLogPort();
    final logger = PayjoinLogger(port);
    final cause = StateError('write failed');
    final trace = StackTrace.current;

    logger.severe(
      code: PayjoinLogCode.storageFailure,
      error: cause,
      trace: trace,
    );

    expect(port.event?.error, same(cause));
    expect(port.event?.trace, same(trace));
  });

  test('a warning keeps its cause too', () {
    final port = _CaptureLogPort();
    final logger = PayjoinLogger(port);
    final cause = StateError('relay timed out');

    logger.warning(code: PayjoinLogCode.relayFailure, error: cause);

    expect(port.event?.error, same(cause));
  });
}
