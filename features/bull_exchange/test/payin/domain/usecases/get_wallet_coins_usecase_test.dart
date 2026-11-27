import 'package:bull_exchange/src/payin/domain/usecases/get_wallet_coins_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show Coin;

void main() {
  test('reads the coins of the asked wallet; a failure when it can not '
      'tell', () async {
    final asked = <String>[];
    final usecase = GetWalletCoinsUsecase((walletId) async {
      asked.add(walletId);
      return walletId == 'w1'
          ? const Ok(<Coin>[])
          : const Err(ExchangeWalletCoinsUnavailableFailure());
    });
    expect(
      await usecase.execute('w1'),
      isA<Ok<List<Coin>, ExchangeWalletCoinsUnavailableFailure>>().having(
        (r) => r.value,
        'value',
        isEmpty,
      ),
    );
    expect(
      await usecase.execute('watch-only'),
      isA<Err<List<Coin>, ExchangeWalletCoinsUnavailableFailure>>(),
    );
    expect(asked, ['w1', 'watch-only']);
  });
}
