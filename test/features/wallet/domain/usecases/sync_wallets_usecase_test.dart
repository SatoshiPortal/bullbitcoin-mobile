import 'package:transaction_sync/read.dart';
import 'package:transaction_sync/transaction_sync.dart'
    show TransactionSyncBusyFailure;
import 'package:bb_mobile/features/wallet/data/sync_coordinator.dart';
import 'package:bb_mobile/features/wallet/domain/sync_kind.dart';
import 'package:bb_mobile/features/wallet/domain/sync_trigger.dart';
import 'package:primitives/primitives.dart' hide Network;
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/sync_wallets_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSyncCoordinator extends Mock implements SyncCoordinator {}

/// The failure an [Err] carries; an [Ok] fails the test.
WalletFailure _failureOf(Result<void, WalletFailure> result) =>
    switch (result) {
      Ok() => fail('expected an Err, got Ok'),
      Err(:final failure) => failure,
    };

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

  for (final mixed in [false, true]) {
    test('busy round preserves classification, mixed=$mixed', () async {
      when(() => coordinator.sync(trigger: any(named: 'trigger'))).thenThrow(
        SyncCoordinatorException({
          SyncKind.bitcoin: const WalletSnapshotException(
            TransactionSyncBusyFailure(),
          ),
          if (mixed) SyncKind.liquid: Exception('connection'),
        }),
      );
      final failure = _failureOf(await usecase.execute());
      expect(
        failure,
        mixed ? isA<WalletSyncFailure>() : isA<WalletSyncBusyFailure>(),
      );
    });
  }

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

    final failure = _failureOf(await usecase.execute());

    expect(failure, isA<WalletSyncFailure>());
    // Sync is the one failure with a server-settings remedy, so the *type*
    // has to survive; the server hostname and TLS detail must not.
    expect(failure.logMessage, isNot(contains('electrum.blockstream.info')));
    expect(failure.logMessage, isNot(contains('handshake failed')));
  });

  test('sanitizes the coordinators own aggregate exception', () async {
    // SyncCoordinatorException aggregates per-kind failures, so its toString()
    // is the most likely place for a raw reason to leak upward.
    when(() => coordinator.sync(trigger: any(named: 'trigger'))).thenThrow(
      SyncCoordinatorException({
        SyncKind.bitcoin: Exception('bdk: Descriptor(Key(InvalidKey))'),
      }),
    );

    final failure = _failureOf(await usecase.execute());

    expect(failure, isA<WalletSyncFailure>());
    expect(failure.logMessage, isNot(contains('InvalidKey')));
  });
}
