import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/nostr_key_display.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/create_keychain_manifest_nostr_key_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/get_default_wallet_nostr_keys_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

enum NostrKeyFormError {
  nameRequired,
  nameTooLong,
  descriptionTooLong,
  invalidNameCharacters,
  invalidDescriptionCharacters,
}

final class NostrKeysState {
  final List<KeychainManifestEntry> keys;
  final bool loading;
  final bool busy;
  final bool showSystemKeys;
  final KeychainManifestFailure? failure;
  final NostrKeyFormError? formError;

  const NostrKeysState({
    this.keys = const [],
    this.loading = false,
    this.busy = false,
    this.showSystemKeys = false,
    this.failure,
    this.formError,
  });

  List<KeychainManifestEntry> get userKeys =>
      keys.where((key) => !key.isSystemNostrKey).toList(growable: false);

  List<KeychainManifestEntry> get systemKeys =>
      keys.where((key) => key.isSystemNostrKey).toList(growable: false);

  NostrKeysState copyWith({
    List<KeychainManifestEntry>? keys,
    bool? loading,
    bool? busy,
    bool? showSystemKeys,
    KeychainManifestFailure? failure,
    NostrKeyFormError? formError,
    bool clearFailure = false,
    bool clearFormError = false,
  }) => NostrKeysState(
    keys: keys ?? this.keys,
    loading: loading ?? this.loading,
    busy: busy ?? this.busy,
    showSystemKeys: showSystemKeys ?? this.showSystemKeys,
    failure: clearFailure ? null : (failure ?? this.failure),
    formError: clearFormError ? null : (formError ?? this.formError),
  );
}

final class NostrKeysCubit extends Cubit<NostrKeysState> {
  final GetDefaultWalletNostrKeysUsecase _load;
  final CreateKeychainManifestNostrKeyUsecase _create;
  NostrKeysCubit(this._load, this._create) : super(const NostrKeysState());

  Future<void> load() async {
    if (isClosed) return;
    emit(state.copyWith(loading: true, clearFailure: true));
    switch (await _load.execute()) {
      case Ok(:final value):
        if (!isClosed) {
          emit(state.copyWith(keys: value, loading: false));
        }
      case Err(:final failure):
        _fail(failure, loading: false);
    }
  }

  void setShowSystemKeys(bool value) {
    if (!isClosed && state.showSystemKeys != value) {
      emit(state.copyWith(showSystemKeys: value));
    }
  }

  Future<bool> create(String name, {String? description}) async {
    if (isClosed || state.busy) return false;
    final formError = validateNostrKeyForm(name, description);
    if (formError != null) {
      emit(state.copyWith(formError: formError));
      return false;
    }
    emit(state.copyWith(busy: true, clearFailure: true, clearFormError: true));
    return switch (await _create.execute(
      purpose: name,
      description: description,
    )) {
      Ok() => await _reloadAfterMutation(),
      Err(:final failure) => _failedMutation(failure),
    };
  }

  void clearFormError() {
    if (!isClosed && state.formError != null) {
      emit(state.copyWith(clearFormError: true));
    }
  }

  Future<bool> _reloadAfterMutation() async {
    switch (await _load.execute()) {
      case Ok(:final value):
        if (!isClosed) {
          emit(state.copyWith(keys: value, busy: false));
        }
        return true;
      case Err(:final failure):
        return _failedMutation(failure);
    }
  }

  bool _failedMutation(KeychainManifestFailure failure) {
    _fail(failure, busy: false);
    return false;
  }

  void _fail(KeychainManifestFailure failure, {bool? loading, bool? busy}) {
    if (!isClosed) {
      emit(state.copyWith(failure: failure, loading: loading, busy: busy));
    }
  }
}

NostrKeyFormError? validateNostrKeyForm(String name, String? description) {
  final normalizedDescription = description?.trim();
  if (KeychainManifestNostrKey.tryNormalizePurpose(name) != null &&
      (normalizedDescription?.length ?? 0) <=
          KeychainManifestEntry.maxDescriptionLength &&
      !(normalizedDescription != null &&
          KeychainManifestNostrKey.hasControlCharacter(
            normalizedDescription,
          ))) {
    return null;
  }
  final trimmed = name.trim();
  if (trimmed.isEmpty) return NostrKeyFormError.nameRequired;
  if (trimmed.length > KeychainManifestNostrKey.maxPurposeLength) {
    return NostrKeyFormError.nameTooLong;
  }
  if ((description?.trim().length ?? 0) >
      KeychainManifestEntry.maxDescriptionLength) {
    return NostrKeyFormError.descriptionTooLong;
  }
  if (KeychainManifestNostrKey.hasControlCharacter(trimmed)) {
    return NostrKeyFormError.invalidNameCharacters;
  }
  return NostrKeyFormError.invalidDescriptionCharacters;
}
