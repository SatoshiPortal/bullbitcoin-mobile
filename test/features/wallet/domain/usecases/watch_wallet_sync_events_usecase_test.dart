import 'dart:async';

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_sync_result.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_electrum_sync_results_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_wallet_sync_events_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchStarted extends Mock
    implements WatchStartedWalletSyncsUsecase {}

class _MockWatchFinished extends Mock
    implements WatchFinishedWalletSyncsUsecase {}

class _MockWatchElectrum extends Mock
    implements WatchElectrumSyncResultsUsecase {}

class _MockWallet extends Mock implements Wallet {}

class _MockElectrumSyncResult extends Mock implements ElectrumSyncResult {}

/// The three watchers behind the home screen's syncing indicators.
///
/// The behaviour under test is survival: a watcher that errors must keep
/// delivering later events, because the alternative is indicators frozen
/// until the screen is rebuilt.
void main() {
  late _MockWatchStarted watchStarted;
  late _MockWatchFinished watchFinished;
  late _MockWatchElectrum watchElectrum;
  late WatchWalletSyncEventsUsecase usecase;

  setUp(() {
    watchStarted = _MockWatchStarted();
    watchFinished = _MockWatchFinished();
    watchElectrum = _MockWatchElectrum();
    usecase = WatchWalletSyncEventsUsecase(
      watchStarted: watchStarted,
      watchFinished: watchFinished,
      watchElectrum: watchElectrum,
    );
  });

  test('wraps each event in Ok', () async {
    final wallet = _MockWallet();
    when(
      () => watchStarted.execute(walletId: any(named: 'walletId')),
    ).thenAnswer((_) => Stream.value(wallet));

    final events = await usecase.started().toList();

    expect(events, [isA<Ok<Wallet, WalletFailure>>()]);
    expect((events.single as Ok).value, wallet);
  });

  test('a stream error becomes an Err WITHOUT ending the stream', () async {
    // The regression this guards: an `await for` would rethrow and kill the
    // subscription, so one hiccup froze the sync indicator permanently.
    final wallet = _MockWallet();
    when(
      () => watchStarted.execute(walletId: any(named: 'walletId')),
    ).thenAnswer(
      (_) => Stream<Wallet>.multi((controller) {
        controller.addError(Exception('electrum read timed out'));
        controller.add(wallet);
        controller.close();
      }),
    );

    final events = await usecase.started().toList();

    expect(events, hasLength(2));
    expect(events.first, isA<Err<Wallet, WalletFailure>>());
    // The later event still arrives — the subscription survived.
    expect(events.last, isA<Ok<Wallet, WalletFailure>>());
  });

  test('a throw on subscribe becomes a single Err event', () async {
    when(
      () => watchFinished.execute(walletId: any(named: 'walletId')),
    ).thenThrow(StateError('stream controller already closed'));

    final events = await usecase.finished().toList();

    expect(events, hasLength(1));
    expect((events.single as Err).failure, isA<WalletSyncFailure>());
  });

  test('sanitizes the stream error text', () async {
    when(() => watchElectrum.execute()).thenAnswer(
      (_) => Stream<ElectrumSyncResult>.error(
        Exception('ssl://electrum.example.com:50002 rejected: bad cert'),
      ),
    );

    final events = await usecase.electrumResults().toList();

    final failure = (events.single as Err).failure as WalletFailure;
    expect(failure, isA<WalletSyncFailure>());
    expect(failure.logMessage, isNot(contains('electrum.example.com')));
    expect(failure.logMessage, isNot(contains('bad cert')));
  });

  test('electrum results are forwarded as Ok', () async {
    final result = _MockElectrumSyncResult();
    when(() => watchElectrum.execute()).thenAnswer((_) => Stream.value(result));

    final events = await usecase.electrumResults().toList();

    expect((events.single as Ok).value, result);
  });
}
