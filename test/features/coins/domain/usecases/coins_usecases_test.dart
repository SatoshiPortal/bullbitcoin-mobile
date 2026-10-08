import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/sync/sync_coordinator.dart';
import 'package:bb_mobile/core/sync/sync_kind.dart';
import 'package:bb_mobile/core/sync/sync_trigger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/coins_failure.dart';
import 'package:bb_mobile/features/coins/domain/usecases/freeze_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/get_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/refresh_coins_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/unfreeze_utxos_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../wallet_utxo_fixture.dart';

class _MockGetWalletUtxosUsecase extends Mock
    implements GetWalletUtxosUsecase {}

class _MockWalletUtxoRepository extends Mock implements WalletUtxoRepository {}

class _MockSyncCoordinator extends Mock implements SyncCoordinator {}

void main() {
  group('RefreshCoinsUsecase', () {
    late _MockSyncCoordinator coordinator;
    late RefreshCoinsUsecase usecase;

    setUp(() {
      coordinator = _MockSyncCoordinator();
      usecase = RefreshCoinsUsecase(coordinator);
    });

    test('requests a user-triggered wallet sync', () async {
      when(
        () => coordinator.sync(trigger: SyncTrigger.user),
      ).thenAnswer((_) async {});

      await usecase.execute();

      verify(() => coordinator.sync(trigger: SyncTrigger.user)).called(1);
    });

    test('settles after a recorded sync failure', () async {
      when(() => coordinator.sync(trigger: SyncTrigger.user)).thenThrow(
        SyncCoordinatorException({SyncKind.bitcoin: Exception('offline')}),
      );

      await expectLater(usecase.execute(), completes);
    });
  });

  group('GetUtxosUsecase', () {
    late _MockGetWalletUtxosUsecase core;
    late GetUtxosUsecase usecase;

    setUp(() {
      core = _MockGetWalletUtxosUsecase();
      usecase = GetUtxosUsecase(getWalletUtxosUsecase: core);
    });

    test('returns the utxos from the core usecase', () async {
      final utxos = [walletUtxoFixture()];
      when(
        () => core.execute(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async => utxos);

      final result = await usecase.execute(walletId: 'w1');

      expect(result, isA<Ok<List<WalletUtxo>, CoinsFailure>>());
      expect((result as Ok).value, utxos);
    });

    test('maps GetUtxosUsecaseException to CoinsLoadFailure', () async {
      when(
        () => core.execute(walletId: any(named: 'walletId')),
      ).thenThrow(GetUtxosUsecaseException('boom'));

      final result = await usecase.execute(walletId: 'w1');

      expect(result, isA<Err<List<WalletUtxo>, CoinsFailure>>());
      expect((result as Err).failure, isA<CoinsLoadFailure>());
    });

    test('maps another exception to CoinsUnexpectedFailure', () async {
      when(
        () => core.execute(walletId: any(named: 'walletId')),
      ).thenThrow(Exception('weird'));

      final result = await usecase.execute(walletId: 'w1');

      expect(result, isA<Err<List<WalletUtxo>, CoinsFailure>>());
      expect((result as Err).failure, isA<CoinsUnexpectedFailure>());
    });

    test('allows programmer errors to propagate', () async {
      when(
        () => core.execute(walletId: any(named: 'walletId')),
      ).thenThrow(StateError('programmer defect'));

      await expectLater(
        usecase.execute(walletId: 'w1'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('FreezeUtxosUsecase', () {
    late _MockWalletUtxoRepository repo;
    late FreezeUtxosUsecase usecase;

    setUp(() {
      repo = _MockWalletUtxoRepository();
      usecase = FreezeUtxosUsecase(walletUtxoRepository: repo);
    });

    test('delegates to repository.freezeUtxos', () async {
      when(
        () => repo.freezeUtxos(
          walletId: any(named: 'walletId'),
          outpoints: any(named: 'outpoints'),
        ),
      ).thenAnswer((_) async {});

      final result = await usecase.execute(
        walletId: 'w1',
        outpoints: [(txId: 'a', vout: 0)],
      );

      expect(result, isA<Ok<void, CoinsFailure>>());
      verify(
        () =>
            repo.freezeUtxos(walletId: 'w1', outpoints: [(txId: 'a', vout: 0)]),
      ).called(1);
    });

    test('maps failure to CoinsFreezeFailure', () async {
      when(
        () => repo.freezeUtxos(
          walletId: any(named: 'walletId'),
          outpoints: any(named: 'outpoints'),
        ),
      ).thenThrow(Exception('db down'));

      final result = await usecase.execute(
        walletId: 'w1',
        outpoints: [(txId: 'a', vout: 0)],
      );

      expect(result, isA<Err<void, CoinsFailure>>());
      expect((result as Err).failure, isA<CoinsFreezeFailure>());
    });

    test('allows programmer errors to propagate', () async {
      when(
        () => repo.freezeUtxos(
          walletId: any(named: 'walletId'),
          outpoints: any(named: 'outpoints'),
        ),
      ).thenThrow(StateError('programmer defect'));

      await expectLater(
        usecase.execute(walletId: 'w1', outpoints: [(txId: 'a', vout: 0)]),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('UnfreezeUtxosUsecase', () {
    late _MockWalletUtxoRepository repo;
    late UnfreezeUtxosUsecase usecase;

    setUp(() {
      repo = _MockWalletUtxoRepository();
      usecase = UnfreezeUtxosUsecase(walletUtxoRepository: repo);
    });

    test('delegates to repository.unfreezeUtxos', () async {
      when(
        () => repo.unfreezeUtxos(
          walletId: any(named: 'walletId'),
          outpoints: any(named: 'outpoints'),
        ),
      ).thenAnswer((_) async {});

      final result = await usecase.execute(
        walletId: 'w1',
        outpoints: [(txId: 'a', vout: 0)],
      );

      expect(result, isA<Ok<void, CoinsFailure>>());
      verify(
        () => repo.unfreezeUtxos(
          walletId: 'w1',
          outpoints: [(txId: 'a', vout: 0)],
        ),
      ).called(1);
    });

    test('maps failure to CoinsUnfreezeFailure', () async {
      when(
        () => repo.unfreezeUtxos(
          walletId: any(named: 'walletId'),
          outpoints: any(named: 'outpoints'),
        ),
      ).thenThrow(Exception('db down'));

      final result = await usecase.execute(
        walletId: 'w1',
        outpoints: [(txId: 'a', vout: 0)],
      );

      expect(result, isA<Err<void, CoinsFailure>>());
      expect((result as Err).failure, isA<CoinsUnfreezeFailure>());
    });

    test('allows programmer errors to propagate', () async {
      when(
        () => repo.unfreezeUtxos(
          walletId: any(named: 'walletId'),
          outpoints: any(named: 'outpoints'),
        ),
      ).thenThrow(StateError('programmer defect'));

      await expectLater(
        usecase.execute(walletId: 'w1', outpoints: [(txId: 'a', vout: 0)]),
        throwsA(isA<StateError>()),
      );
    });
  });
}
