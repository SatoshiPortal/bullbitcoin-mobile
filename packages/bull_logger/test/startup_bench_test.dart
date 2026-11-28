import 'package:bull_logger/startup_bench.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// `StartupBench` only writes fixed labels, in non-release builds, to the console.
/// The release guard (`kReleaseMode`) is a compile-time constant, so it cannot
/// be exercised here: a release build is verified on device instead. These
/// tests cover the shape of the line, the one-shot behaviour and the implicit
/// start, through the `debugPrint` seam the class itself uses.
void main() {
  late List<String> printed;
  late DebugPrintCallback original;

  setUp(() {
    StartupBench.reset();
    printed = <String>[];
    original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) printed.add(message);
    };
  });

  tearDown(() => debugPrint = original);

  test('start emits app_start and every mark is a fixed label line', () {
    StartupBench.start();
    StartupBench.mark('unit_test_phase');

    expect(printed, hasLength(2));
    expect(printed.first, contains('ph=app_start'));
    expect(printed.last, contains('ph=unit_test_phase'));
    for (final String line in printed) {
      expect(
        line,
        matches(
          RegExp(r'^BULL_STARTUP_BENCH v=1 ph=[a-z0-9_]+ t_us=\d+ d_us=-?\d+$'),
        ),
        reason: 'fixed labels and numbers only, never user data',
      );
    }
  });

  test('markOnce writes a label at most once', () {
    StartupBench.markOnce('unit_test_once');
    StartupBench.markOnce('unit_test_once');

    expect(
      printed.where((String line) => line.contains('ph=app_start')),
      hasLength(1),
    );
    expect(
      printed.where((String line) => line.contains('ph=unit_test_once')),
      hasLength(1),
    );
  });

  test('a mark before start begins the watch implicitly', () {
    StartupBench.mark('unit_test_implicit');

    expect(printed, hasLength(2));
    expect(printed.first, contains('ph=app_start'));
    expect(printed.last, contains('ph=unit_test_implicit'));
  });
}
