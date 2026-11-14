import 'package:bb_mobile/features/send/public/send_facade.dart';
import 'dart:async';

import 'package:bb_mobile/features/sell/domain/broadcast_sell_payin_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' hide Network;

class _Bitcoin extends Mock implements BroadcastBitcoinTransactionUsecase {}

class _Liquid extends Mock implements BroadcastLiquidTransactionUsecase {}

void main() {
  for (final isLiquid in [false, true]) {
    for (final succeeds in [false, true]) {
      test(
        'sync only after successful ${isLiquid ? "Liquid" : "Bitcoin"} broadcast: $succeeds',
        () async {
          final bitcoin = _Bitcoin();
          final liquid = _Liquid();
          final broadcast = Completer<String>();
          final sync = Completer<void>();
          final wallets = <String>[];
          final facade = WalletFacade(
            const Stream.empty(),
            pollWallet: (id, {required isActive}) {
              expect(isActive(), isTrue);
              wallets.add(id);
              return sync.future;
            },
          );
          when(
            () => bitcoin.execute(
              walletId: any(named: 'walletId'),
              'signed',
              isPsbt: true,
              network: Network.bitcoinTestnet,
            ),
          ).thenAnswer((_) => broadcast.future);
          when(
            () => liquid.execute('signed'),
          ).thenAnswer((_) => broadcast.future);
          final usecase = BroadcastSellPayinUsecase(
            wallet: facade,
            send: SendFacade(bitcoin: bitcoin.execute, liquid: liquid.execute),
          );
          final result = isLiquid
              ? usecase.liquid('signed', walletId: 'source-wallet')
              : usecase.bitcoin(
                  'signed',
                  walletId: 'source-wallet',
                  isPsbt: true,
                  network: Network.bitcoinTestnet,
                );
          expect(wallets, isEmpty);
          if (succeeds) {
            broadcast.complete('txid');
          } else {
            broadcast.completeError(Exception('rejected'));
          }
          final outcome = await result;
          expect(outcome, succeeds ? isA<Ok>() : isA<Err>());
          expect(wallets, succeeds ? ['source-wallet'] : isEmpty);
          // A failed/slow sync cannot delay or turn a broadcast into a failure.
          sync.completeError(Exception('sync unavailable'));
          if (!succeeds) {
            await sync.future.catchError((Object _) {});
          }
          await Future<void>.delayed(Duration.zero);
          expect(wallets.length, succeeds ? 1 : 0);
        },
      );
    }
  }
}
