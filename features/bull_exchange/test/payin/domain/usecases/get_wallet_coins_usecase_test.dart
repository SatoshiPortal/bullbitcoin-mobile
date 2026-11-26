import 'package:bull_exchange/src/payin/domain/usecases/get_wallet_coins_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync/sync.dart' show Coin;

void main() {
  test('reads the coins of the asked wallet; none when it can not '
      'tell', () async {
    final asked = <String>[];
    final usecase = GetWalletCoinsUsecase((walletId) async {
      asked.add(walletId);
      return walletId == 'w1' ? const <Coin>[] : null;
    });
    expect(await usecase.execute('w1'), isEmpty);
    expect(await usecase.execute('watch-only'), isNull);
    expect(asked, ['w1', 'watch-only']);
  });
}
