import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/broadcast_signed_tx_failure.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBroadcastBitcoinTransactionUsecase extends Mock
    implements BroadcastBitcoinTransactionUsecase {}

void main() {
  late BroadcastSignedTxCubit cubit;

  setUp(() {
    cubit = BroadcastSignedTxCubit(
      broadcastBitcoinTransactionUsecase:
          _MockBroadcastBitcoinTransactionUsecase(),
    );
  });

  tearDown(() => cubit.close());

  group('onPushTxPayload', () {
    test('rejects a payload that is not a uri', () async {
      await cubit.onPushTxPayload('not a uri at all');

      expect(cubit.state.failure, isA<InvalidPushTxFailure>());
      expect(cubit.state.pushTxUri, isNull);
    });

    test('rejects a uri with no fragment', () async {
      await cubit.onPushTxPayload('https://coldcard.com/pushtx');

      expect(cubit.state.failure, isA<InvalidPushTxFailure>());
      expect(cubit.state.pushTxUri, isNull);
    });

    test('rejects a fragment without the checksum parameter', () async {
      await cubit.onPushTxPayload('https://coldcard.com/pushtx#t=AgAAAAABAA');

      expect(cubit.state.failure, isA<InvalidPushTxFailure>());
      expect(cubit.state.pushTxUri, isNull);
    });

    test('rejects a fragment without the transaction parameter', () async {
      await cubit.onPushTxPayload('https://coldcard.com/pushtx#c=x0PSGeD');

      expect(cubit.state.failure, isA<InvalidPushTxFailure>());
      expect(cubit.state.pushTxUri, isNull);
    });

    test(
      'reports an unexpected failure when the transaction is not base64url',
      () async {
        await cubit.onPushTxPayload(
          'https://coldcard.com/pushtx#t=!!!not-base64!!!&c=x0PSGeD',
        );

        expect(cubit.state.failure, isA<BroadcastUnexpectedFailure>());
        expect(cubit.state.pushTxUri, isNull);
      },
    );

    test('clears a previous failure before a new attempt', () async {
      await cubit.onPushTxPayload('not a uri at all');
      expect(cubit.state.failure, isA<InvalidPushTxFailure>());

      await cubit.onPushTxPayload('https://coldcard.com/pushtx');
      expect(cubit.state.failure, isA<InvalidPushTxFailure>());
    });
  });
}
