import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/backup_identity_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/nostr_key_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/manage_backup_identities_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/manage_nostr_keys_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class NostrKeysState {
  final List<NostrKeyRecord> keys;
  final List<BackupIdentityRecord>? systemKeys;
  final bool loading;
  final bool creating;
  final bool loadingSystem;
  final KeychainManifestFailure? failure;

  const NostrKeysState({
    this.keys = const [],
    this.systemKeys,
    this.loading = true,
    this.creating = false,
    this.loadingSystem = false,
    this.failure,
  });

  NostrKeysState copyWith({
    List<NostrKeyRecord>? keys,
    List<BackupIdentityRecord>? systemKeys,
    bool clearSystemKeys = false,
    bool? loading,
    bool? creating,
    bool? loadingSystem,
    KeychainManifestFailure? failure,
  }) => NostrKeysState(
    keys: keys ?? this.keys,
    systemKeys: clearSystemKeys ? null : systemKeys ?? this.systemKeys,
    loading: loading ?? this.loading,
    creating: creating ?? this.creating,
    loadingSystem: loadingSystem ?? this.loadingSystem,
    failure: failure,
  );
}

final class NostrKeysCubit extends Cubit<NostrKeysState> {
  final GetNostrKeysUsecase _getKeys;
  final CreateNostrKeyUsecase _createKey;
  final GetBackupIdentitiesUsecase _getBackupIdentities;
  late final StreamSubscription<void> _updates;
  int _load = 0;
  int _systemLoad = 0;

  NostrKeysCubit({
    required this._getKeys,
    required WatchNostrKeysUsecase watchKeys,
    required this._createKey,
    required this._getBackupIdentities,
  }) : super(const NostrKeysState()) {
    _updates = watchKeys.execute().listen(
      (_) => unawaited(load()),
      onError: (Object _, StackTrace _) {
        if (!isClosed) {
          emit(
            state.copyWith(
              loading: false,
              failure: const KeychainManifestStorageFailure(),
            ),
          );
        }
      },
    );
  }

  Future<void> load() async {
    final request = ++_load;
    final result = await _getKeys.execute();
    if (isClosed || request != _load) return;
    emit(switch (result) {
      Ok(:final value) => state.copyWith(
        keys: List.unmodifiable(value),
        loading: false,
      ),
      Err(:final failure) => state.copyWith(loading: false, failure: failure),
    });
  }

  Future<NostrKeyRecord?> create({
    required String purpose,
    required String description,
  }) async {
    if (state.creating) return null;
    emit(state.copyWith(creating: true));
    final result = await _createKey.execute(
      purpose: purpose,
      description: description,
    );
    if (isClosed) return null;
    switch (result) {
      case Err(:final failure):
        emit(state.copyWith(creating: false, failure: failure));
        return null;
      case Ok(:final value):
        emit(state.copyWith(creating: false));
        await load();
        return value;
    }
  }

  Future<void> showSystemKeys() async {
    if (state.loadingSystem) return;
    final request = ++_systemLoad;
    emit(state.copyWith(loadingSystem: true));
    final result = await _getBackupIdentities.execute();
    if (isClosed || request != _systemLoad) return;
    emit(switch (result) {
      Ok(:final value) => state.copyWith(
        systemKeys: List.unmodifiable(value),
        loadingSystem: false,
      ),
      Err(:final failure) => state.copyWith(
        loadingSystem: false,
        failure: failure,
      ),
    });
  }

  void hideSystemKeys() {
    _systemLoad++;
    emit(state.copyWith(clearSystemKeys: true, loadingSystem: false));
  }

  @override
  Future<void> close() async {
    await _updates.cancel();
    await super.close();
  }
}
