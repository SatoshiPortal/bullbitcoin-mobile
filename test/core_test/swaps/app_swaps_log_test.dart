import 'package:bb_mobile/core/swaps/swaps_adapters.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLogger extends Mock implements Logger {}

void main() {
  setUpAll(() => registerFallbackValue(StackTrace.empty));

  test('engine detail stays on disk; the reporter gets a fixed label', () {
    final previousLogger = log;
    final logger = _MockLogger();
    log = logger;
    addTearDown(() => log = previousLogger);
    const detail = 'SWAPS: refund failed for abc: bad-txns tx 0f3a… addr bc1q…';

    const AppSwapsLog().severe(detail, error: const FormatException('x'));

    expect(verify(() => logger.warning(captureAny())).captured.single, detail);
    final reported = verify(
      () => logger.severe(
        message: captureAny(named: 'message'),
        error: captureAny(named: 'error'),
        trace: any(named: 'trace'),
      ),
    ).captured;
    expect(
      reported,
      unorderedEquals(['SWAPS: engine failure', FormatException]),
    );
  });

  test('a severe without an error never forwards its message', () {
    final previousLogger = log;
    final logger = _MockLogger();
    log = logger;
    addTearDown(() => log = previousLogger);

    const AppSwapsLog().severe('SWAPS: lockup 0f3a… not recorded');

    final reported = verify(
      () => logger.severe(
        message: captureAny(named: 'message'),
        error: captureAny(named: 'error'),
        trace: any(named: 'trace'),
      ),
    ).captured;
    expect(reported, unorderedEquals(['SWAPS: engine failure', 'swaps']));
  });
}
