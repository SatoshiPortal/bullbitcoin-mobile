import 'package:primitives/primitives.dart' hide Network;
import 'package:coins/coins.dart';
import 'package:coins/src/domain/repositories/wallet_utxo_repository.dart';
import 'package:coins/src/domain/usecases/freeze_utxos_usecase.dart';
import 'package:coins/src/domain/usecases/get_utxos_usecase.dart';
import 'package:coins/src/domain/usecases/refresh_coins_usecase.dart';
import 'package:coins/src/domain/usecases/unfreeze_utxos_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:coins/testing.dart';

class _MockWalletUtxoRepository extends Mock implements WalletUtxoRepository {}

void main() {
  group('RefreshCoinsUsecase', () {
    test('requests a screen sync of the wallet', () async {
      final polled = <String>[];
      final usecase = RefreshCoinsUsecase(
        (walletId) async => polled.add(walletId),
      );

      await usecase.execute(walletId: 'w1');

      expect(polled, ['w1']);
    });

    test('settles after a sync failure', () async {
      final usecase = RefreshCoinsUsecase(
        (_) async => throw Exception('offline'),
      );

      await expectLater(usecase.execute(walletId: 'w1'), completes);
    });
  });

  group('GetUtxosUsecase', () {
    late _MockWalletUtxoRepository core;
    late GetUtxosUsecase usecase;

    setUp(() {
      core = _MockWalletUtxoRepository();
      usecase = GetUtxosUsecase(repository: core);
    });

    test('returns the utxos from the repository', () async {
      final utxos = [walletUtxoFixture()];
      when(() => core.getWalletUtxos(walletId: any(named: 'walletId')))
          .thenAnswer((_) async => Ok(utxos));

      final result = await usecase.execute(walletId: 'w1');

      expect(result, isA<Ok<List<WalletUtxo>, CoinsFailure>>());
      expect((result as Ok).value, utxos);
    });

    test('forwards CoinsLoadFailure', () async {
      when(() => core.getWalletUtxos(walletId: any(named: 'walletId')))
          .thenAnswer((_) async => const Err(CoinsLoadFailure()));

      final result = await usecase.execute(walletId: 'w1');

      expect(result, isA<Err<List<WalletUtxo>, CoinsFailure>>());
      expect((result as Err).failure, isA<CoinsLoadFailure>());
    });

    test('forwards CoinsUnexpectedFailure', () async {
      when(() => core.getWalletUtxos(walletId: any(named: 'walletId')))
          .thenAnswer((_) async => const Err(CoinsUnexpectedFailure()));

      final result = await usecase.execute(walletId: 'w1');

      expect(result, isA<Err<List<WalletUtxo>, CoinsFailure>>());
      expect((result as Err).failure, isA<CoinsUnexpectedFailure>());
    });

    test('allows programmer errors to propagate', () async {
      when(() => core.getWalletUtxos(walletId: any(named: 'walletId')))
          .thenAnswer((_) async => throw StateError('programmer defect'));

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
      ).thenAnswer((_) async => const Ok(null));

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

    test('forwards CoinsFreezeFailure', () async {
      when(
        () => repo.freezeUtxos(
          walletId: any(named: 'walletId'),
          outpoints: any(named: 'outpoints'),
        ),
      ).thenAnswer((_) async => const Err(CoinsFreezeFailure()));

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
      ).thenAnswer((_) async => throw StateError('programmer defect'));

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
      ).thenAnswer((_) async => const Ok(null));

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

    test('forwards CoinsUnfreezeFailure', () async {
      when(
        () => repo.unfreezeUtxos(
          walletId: any(named: 'walletId'),
          outpoints: any(named: 'outpoints'),
        ),
      ).thenAnswer((_) async => const Err(CoinsUnfreezeFailure()));

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
      ).thenAnswer((_) async => throw StateError('programmer defect'));

      await expectLater(
        usecase.execute(walletId: 'w1', outpoints: [(txId: 'a', vout: 0)]),
        throwsA(isA<StateError>()),
      );
    });
  });
}
