import 'dart:async';
import 'package:bb_mobile/features/transactions/domain/repositories/cbf_recovery_repository.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/retry_unrelayed_transaction_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/cancel_unrelayed_transaction_usecase.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/cbf_recovery_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

class _Repository implements CbfRecoveryRepository {
  final result = Completer<Result<void, TransactionFailure>>();
  final calls = <String>[];
  @override
  Future<Result<void, TransactionFailure>> retry(String walletId, String txid) {
    calls.add('retry:$walletId:$txid');
    return result.future;
  }

  @override
  Future<Result<void, TransactionFailure>> cancel(
    String walletId,
    String txid,
  ) {
    calls.add('cancel:$walletId:$txid');
    return result.future;
  }
}

CbfRecoveryCubit _cubit(_Repository repository) => CbfRecoveryCubit(
  RetryUnrelayedTransactionUsecase(repository),
  CancelUnrelayedTransactionUsecase(repository),
);

void main() {
  for (final cancel in [false, true]) {
    test(
      '${cancel ? 'Cancel' : 'Retry'} serializes both actions and surfaces the typed failure',
      () async {
        final repository = _Repository();
        final cubit = _cubit(repository);
        final operation = cancel
            ? cubit.cancel('wallet', 'spend')
            : cubit.retry('wallet', 'spend');
        expect(cubit.state, isA<CbfRecoveryRunning>());
        expect(await cubit.cancel('wallet', 'spend'), isFalse);
        expect(await cubit.retry('wallet', 'spend'), isFalse);
        expect(repository.calls, [
          '${cancel ? 'cancel' : 'retry'}:wallet:spend',
        ]);
        repository.result.complete(const Err(TransactionCbfRecoveryFailure()));
        expect(await operation, isFalse);
        expect(cubit.state.failure, isA<TransactionCbfRecoveryFailure>());
        expect(cubit.state.isBusy, isFalse);
        await cubit.close();
      },
    );
  }
  test('success is reported only after the use-case completes', () async {
    final repository = _Repository();
    final cubit = _cubit(repository);
    final operation = cubit.cancel('wallet', 'spend');
    expect(cubit.state.isBusy, isTrue);
    repository.result.complete(const Ok(null));
    expect(await operation, isTrue);
    expect(cubit.state, isA<CbfRecoveryReady>());
    await cubit.close();
  });
  test(
    'closing the details while Retry waits does not emit into a closed cubit',
    () async {
      final repository = _Repository();
      final cubit = _cubit(repository);
      final operation = cubit.retry('wallet', 'spend');
      await cubit.close();
      repository.result.complete(const Ok(null));
      expect(await operation, isFalse);
    },
  );
}
