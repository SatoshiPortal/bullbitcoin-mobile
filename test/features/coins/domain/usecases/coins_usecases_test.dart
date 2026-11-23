import 'package:bb_mobile/features/coins/domain/usecases/freeze_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/get_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/refresh_coins_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/unfreeze_utxos_usecase.dart';
import 'package:coins/coins.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../../wallet_utxo_fixture.dart';

class _MockCoins extends Mock implements Coins {}

void main() {
  test('refresh requests a screen sync of the wallet', () async {
    final polled = <String>[];
    final usecase = RefreshCoinsUsecase(
      (walletId) async => polled.add(walletId),
    );
    await usecase.execute(walletId: 'w1');
    expect(polled, ['w1']);
  });

  test('refresh settles after a sync failure', () async {
    final usecase = RefreshCoinsUsecase(
      (_) async => throw Exception('offline'),
    );
    await expectLater(usecase.execute(walletId: 'w1'), completes);
  });

  test('loading forwards coins and typed failures', () async {
    final coins = _MockCoins();
    final utxos = [walletUtxoFixture()];
    when(() => coins.coins('w1')).thenAnswer((_) async => Ok(utxos));
    final usecase = GetUtxosUsecase(coins);
    expect((await usecase.execute(walletId: 'w1') as Ok).value, utxos);

    when(() => coins.coins('w1'))
        .thenAnswer((_) async => const Err(CoinsLoadFailure()));
    expect(
      (await usecase.execute(walletId: 'w1') as Err).failure,
      isA<CoinsLoadFailure>(),
    );
  });

  test('freeze forwards the wallet, outpoints and typed result', () async {
    final coins = _MockCoins();
    final outpoints = [(txId: 'a', vout: 0)];
    when(() => coins.freeze('w1', outpoints))
        .thenAnswer((_) async => const Ok(null));
    final usecase = FreezeUtxosUsecase(coins);
    expect(
      await usecase.execute(walletId: 'w1', outpoints: outpoints),
      isA<Ok<void, CoinsFailure>>(),
    );
    verify(() => coins.freeze('w1', outpoints)).called(1);

    when(() => coins.freeze('w1', outpoints))
        .thenAnswer((_) async => const Err(CoinsFreezeFailure()));
    expect(
      (await usecase.execute(
        walletId: 'w1',
        outpoints: outpoints,
      ) as Err).failure,
      isA<CoinsFreezeFailure>(),
    );
  });

  test('unfreeze forwards outpoints and typed result', () async {
    final coins = _MockCoins();
    final outpoints = [(txId: 'a', vout: 0)];
    when(() => coins.unfreeze(outpoints))
        .thenAnswer((_) async => const Ok(null));
    final usecase = UnfreezeUtxosUsecase(coins);
    expect(
      await usecase.execute(walletId: 'w1', outpoints: outpoints),
      isA<Ok<void, CoinsFailure>>(),
    );
    verify(() => coins.unfreeze(outpoints)).called(1);

    when(() => coins.unfreeze(outpoints))
        .thenAnswer((_) async => const Err(CoinsUnfreezeFailure()));
    expect(
      (await usecase.execute(
        walletId: 'w1',
        outpoints: outpoints,
      ) as Err).failure,
      isA<CoinsUnfreezeFailure>(),
    );
  });
}
