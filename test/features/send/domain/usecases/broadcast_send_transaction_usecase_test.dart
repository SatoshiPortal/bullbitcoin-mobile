import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_sync_operation_exception.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/broadcast_send_transaction_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

class _Broadcast extends Mock implements BroadcastBitcoinTransactionUsecase {}

void main() {
  test(
    'the source wallet is forwarded and saved-but-unrelayed stays typed',
    () async {
      final core = _Broadcast();
      final usecase = BroadcastSendTransactionUsecase(broadcast: core);
      when(
        () => core.execute(
          'public-raw',
          isPsbt: false,
          walletId: 'private-wallet',
        ),
      ).thenThrow(
        const BitcoinSyncOperationException(CbfBroadcastNotRelayedFailure()),
      );
      final result = await usecase.execute(
        'public-raw',
        isPsbt: false,
        walletId: 'private-wallet',
      );
      expect(result, isA<Err<String, SendFailure>>());
      if (result case Err(:final failure)) {
        expect(failure, isA<SendPrivateBroadcastFailure>());
      }
      verify(
        () => core.execute(
          'public-raw',
          isPsbt: false,
          walletId: 'private-wallet',
        ),
      ).called(1);
    },
  );
  test(
    'Tor unavailability stays distinct from a transaction rejection',
    () async {
      final core = _Broadcast();
      when(
        () => core.execute(
          'public-raw',
          isPsbt: false,
          walletId: 'private-wallet',
        ),
      ).thenThrow(
        const BitcoinSyncOperationException(CbfTorUnavailableFailure()),
      );
      final result = await BroadcastSendTransactionUsecase(
        broadcast: core,
      ).execute('public-raw', isPsbt: false, walletId: 'private-wallet');
      if (result case Err(:final failure)) {
        expect(failure, isA<SendPrivateTorFailure>());
      } else {
        fail('Tor must fail closed');
      }
    },
  );
}
