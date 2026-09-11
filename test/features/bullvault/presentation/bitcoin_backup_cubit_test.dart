import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bitcoin_descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bitcoin_descriptor_backup_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/fetch_bitcoin_backup_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/restore_bitcoin_backup_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bitcoin_backup_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

const connection = ElectrumConnection(
  url: 'tcp://localhost:51401',
  retry: 0,
  timeout: 1,
  stopGap: 20,
  validateDomain: true,
  isCustom: true,
);
final candidate = BitcoinBackupCandidate(
  descriptor: 'public descriptor',
  txid: 'a' * 64,
  outputIndex: 0,
  reportedHeight: 1,
);
final fetched = BitcoinBackupFetch(
  'address',
  [candidate],
  incomplete: false,
  rejectedTransactions: 0,
);

class FakeRepository implements BitcoinDescriptorBackupRepository {
  Completer<Result<BitcoinBackupFetch, BullVaultFailure>>? pendingFetch;
  Completer<Result<RestoredBackupWallet, BullVaultFailure>>? pendingRestore;
  String? restoredDescriptor;
  @override
  Result<BitcoinBackupPublication, BullVaultFailure> prepare(
    String descriptor,
    BitcoinBackupNetwork network,
  ) => const Err(BullVaultInvalidRecoveryFailure());
  @override
  Future<Result<BitcoinBackupFetch, BullVaultFailure>> fetch(
    String input,
    BitcoinBackupNetwork network,
    ElectrumConnection connection,
    DescriptorBackupSession session,
  ) async => pendingFetch == null ? Ok(fetched) : pendingFetch!.future;
  @override
  Future<Result<RestoredBackupWallet, BullVaultFailure>> restore(
    String descriptor,
    BitcoinBackupNetwork network,
    ElectrumConnection connection,
    DescriptorBackupSession session,
  ) async {
    restoredDescriptor = descriptor;
    return pendingRestore == null
        ? const Err(BullVaultBackupStatusFailure())
        : pendingRestore!.future;
  }
}

void main() {
  test(
    'restore failure preserves candidates and invokes restore usecase with selected descriptor',
    () async {
      final repository = FakeRepository();
      final cubit = BitcoinBackupCubit(
        FetchBitcoinBackupUsecase(repository),
        RestoreBitcoinBackupUsecase(repository),
      );
      addTearDown(cubit.close);
      await cubit.fetch('xpub', BitcoinBackupNetwork.regtest, connection);
      await cubit.restore(candidate, BitcoinBackupNetwork.regtest, connection);
      expect(repository.restoredDescriptor, candidate.descriptor);
      expect(cubit.state.result, same(fetched));
      expect(cubit.state.failure, isA<BullVaultBackupStatusFailure>());
    },
  );

  test('cancel suppresses late fetch and restore completion', () async {
    final repository = FakeRepository()..pendingFetch = Completer();
    final cubit = BitcoinBackupCubit(
      FetchBitcoinBackupUsecase(repository),
      RestoreBitcoinBackupUsecase(repository),
    );
    addTearDown(cubit.close);
    final pending = cubit.fetch(
      'xpub',
      BitcoinBackupNetwork.regtest,
      connection,
    );
    cubit.cancel();
    repository.pendingFetch!.complete(Ok(fetched));
    await pending;
    expect(cubit.state.result, isNull);
    expect(cubit.state.busy, isFalse);
    repository.pendingFetch = null;
    await cubit.fetch('xpub', BitcoinBackupNetwork.regtest, connection);
    repository.pendingRestore = Completer();
    final restore = cubit.restore(
      candidate,
      BitcoinBackupNetwork.regtest,
      connection,
    );
    cubit.cancel(preserveCandidates: true);
    repository.pendingRestore!.complete(
      Ok(
        RestoredBackupWallet(
          id: 'b' * 64,
          receiveAddress: 'receive',
          changeAddress: 'change',
          balanceSats: 300000,
          transactionCount: 1,
        ),
      ),
    );
    await restore;
    expect(cubit.state.result, same(fetched));
    expect(cubit.state.restored, isNull);
  });

  test(
    'publication/candidates/results enforce intrinsic invariants and immutability',
    () {
      final bytes = Uint8List.fromList([1]);
      final addresses = ['a', 'b', 'c'];
      final publication = BitcoinBackupPublication(
        'descriptor',
        bytes,
        addresses,
      );
      bytes[0] = 2;
      addresses[0] = 'changed';
      expect(publication.payload, [1]);
      expect(publication.addresses, ['a', 'b', 'c']);
      expect(() => publication.payload[0] = 3, throwsUnsupportedError);
      expect(() => publication.addresses.add('d'), throwsUnsupportedError);
      expect(
        () => BitcoinBackupPublication('', bytes, addresses),
        throwsArgumentError,
      );
      expect(
        () => BitcoinBackupPublication('d', bytes, ['a', 'a', 'b']),
        throwsArgumentError,
      );
      expect(
        () => BitcoinBackupCandidate(
          descriptor: '',
          txid: 'a' * 64,
          outputIndex: 0,
          reportedHeight: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => BitcoinBackupCandidate(
          descriptor: 'd',
          txid: 'bad',
          outputIndex: 0,
          reportedHeight: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => BitcoinBackupFetch(
          '',
          [],
          incomplete: false,
          rejectedTransactions: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => BitcoinBackupFetch(
          'a',
          [],
          incomplete: false,
          rejectedTransactions: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => RestoredBackupWallet(
          id: 'b' * 64,
          receiveAddress: 'r',
          changeAddress: 'c',
          balanceSats: -1,
          transactionCount: 0,
        ),
        throwsArgumentError,
      );
    },
  );
}
