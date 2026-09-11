import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup_failure.dart';
import 'package:bb_mobile/features/portable_backup/domain/usecases/fetch_portable_vault_usecase.dart';
import 'package:bb_mobile/features/portable_backup/domain/usecases/open_portable_backup_usecase.dart';
import 'package:bb_mobile/features/portable_backup/domain/usecases/prepare_and_publish_portable_vault_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Holds ciphertext and public recovery information only, never credentials or
/// decrypted metadata. A credential is borrowed for one operation.
final class PortableBackupState {
  final bool busy;
  final PortableBackupFiles? files;
  final String? publishedEventId;
  final PortableBackupFetch? recovered;
  final bool metadataOpened;
  final PortableBackupFailure? failure;

  const PortableBackupState({
    this.busy = false,
    this.files,
    this.publishedEventId,
    this.recovered,
    this.metadataOpened = false,
    this.failure,
  });
}

final class PortableBackupCubit extends Cubit<PortableBackupState> {
  final PrepareAndPublishPortableVaultUsecase _prepareAndPublish;
  final FetchPortableVaultUsecase _fetch;
  final OpenPortableBackupUsecase _open;
  NostrSession? _session;

  PortableBackupCubit(this._prepareAndPublish, this._fetch, this._open)
    : super(const PortableBackupState());

  NostrSession _start() {
    cancel();
    final session = _session = NostrSession();
    emit(const PortableBackupState(busy: true));
    return session;
  }

  bool _finished(NostrSession session) => isClosed || session.isCancelled;

  Future<void> prepareAndPublish({
    required String words,
    required String metadataJson,
    required String descriptor,
    required String network,
    required String relay,
  }) async {
    final session = _start();
    final result = await _prepareAndPublish.execute(
      words: words,
      metadataJson: metadataJson,
      descriptor: descriptor,
      network: network,
      relay: relay,
      session: session,
    );
    if (_finished(session)) return;
    emit(switch (result) {
      Err(:final failure) => PortableBackupState(failure: failure),
      Ok(:final value) => switch (value.publication) {
        Ok(value: final eventId) => PortableBackupState(
          files: value.files,
          publishedEventId: eventId,
        ),
        Err(:final failure) => PortableBackupState(
          files: value.files,
          failure: failure,
        ),
      },
    });
  }

  Future<void> fetch({
    required String words,
    required String network,
    required String relay,
  }) async {
    final session = _start();
    final uri = Uri.tryParse(relay.trim());
    if (uri == null) {
      emit(const PortableBackupState(failure: PortableBackupNetworkFailure()));
      return;
    }
    final result = await _fetch.execute(
      words: words,
      network: network,
      relay: uri,
      session: session,
    );
    if (_finished(session)) return;
    emit(switch (result) {
      Ok(:final value) => PortableBackupState(recovered: value),
      Err(:final failure) => PortableBackupState(failure: failure),
    });
  }

  Future<void> openMetadata({
    required String words,
    required String encodedFile,
    required String network,
  }) async {
    final session = _start();
    final result = await _open.execute(
      words: words,
      encodedFile: encodedFile,
      network: network,
      kind: PortableBackupKind.metadata,
    );
    if (_finished(session)) return;
    emit(switch (result) {
      Ok() => const PortableBackupState(metadataOpened: true),
      Err(:final failure) => PortableBackupState(failure: failure),
    });
  }

  void cancel() {
    _session?.cancel();
    _session = null;
    if (!isClosed) emit(const PortableBackupState());
  }

  @override
  Future<void> close() {
    _session?.cancel();
    return super.close();
  }
}
