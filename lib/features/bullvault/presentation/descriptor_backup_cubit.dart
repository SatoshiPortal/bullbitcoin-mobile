import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/fetch_descriptor_backup_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/publish_descriptor_backup_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class DescriptorBackupState {
  final bool busy;
  final bool published;
  final DescriptorBackupFetch? result;
  final BullVaultFailure? failure;
  const DescriptorBackupState({
    this.busy = false,
    this.published = false,
    this.result,
    this.failure,
  });
}

final class DescriptorBackupCubit extends Cubit<DescriptorBackupState> {
  final FetchDescriptorBackupUsecase _fetch;
  final PublishDescriptorBackupUsecase? _publish;
  DescriptorBackupSession? _session;
  DescriptorBackupCubit(this._fetch, [this._publish])
    : super(const DescriptorBackupState());

  Future<void> fetch(String input, String relay) async {
    cancel();
    final session = _session = DescriptorBackupSession();
    emit(const DescriptorBackupState(busy: true));
    final uri = Uri.tryParse(relay.trim());
    if (uri == null) {
      emit(
        const DescriptorBackupState(failure: BullVaultInvalidRecoveryFailure()),
      );
      return;
    }
    final result = await _fetch.execute(
      input: input,
      relay: uri,
      session: session,
    );
    if (isClosed || session.isCancelled) return;
    session.cancel();
    emit(switch (result) {
      Ok(:final value) => DescriptorBackupState(result: value),
      Err(:final failure) => DescriptorBackupState(failure: failure),
    });
  }

  Future<void> publish(String descriptor, String relay) async {
    final publish = _publish;
    if (publish == null) return;
    cancel();
    final session = _session = DescriptorBackupSession();
    emit(const DescriptorBackupState(busy: true));
    final uri = Uri.tryParse(relay.trim());
    if (uri == null) {
      emit(
        const DescriptorBackupState(failure: BullVaultInvalidRecoveryFailure()),
      );
      return;
    }
    final result = await publish.execute(
      descriptor: descriptor,
      relay: uri,
      session: session,
    );
    if (isClosed || session.isCancelled) return;
    session.cancel();
    emit(switch (result) {
      Ok() => const DescriptorBackupState(published: true),
      Err(:final failure) => DescriptorBackupState(failure: failure),
    });
  }

  void cancel() {
    _session?.cancel();
    _session = null;
    if (!isClosed) emit(const DescriptorBackupState());
  }

  @override
  Future<void> close() {
    _session?.cancel();
    return super.close();
  }
}
