import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/coins_error.dart';
import 'package:bb_mobile/features/coins/domain/usecases/freeze_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/get_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/unfreeze_utxos_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../wallet_utxo_fixture.dart';

class _MockGetWalletUtxosUsecase extends Mock
    implements GetWalletUtxosUsecase {}

class _MockWalletUtxoRepository extends Mock implements WalletUtxoRepository {}

void main() {
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

      expect(result, utxos);
    });

    test('maps GetUtxosUsecaseException to CoinsError.loadFailed', () async {
      when(
        () => core.execute(walletId: any(named: 'walletId')),
      ).thenThrow(GetUtxosUsecaseException('boom'));

      expect(
        () => usecase.execute(walletId: 'w1'),
        throwsA(isA<LoadFailedCoinsError>()),
      );
    });

    test('maps any other error to CoinsError.unexpected', () async {
      when(
        () => core.execute(walletId: any(named: 'walletId')),
      ).thenThrow(Exception('weird'));

      expect(
        () => usecase.execute(walletId: 'w1'),
        throwsA(isA<UnexpectedCoinsError>()),
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

      await usecase.execute(walletId: 'w1', outpoints: [(txId: 'a', vout: 0)]);

      verify(
        () =>
            repo.freezeUtxos(walletId: 'w1', outpoints: [(txId: 'a', vout: 0)]),
      ).called(1);
    });

    test('maps failure to CoinsError.freezeFailed', () async {
      when(
        () => repo.freezeUtxos(
          walletId: any(named: 'walletId'),
          outpoints: any(named: 'outpoints'),
        ),
      ).thenThrow(Exception('db down'));

      expect(
        () =>
            usecase.execute(walletId: 'w1', outpoints: [(txId: 'a', vout: 0)]),
        throwsA(isA<FreezeFailedCoinsError>()),
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

      await usecase.execute(walletId: 'w1', outpoints: [(txId: 'a', vout: 0)]);

      verify(
        () => repo.unfreezeUtxos(
          walletId: 'w1',
          outpoints: [(txId: 'a', vout: 0)],
        ),
      ).called(1);
    });

    test('maps failure to CoinsError.unfreezeFailed', () async {
      when(
        () => repo.unfreezeUtxos(
          walletId: any(named: 'walletId'),
          outpoints: any(named: 'outpoints'),
        ),
      ).thenThrow(Exception('db down'));

      expect(
        () =>
            usecase.execute(walletId: 'w1', outpoints: [(txId: 'a', vout: 0)]),
        throwsA(isA<UnfreezeFailedCoinsError>()),
      );
    });
  });
}
