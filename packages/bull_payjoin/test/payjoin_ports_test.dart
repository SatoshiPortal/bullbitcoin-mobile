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
