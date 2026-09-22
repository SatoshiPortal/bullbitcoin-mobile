import 'package:bb_mobile/core/sync/sync_coordinator.dart';
import 'package:bb_mobile/core/sync/sync_trigger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/sync_wallets_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSyncCoordinator extends Mock implements SyncCoordinator {}

/// The wallet feature's boundary around [SyncCoordinator], which is a shared
/// core service that still throws (#1895). Nothing above this may see the
/// raw exception.
void main() {
  late _MockSyncCoordinator coordinator;
  late SyncWalletsUsecase usecase;

  setUpAll(() => registerFallbackValue(SyncTrigger.automatic));

  setUp(() {
    coordinator = _MockSyncCoordinator();
    usecase = SyncWalletsUsecase(coordinator);
  });

  test('a completed sync round is Ok', () async {
    when(
      () => coordinator.sync(trigger: any(named: 'trigger')),
    ).thenAnswer((_) async {});

    expect(await usecase.execute(), isA<Ok<void, WalletFailure>>());
  });

  test('forwards the trigger it was given', () async {
    when(
      () => coordinator.sync(trigger: any(named: 'trigger')),
    ).thenAnswer((_) async {});

    // The result is asserted too because `execute` is `@useResult` — the
    // annotation is doing its job here and discarding it is a warning.
    expect(
      await usecase.execute(trigger: SyncTrigger.user),
      isA<Ok<void, WalletFailure>>(),
    );

    verify(() => coordinator.sync(trigger: SyncTrigger.user)).called(1);
  });

  test('sanitizes a throwing sync round into WalletSyncFailure', () async {
    when(() => coordinator.sync(trigger: any(named: 'trigger'))).thenThrow(
      Exception('electrum.blockstream.info:50002 handshake failed: cert'),
    );

    final result = await usecase.execute();

    final failure = (result as Err).failure as WalletFailure;
    expect(failure, isA<WalletSyncFailure>());
    // Sync is the one failure with a server-settings remedy, so the *type*
    // has to survive; the server hostname and TLS detail must not.
    expect(failure.logMessage, isNot(contains('electrum.blockstream.info')));
    expect(failure.logMessage, isNot(contains('handshake failed')));
  });

  test('sanitizes the coordinators own aggregate exception', () async {
    // SyncCoordinatorException aggregates per-kind failures, so its toString()
    // is the most likely place for a raw reason to leak upward.
    when(
      () => coordinator.sync(trigger: any(named: 'trigger')),
    ).thenThrow(StateError('bdk: Descriptor(Key(InvalidKey))'));

    final result = await usecase.execute();

    final failure = (result as Err).failure as WalletFailure;
    expect(failure, isA<WalletSyncFailure>());
    expect(failure.logMessage, isNot(contains('InvalidKey')));
  });
}
