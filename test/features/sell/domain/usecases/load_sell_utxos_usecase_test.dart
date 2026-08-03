import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/features/sell/domain/usecases/load_sell_utxos_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetWalletUtxosUsecase extends Mock implements GetWalletUtxosUsecase {}

void main() {
  late MockGetWalletUtxosUsecase getWalletUtxosUsecase;
  late LoadSellUtxosUsecase usecase;

  setUp(() {
    getWalletUtxosUsecase = MockGetWalletUtxosUsecase();
    usecase = LoadSellUtxosUsecase(
      getWalletUtxosUsecase: getWalletUtxosUsecase,
    );
  });

  group('LoadSellUtxosUsecase', () {
    test('returns Ok(utxos) on success', () async {
      const utxos = <WalletUtxo>[];
      when(
        () => getWalletUtxosUsecase.execute(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async => utxos);

      final result = await usecase.execute(walletId: 'wallet-1');

      expect(result, isA<Ok<List<WalletUtxo>, SellFailure>>());
      expect((result as Ok).value, utxos);
    });

    test(
      'returns Err(SellLoadUtxosFailure) on exception — raw message in logMessage only, no leak',
      () async {
        when(
          () => getWalletUtxosUsecase.execute(walletId: any(named: 'walletId')),
        ).thenThrow(Exception('electrum boom'));

        final result = await usecase.execute(walletId: 'wallet-1');

        expect(result, isA<Err<List<WalletUtxo>, SellFailure>>());
        final failure = (result as Err).failure;
        expect(failure, isA<SellLoadUtxosFailure>());
        expect(
          (failure as SellLoadUtxosFailure).logMessage,
          contains('electrum boom'),
        );
      },
    );
  });
}
