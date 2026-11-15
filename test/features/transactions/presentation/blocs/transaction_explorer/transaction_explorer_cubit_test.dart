import 'dart:async';

import 'package:bb_mobile/features/transactions/domain/entities/explored_transaction.dart';
import 'package:bb_mobile/features/transactions/domain/repositories/transaction_explorer_repository.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/find_transaction_owner_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/get_explored_transaction_usecase.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_explorer/transaction_explorer_cubit.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_explorer/transaction_explorer_state.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;

final _txid = 'cd' * 32;

class FakeWallet extends Fake implements Wallet {}

class FakeTransactionExplorerRepository
    implements TransactionExplorerRepository {
  final requested = <String>[];
  Future<Result<ExploredTransaction, TransactionFailure>> Function() answer =
      () async => Ok(_transaction());

  @override
  Future<Result<ExploredTransaction, TransactionFailure>> fetch(String txid) {
    requested.add(txid);
    return answer();
  }
}

class FakeFindTransactionOwnerUsecase implements FindTransactionOwnerUsecase {
  Future<Result<Wallet?, TransactionFailure>> Function() answer = () async =>
      const Ok(null);

  @override
  Future<Result<Wallet?, TransactionFailure>> execute(String txid) => answer();
}

ExploredTransaction _transaction() => ExploredTransaction(
  txid: _txid,
  network: Network.bitcoinMainnet,
  version: 2,
  sizeBytes: 200,
  virtualSizeBytes: 150,
  locktime: 0,
  inputCount: 1,
  outputs: const [
    ExploredTransactionOutput(index: 0, amountSat: 700, address: 'address'),
    ExploredTransactionOutput(index: 1, amountSat: 300),
  ],
);

void main() {
  late FakeTransactionExplorerRepository repository;
  late FakeFindTransactionOwnerUsecase findOwner;

  TransactionExplorerCubit build({String? txid}) => TransactionExplorerCubit(
    txid: txid ?? _txid,
    getExploredTransactionUsecase: GetExploredTransactionUsecase(
      repository: repository,
    ),
    findTransactionOwnerUsecase: findOwner,
  );

  setUp(() {
    repository = FakeTransactionExplorerRepository();
    findOwner = FakeFindTransactionOwnerUsecase();
  });

  blocTest<TransactionExplorerCubit, TransactionExplorerState>(
    'loads the transaction and reports a transaction that is not owned',
    build: build,
    act: (cubit) => cubit.load(),
    verify: (cubit) {
      final ownership = cubit.state.ownership;
      expect(ownership, isA<TransactionOwnershipKnown>());
      expect((ownership as TransactionOwnershipKnown).owner, isNull);
      expect(cubit.state.transaction?.totalOutputSat, 1000);
      expect(cubit.state.failure, isNull);
      expect(cubit.state.isLoadingTransaction, isFalse);
    },
  );

  blocTest<TransactionExplorerCubit, TransactionExplorerState>(
    'shows the owner before the server answers',
    build: build,
    act: (cubit) async {
      final wallet = FakeWallet();
      final pending =
          Completer<Result<ExploredTransaction, TransactionFailure>>();
      findOwner.answer = () async => Ok(wallet);
      repository.answer = () => pending.future;

      final load = cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.isLoadingTransaction, isTrue);
      expect(
        (cubit.state.ownership as TransactionOwnershipKnown).owner,
        same(wallet),
      );

      pending.complete(Ok(_transaction()));
      await load;
    },
    verify: (cubit) => expect(cubit.state.transaction, isNotNull),
  );

  blocTest<TransactionExplorerCubit, TransactionExplorerState>(
    'keeps the ownership result when the server lookup fails',
    build: build,
    act: (cubit) {
      findOwner.answer = () async => Ok(FakeWallet());
      repository.answer = () async =>
          const Err(TransactionExplorerUnavailableFailure('SocketException'));
      return cubit.load();
    },
    verify: (cubit) {
      expect(
        (cubit.state.ownership as TransactionOwnershipKnown).owner,
        isNotNull,
      );
      expect(cubit.state.failure, isA<TransactionExplorerUnavailableFailure>());
      expect(cubit.state.transaction, isNull);
    },
  );

  blocTest<TransactionExplorerCubit, TransactionExplorerState>(
    'a failed ownership check does not block the transaction',
    build: build,
    act: (cubit) {
      findOwner.answer = () async =>
          const Err(TransactionUnexpectedFailure('owner'));
      return cubit.load();
    },
    verify: (cubit) {
      expect(cubit.state.ownership, isA<TransactionOwnershipUnavailable>());
      expect(cubit.state.transaction, isNotNull);
    },
  );

  blocTest<TransactionExplorerCubit, TransactionExplorerState>(
    'refuses an invalid txid without a server request',
    build: () => build(txid: 'not-a-txid'),
    act: (cubit) => cubit.load(),
    verify: (cubit) {
      expect(cubit.state.failure, isA<TransactionExplorerInvalidTxidFailure>());
      expect(repository.requested, isEmpty);
    },
  );

  blocTest<TransactionExplorerCubit, TransactionExplorerState>(
    'normalizes the txid and retry clears the failure',
    build: () => build(txid: ' ${_txid.toUpperCase()} '),
    act: (cubit) async {
      repository.answer = () async =>
          const Err(TransactionExplorerUnavailableFailure());
      await cubit.load();
      expect(cubit.state.failure, isNotNull);

      repository.answer = () async => Ok(_transaction());
      await cubit.load();
    },
    verify: (cubit) {
      expect(cubit.state.failure, isNull);
      expect(cubit.state.transaction, isNotNull);
      expect(repository.requested, [_txid, _txid]);
    },
  );
}
