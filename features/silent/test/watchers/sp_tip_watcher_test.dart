import 'package:primitives/primitives.dart';

import 'dart:async';

import 'package:silent/src/domain/entities/sp_update.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/watchers/sp_tip_watcher.dart';
import 'package:silent/src/domain/usecases/sync_sp_wallet_usecase.dart';
import 'package:silent/src/domain/usecases/watch_sp_updates_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchSpUpdatesUsecase extends Mock
    implements WatchSpUpdatesUsecase {}

class _MockSyncSpWalletUsecase extends Mock implements SyncSpWalletUsecase {}

void main() {
  late StreamController<SilentUpdate> updates;
  late _MockWatchSpUpdatesUsecase watchUsecase;
  late _MockSyncSpWalletUsecase syncUsecase;
  late SpTipWatcher watcher;

  setUp(() {
    updates = StreamController<SilentUpdate>.broadcast();
    watchUsecase = _MockWatchSpUpdatesUsecase();
    syncUsecase = _MockSyncSpWalletUsecase();
    when(() => watchUsecase.execute()).thenAnswer((_) => updates.stream);
    when(() => syncUsecase.execute())
        .thenAnswer((_) async => const Ok<void, SilentFailure>(null));
    watcher = SpTipWatcher(
      watchSpUpdatesUsecase: watchUsecase,
      syncSpWalletUsecase: syncUsecase,
    );
    watcher.start();
  });

  tearDown(() async {
    await watcher.dispose();
    await updates.close();
  });

  Future<void> emit(SilentUpdate update) async {
    updates.add(update);
    await Future<void>.delayed(Duration.zero);
  }

  test('a tip landing re-runs the sync', () async {
    await emit(const SilentChainTipChanged(900000));

    verify(() => syncUsecase.execute()).called(1);
  });

  test('the same tip repeated syncs only once', () async {
    await emit(const SilentChainTipChanged(900000));
    await emit(const SilentChainTipChanged(900000));

    verify(() => syncUsecase.execute()).called(1);
  });

  test('a new block syncs again', () async {
    await emit(const SilentChainTipChanged(900000));
    await emit(const SilentChainTipChanged(900001));

    verify(() => syncUsecase.execute()).called(2);
  });

  test('other updates never sync', () async {
    await emit(const SilentSetupChanged());
    await emit(SilentBalanceChanged(Sats.fromInt(1000)));

    verifyNever(() => syncUsecase.execute());
  });

  test('a sync failure is swallowed, the watcher stays alive', () async {
    when(() => syncUsecase.execute()).thenAnswer(
      (_) async => const Err<void, SilentFailure>(SilentUnexpected('boom')),
    );

    await emit(const SilentChainTipChanged(900000));
    await emit(const SilentChainTipChanged(900001));

    verify(() => syncUsecase.execute()).called(2);
  });

  test('dispose stops further syncs', () async {
    await watcher.dispose();

    await emit(const SilentChainTipChanged(900000));

    verifyNever(() => syncUsecase.execute());
  });
}
