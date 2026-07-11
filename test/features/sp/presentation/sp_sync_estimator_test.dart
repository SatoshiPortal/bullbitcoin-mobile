import 'package:bb_mobile/features/sp/presentation/sp_sync_estimator.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final loc = lookupAppLocalizations(const Locale('en'));

  group('SpSyncEstimator', () {
    final base = DateTime(2026);

    test('returns null until warmup, then estimates remaining seconds', () {
      final est = SpSyncEstimator();
      // 5 updates at a constant 1 s/block. The first seeds state without a
      // sample, so after 5 updates there are only 4 samples (< warmup of 5).
      for (var i = 1; i <= 5; i++) {
        est.update(i, 1000, base.add(Duration(seconds: i - 1)));
      }
      expect(est.estimateSecs(), isNull);

      // 6th update reaches 5 samples -> estimate available.
      est.update(6, 1000, base.add(const Duration(seconds: 5)));
      // remaining = 1000 - 6 = 994 blocks at 1 s/block.
      expect(est.estimateSecs(), 994);
    });

    test('a >60s gap rebases without polluting the rate', () {
      final est = SpSyncEstimator();
      for (var i = 1; i <= 6; i++) {
        est.update(i, 1000, base.add(Duration(seconds: i - 1)));
      }
      expect(est.estimateSecs(), 994);

      // Big gap (300s+): updates remaining but adds no rate sample.
      est.update(200, 1000, base.add(const Duration(seconds: 400)));
      expect(est.estimateSecs(), 800); // remaining 800 * 1 s/block

      // Going backwards (blocksDone <= 0) is ignored.
      est.update(50, 1000, base.add(const Duration(seconds: 410)));
      expect(est.estimateSecs(), 800);
    });

    test('reset clears state', () {
      final est = SpSyncEstimator();
      for (var i = 1; i <= 6; i++) {
        est.update(i, 1000, base.add(Duration(seconds: i - 1)));
      }
      expect(est.estimateSecs(), isNotNull);
      est.reset();
      expect(est.estimateSecs(), isNull);
    });
  });

  group('formatDuration', () {
    test('compact h/m/s', () {
      expect(formatDuration(loc, 3), '3s');
      expect(formatDuration(loc, 90), '1m 30s');
      expect(formatDuration(loc, 3661), '1h 1m');
      expect(formatDuration(loc, 0), '0s');
    });
  });
}
