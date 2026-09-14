import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/publish_vault_descriptor_backups_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/watch_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class VaultDestinationsState {
  /// One row per destination this vault could publish to, with its choice and
  /// how far its artifact got.
  final List<VaultDescriptorPublication> rows;

  /// Whether Continue has been pressed, which is when results replace choices.
  final bool published;
  final bool busy;
  final BackupSettingsFailure? failure;

  /// Data Backup's own state, because a descriptor destination is not it.
  final WalletBackupState? dataBackup;

  const VaultDestinationsState({
    this.rows = const [],
    this.published = false,
    this.busy = false,
    this.failure,
    this.dataBackup,
  });

  VaultDestinationsState copyWith({
    List<VaultDescriptorPublication>? rows,
    bool? published,
    bool? busy,
    BackupSettingsFailure? failure,
    bool clearFailure = false,
    WalletBackupState? dataBackup,
  }) => VaultDestinationsState(
    rows: rows ?? this.rows,
    published: published ?? this.published,
    busy: busy ?? this.busy,
    failure: clearFailure ? null : failure ?? this.failure,
    dataBackup: dataBackup ?? this.dataBackup,
  );

  bool enabled(VaultBackupDestination destination) =>
      rows.any((row) => row.destination == destination && row.enabled);

  bool get anyEnabled => rows.any((row) => row.enabled);

  bool get anyOutstanding => rows.any((row) => row.outstanding);
}

/// Drives the destination choices of one vault and their publication.
///
/// Nothing is sent before Continue: a row is a recorded choice, and publishing
/// is the separate step the person asks for. A destination that fails leaves
/// its artifact outstanding, which is what a retry resends.
final class VaultDestinationsCubit extends Cubit<VaultDestinationsState> {
  final PublishVaultDescriptorBackupsUsecase _publish;
  final WatchWalletBackupUsecase _watchDataBackup;
  final String walletId;
  StreamSubscription<Result<WalletBackupState, BackupSettingsFailure>>?
  _dataBackup;

  VaultDestinationsCubit(this._publish, this._watchDataBackup, this.walletId)
    : super(const VaultDestinationsState(busy: true));

  @override
  Future<void> close() async {
    await _dataBackup?.cancel();
    return super.close();
  }

  Future<void> load() async {
    _dataBackup ??= _watchDataBackup.execute().listen((result) {
      if (result case Ok(:final value) when !isClosed) {
        emit(state.copyWith(dataBackup: value));
      }
    });
    await _apply(() => _publish.load(walletId));
  }

  Future<void> setEnabled(VaultBackupDestination destination, bool enabled) =>
      _apply(
        () => _publish.setDestination(
          walletId: walletId,
          destination: destination,
          enabled: enabled,
        ),
      );

  /// Prepares, stores and sends the artifact each selected destination is owed.
  Future<void> publish() async {
    await _apply(() => _publish.execute(walletId));
    if (!isClosed) emit(state.copyWith(published: true));
  }

  /// Resends exactly the bytes a destination never acknowledged.
  Future<void> retry() =>
      _apply(() => _publish.retryPendingPublications(walletId));

  Future<void> _apply(
    Future<Result<List<VaultDescriptorPublication>, BackupSettingsFailure>>
    Function()
    action,
  ) async {
    if (state.busy && state.rows.isNotEmpty) return;
    emit(state.copyWith(busy: true, clearFailure: true));
    final result = await action();
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => state.copyWith(rows: value, busy: false),
      Err(:final failure) => state.copyWith(busy: false, failure: failure),
    });
  }
}
