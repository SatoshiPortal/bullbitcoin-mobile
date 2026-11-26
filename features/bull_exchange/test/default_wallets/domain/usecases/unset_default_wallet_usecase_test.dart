import 'package:bull_exchange/src/default_wallets/domain/usecases/unset_default_wallet_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'default_wallets_usecase_test_support.dart';

Exchange _exchange(List<String> sent, ExchangeWrite<void> answer) =>
    exchangeForTesting(
      access: fixedAccessForTesting(const ExchangeAccessSignedIn(dwSession)),
      deleteDefaultWallet:
          ({
            required recipientId,
            required walletType,
            required address,
          }) async {
            sent.add('${walletType.name} $recipientId $address');
            return answer;
          },
    );

void main() {
  test('unsets the recipient of the network it was given', () async {
    final sent = <String>[];
    final write =
        await UnsetDefaultWalletUsecase(_exchange(sent, const WriteDone(null)))
            .execute(
              dwSession,
              network: BtcNetwork.bitcoin,
              recipientId: 'r-1',
              address: 'bc1qsaved',
            );
    expect(sent, ['bitcoin r-1 bc1qsaved']);
    expect(
      (write as GateAdmitted<ExchangeWrite<void>>).result,
      isA<WriteDone<void>>(),
    );
  });

  test('a refused unset stays refused', () async {
    final write =
        await UnsetDefaultWalletUsecase(
          _exchange([], const WriteRefused(ExchangeRefusal(httpStatus: 400))),
        ).execute(
          dwSession,
          network: BtcNetwork.bitcoin,
          recipientId: 'r-1',
          address: 'bc1qsaved',
        );
    expect(
      (write as GateAdmitted<ExchangeWrite<void>>).result,
      isA<WriteRefused<void>>(),
    );
  });

  test('an unset for another session is never sent', () async {
    final sent = <String>[];
    final write =
        await UnsetDefaultWalletUsecase(_exchange(sent, const WriteDone(null)))
            .execute(
              dwOtherSession,
              network: BtcNetwork.bitcoin,
              recipientId: 'r-1',
              address: 'bc1qsaved',
            );
    expect(sent, isEmpty);
    expect(
      (write as GateAdmitted<ExchangeWrite<void>>).result,
      isA<WriteNotSent<void>>(),
    );
  });
}
