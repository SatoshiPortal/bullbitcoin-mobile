import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_kind.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/presentation/sp_backend_form.dart';
import 'package:bb_mobile/features/sp/presentation/sp_connection_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

const _defaults = SpBackendDefaults(
  blindbitUrl: 'http://fetched-blindbit',
  electrumUrl: 'tcp://fetched-electrum:50001',
);

/// A form mid-fetch with both URLs already tested, so applyDefaults has
/// something to either keep or overwrite.
SpBackendForm testedForm() => const SpBackendForm(
  blindbitUrl: 'http://typed-blindbit',
  electrumUrl: 'tcp://typed-electrum:50001',
  blindbitStatus: SpConnectionStatus.ok,
  electrumStatus: SpConnectionStatus.failed,
  electrumStatusError: SpUnexpected('electrum refused'),
  isFetchingDefaults: true,
);

void main() {
  group('SpBackendForm.applyFetchConcurrencyFactor', () {
    int clamped(int input) => const SpBackendForm()
        .applyFetchConcurrencyFactor(input)
        .fetchConcurrencyFactor;

    test('keeps a factor inside the range', () {
      expect(clamped(7), 7);
    });

    test('clamps zero and negatives up to 1', () {
      expect(clamped(0), 1);
      expect(clamped(-5), 1);
    });

    test('clamps above the maximum down to 32', () {
      expect(clamped(33), 32);
      expect(clamped(9999), 32);
    });

    test('accepts both ends of the range unchanged', () {
      expect(clamped(1), 1);
      expect(clamped(32), 32);
    });

    test('clears a pending error and leaves the match factor alone', () {
      final form = const SpBackendForm(
        error: SpUnexpected('stale'),
        matchConcurrencyFactor: 3,
      ).applyFetchConcurrencyFactor(4);

      expect(form.error, isNull);
      expect(form.matchConcurrencyFactor, 3);
    });
  });

  group('SpBackendForm.applyMatchConcurrencyFactor', () {
    int clamped(int input) => const SpBackendForm()
        .applyMatchConcurrencyFactor(input)
        .matchConcurrencyFactor;

    test('keeps a factor inside the range', () {
      expect(clamped(2), 2);
    });

    test('clamps zero and negatives up to 1', () {
      expect(clamped(0), 1);
      expect(clamped(-5), 1);
    });

    test('clamps above the maximum down to 4', () {
      expect(clamped(5), 4);
      expect(clamped(9999), 4);
    });

    test('accepts both ends of the range unchanged', () {
      expect(clamped(1), 1);
      expect(clamped(4), 4);
    });

    test('clears a pending error and leaves the fetch factor alone', () {
      final form = const SpBackendForm(
        error: SpUnexpected('stale'),
        fetchConcurrencyFactor: 6,
      ).applyMatchConcurrencyFactor(2);

      expect(form.error, isNull);
      expect(form.fetchConcurrencyFactor, 6);
    });
  });

  group('SpBackendForm.applyDefaults', () {
    test('overwrites both urls when the user typed nothing', () {
      final form = testedForm().applyDefaults(_defaults);

      expect(form.isFetchingDefaults, isFalse);
      expect(form.blindbitUrl, 'http://fetched-blindbit');
      expect(form.electrumUrl, 'tcp://fetched-electrum:50001');
      expect(form.blindbitStatus, SpConnectionStatus.untested);
      expect(form.electrumStatus, SpConnectionStatus.untested);
      expect(form.electrumStatusError, isNull);
    });

    test('keeps a blindbit url typed while the fetch was in flight', () {
      final form = testedForm().applyDefaults(_defaults, keepBlindbit: true);

      expect(form.isFetchingDefaults, isFalse);
      expect(form.blindbitUrl, 'http://typed-blindbit');
      expect(form.blindbitStatus, SpConnectionStatus.ok);
      expect(form.electrumUrl, 'tcp://fetched-electrum:50001');
      expect(form.electrumStatus, SpConnectionStatus.untested);
      expect(form.electrumStatusError, isNull);
    });

    test('keeps an electrum url typed while the fetch was in flight', () {
      final form = testedForm().applyDefaults(_defaults, keepElectrum: true);

      expect(form.isFetchingDefaults, isFalse);
      expect(form.electrumUrl, 'tcp://typed-electrum:50001');
      expect(form.electrumStatus, SpConnectionStatus.failed);
      expect(form.electrumStatusError, isA<SpUnexpected>());
      expect(form.blindbitUrl, 'http://fetched-blindbit');
      expect(form.blindbitStatus, SpConnectionStatus.untested);
    });

    test('keeps both urls when the user typed over both', () {
      final form = testedForm().applyDefaults(
        _defaults,
        keepBlindbit: true,
        keepElectrum: true,
      );

      expect(form.isFetchingDefaults, isFalse);
      expect(form.blindbitUrl, 'http://typed-blindbit');
      expect(form.electrumUrl, 'tcp://typed-electrum:50001');
      expect(form.blindbitStatus, SpConnectionStatus.ok);
      expect(form.electrumStatus, SpConnectionStatus.failed);
      expect(form.electrumStatusError, isA<SpUnexpected>());
    });
  });

  group('SpBackendForm.applyNetwork', () {
    test('clears the urls, the tests and the concurrency factors', () {
      final form = const SpBackendForm(
        network: BitcoinNetwork.mainnet,
        blindbitUrl: 'http://old',
        electrumUrl: 'tcp://old:1',
        blindbitStatus: SpConnectionStatus.ok,
        electrumStatus: SpConnectionStatus.failed,
        electrumStatusError: SpUnexpected('old failure'),
        fetchConcurrencyFactor: 30,
        matchConcurrencyFactor: 4,
        error: SpUnexpected('old error'),
      ).applyNetwork(BitcoinNetwork.signet);

      expect(form.network, BitcoinNetwork.signet);
      expect(form.isFetchingDefaults, isTrue);
      expect(form.blindbitUrl, isEmpty);
      expect(form.electrumUrl, isEmpty);
      expect(form.blindbitStatus, SpConnectionStatus.untested);
      expect(form.electrumStatus, SpConnectionStatus.untested);
      expect(form.electrumStatusError, isNull);
      expect(form.error, isNull);
      expect(form.fetchConcurrencyFactor, 12);
      expect(form.matchConcurrencyFactor, 1);
    });
  });

  group('SpBackendForm url helpers', () {
    test('applyUrl resets only that backend test', () {
      final form = testedForm().applyUrl(
        SpBackendKind.blindbit,
        'http://new-blindbit',
      );

      expect(form.blindbitUrl, 'http://new-blindbit');
      expect(form.blindbitStatus, SpConnectionStatus.untested);
      expect(form.electrumUrl, 'tcp://typed-electrum:50001');
      expect(form.electrumStatus, SpConnectionStatus.failed);
    });

    test('urlFor returns the url of the requested backend', () {
      expect(
        testedForm().urlFor(SpBackendKind.blindbit),
        'http://typed-blindbit',
      );
      expect(
        testedForm().urlFor(SpBackendKind.electrum),
        'tcp://typed-electrum:50001',
      );
    });

    test('applyConnectionStatus records the outcome for one backend', () {
      final form = const SpBackendForm().applyConnectionStatus(
        SpBackendKind.electrum,
        SpConnectionStatus.failed,
        const SpBackendUnreachable('no route'),
      );

      expect(form.electrumStatus, SpConnectionStatus.failed);
      expect(form.electrumStatusError, isA<SpBackendUnreachable>());
      expect(form.blindbitStatus, SpConnectionStatus.untested);
      expect(form.blindbitStatusError, isNull);
    });

    test('failFetching leaves the fetching state and holds the failure', () {
      final form = const SpBackendForm(
        isFetchingDefaults: true,
      ).failFetching(const SpBackendUnreachable('blindbit down'));

      expect(form.isFetchingDefaults, isFalse);
      expect(form.error, isA<SpBackendUnreachable>());
    });

    test('startFetching enters the fetching state and clears the error', () {
      final form = const SpBackendForm(
        error: SpUnexpected('stale'),
      ).startFetching();

      expect(form.isFetchingDefaults, isTrue);
      expect(form.error, isNull);
    });
  });
}
