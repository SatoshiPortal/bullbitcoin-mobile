import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bitcoin_descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/fetch_bitcoin_backup_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/restore_bitcoin_backup_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class BitcoinBackupState {
  final bool busy;
  final BitcoinBackupFetch? result;
  final RestoredBackupWallet? restored;
  final BullVaultFailure? failure;
  const BitcoinBackupState({
    this.busy = false,
    this.result,
    this.restored,
    this.failure,
  });
}

final class BitcoinBackupCubit extends Cubit<BitcoinBackupState> {
  final FetchBitcoinBackupUsecase _fetch;
  final RestoreBitcoinBackupUsecase _restore;
  DescriptorBackupSession? _session;
  BitcoinBackupCubit(this._fetch, this._restore)
    : super(const BitcoinBackupState());

  Future<void> fetch(
    String input,
    BitcoinBackupNetwork network,
    ElectrumConnection connection,
  ) async {
    cancel();
    final session = _session = DescriptorBackupSession();
    emit(const BitcoinBackupState(busy: true));
    final result = await _fetch.execute(
      input: input,
      network: network,
      connection: connection,
      session: session,
    );
    if (isClosed || session.isCancelled) return;
    session.cancel();
    emit(switch (result) {
      Ok(:final value) => BitcoinBackupState(result: value),
      Err(:final failure) => BitcoinBackupState(failure: failure),
    });
  }

  Future<void> restore(
    BitcoinBackupCandidate candidate,
    BitcoinBackupNetwork network,
    ElectrumConnection connection,
  ) async {
    final fetched = state.result;
    _session?.cancel();
    final session = _session = DescriptorBackupSession();
    emit(BitcoinBackupState(busy: true, result: fetched));
    final result = await _restore.execute(
      descriptor: candidate.descriptor,
      network: network,
      connection: connection,
      session: session,
    );
    if (isClosed || session.isCancelled) return;
    session.cancel();
    emit(switch (result) {
      Ok(:final value) => BitcoinBackupState(result: fetched, restored: value),
      Err(:final failure) => BitcoinBackupState(
        result: fetched,
        failure: failure,
      ),
    });
  }

  void cancel({bool preserveCandidates = false}) {
    _session?.cancel();
    _session = null;
    if (!isClosed) {
      emit(
        BitcoinBackupState(result: preserveCandidates ? state.result : null),
      );
    }
  }

  @override
  Future<void> close() {
    _session?.cancel();
    return super.close();
  }
}
