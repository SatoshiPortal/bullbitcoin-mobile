import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBroadcastBitcoinTransactionUsecase extends Mock
    implements BroadcastBitcoinTransactionUsecase {}

void main() {
  late _MockBroadcastBitcoinTransactionUsecase broadcastUsecase;

  setUp(() {
    broadcastUsecase = _MockBroadcastBitcoinTransactionUsecase();
  });

  BroadcastSignedTxCubit buildCubit() => BroadcastSignedTxCubit(
    broadcastBitcoinTransactionUsecase: broadcastUsecase,
    request: const BroadcastSignedTxRequest(collectSignerResult: true),
  );

  group('signer result collection', () {
    test('stores the signer result for authoritative validation', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.tryParseTransaction('signer-result');

      expect(cubit.state.collectedSignerResult, 'signer-result');
      expect(cubit.state.failure, isNull);
    });

    test('collects a non-BBQR signer QR directly', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.onQrScanned('signer-result');

      expect(cubit.state.collectedSignerResult, 'signer-result');
    });
  });
}
