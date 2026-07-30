import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/get_payjoin_by_tx_id_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPayjoinRepository extends Mock implements PayjoinRepository {}

void main() {
  test(
    'reports a missing Payjoin without wrapping its own exception',
    () async {
      final repository = _MockPayjoinRepository();
      when(
        () => repository.getPayjoinsByTxId('missing'),
      ).thenAnswer((_) async => []);
      final usecase = GetPayjoinByTxIdUsecase(repository);

      await expectLater(
        usecase.execute('missing'),
        throwsA(
          isA<GetPayjoinByTxIdException>().having(
            (exception) => exception.message,
            'message',
            'Payjoin not found',
          ),
        ),
      );
    },
  );

  test('preserves an existing GetPayjoinByTxIdException', () async {
    final repository = _MockPayjoinRepository();
    final exception = GetPayjoinByTxIdException('lookup failed');
    when(() => repository.getPayjoinsByTxId('txid')).thenThrow(exception);
    final usecase = GetPayjoinByTxIdUsecase(repository);

    await expectLater(usecase.execute('txid'), throwsA(same(exception)));
  });
}
