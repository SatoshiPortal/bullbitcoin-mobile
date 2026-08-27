import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:test/test.dart';

void main() {
  test('log events reject raw session identifiers', () {
    expect(
      () => PayjoinLogEvent(
        level: PayjoinLogLevel.info,
        code: PayjoinLogCode.sessionStarted,
        sessionRef: 'bitcoin:address?amount=1',
      ),
      throwsArgumentError,
    );
  });

  test('log events carry the underlying error for the host to report', () {
    final cause = StateError('database is locked');

    final event = PayjoinLogEvent(
      level: PayjoinLogLevel.severe,
      code: PayjoinLogCode.storageFailure,
      error: cause,
    );

    // Without this the host can only report the code, so a locked database and
    // a rejected broadcast reach crash reporting as the same signature.
    expect(event.error, same(cause));
  });

  test('log events accept privacy-safe session references', () {
    expect(
      PayjoinLogEvent(
        level: PayjoinLogLevel.info,
        code: PayjoinLogCode.sessionStarted,
        sessionRef: '0123456789abcdef',
      ).sessionRef,
      '0123456789abcdef',
    );
  });
}
