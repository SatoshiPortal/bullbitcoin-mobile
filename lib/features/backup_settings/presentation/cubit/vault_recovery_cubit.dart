import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vault_from_bip138_file_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vaults_from_backup_words_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vaults_from_cosigner_key_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_recovery_result.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart' show Uint8List;

/// Where a recovery looked. Bitcoin is listed and never searched: publication
/// on chain is deferred, so it is a fixed Coming soon row rather than a request
/// that could keep the screen waiting.
enum VaultRecoverySource { dataBackup, nostr, bitcoin }

/// What one source is doing, or what it last did.
///
/// [incomplete] is not [none]: a relay that went quiet or a page that filled up
/// means the vault may be there, unseen, and saying "nothing found" would send
/// someone away from a backup they actually have.
enum VaultRecoverySourceStatus {
  idle,
  checking,
  found,
  none,
  unavailable,
  incomplete,
}

final class VaultRecoveryState {
  /// Null until the device has been asked whether it can derive its own
  /// credential; false on a phone with no seed, where only manual entries work.
  final bool? credentialAvailable;
  final Map<VaultRecoverySource, VaultRecoverySourceStatus> sources;

  /// One entry per candidate the searches have dealt with so far, in the order
  /// they were dealt with.
  final List<VaultRecoveryOutcome> outcomes;
  final bool busy;
  final BackupSettingsFailure? failure;

  const VaultRecoveryState({
    this.credentialAvailable,
    this.sources = const {
      VaultRecoverySource.dataBackup: VaultRecoverySourceStatus.idle,
      VaultRecoverySource.nostr: VaultRecoverySourceStatus.idle,
      VaultRecoverySource.bitcoin: VaultRecoverySourceStatus.idle,
    },
    this.outcomes = const [],
    this.busy = false,
    this.failure,
  });

  VaultRecoveryState copyWith({
    bool? credentialAvailable,
    Map<VaultRecoverySource, VaultRecoverySourceStatus>? sources,
    List<VaultRecoveryOutcome>? outcomes,
    bool? busy,
    BackupSettingsFailure? failure,
    bool clearFailure = false,
  }) => VaultRecoveryState(
    credentialAvailable: credentialAvailable ?? this.credentialAvailable,
    sources: sources ?? this.sources,
    outcomes: outcomes ?? this.outcomes,
    busy: busy ?? this.busy,
    failure: clearFailure ? null : failure ?? this.failure,
  );

  /// Whether a search has been started at all, which is what tells an entry
  /// screen to stop showing its input and start showing what came back.
  bool get searched =>
      sources.values.any((status) => status != VaultRecoverySourceStatus.idle);

  /// Every vault this recovery put on the device or found already here.
  Iterable<VaultRecoveryOutcome> get recovered => outcomes.where(
    (outcome) =>
        outcome.status == VaultRecoveryStatus.imported ||
        outcome.status == VaultRecoveryStatus.alreadyPresent,
  );
}

/// Drives one recovery journey: the landing's automatic search, or one manual
/// entry's search.
///
/// Every secret it is given — backup words, a mobile seed — arrives as a method
/// argument, is used inside that one method and is never emitted, so nothing
/// secret reaches state, a state `toString`, or a bloc observer. Closing the
/// cubit cancels any relay search still running.
final class VaultRecoveryCubit extends Cubit<VaultRecoveryState> {
  final RecoverVaultsFromBackupWordsUsecase _words;
  final RecoverVaultsFromCosignerKeyUsecase _cosignerKey;
  final RecoverVaultFromBip138FileUsecase _artifact;
  NostrSession? _session;

  VaultRecoveryCubit(this._words, this._cosignerKey, this._artifact)
    : super(const VaultRecoveryState());

  @override
  Future<void> close() {
    _session?.cancel();
    return super.close();
  }

  /// The landing's automatic search: the Data Backup server, then the relays,
  /// each reported on its own and neither able to stop the other.
  Future<void> discover() async {
    if (state.busy) return;
    final available = await _words.hasLocalCredential();
    if (isClosed) return;
    if (!available) {
      emit(state.copyWith(credentialAvailable: false));
      return;
    }
    emit(state.copyWith(credentialAvailable: true, busy: true));
    await _run(
      () => _words.fromDataBackup(abandoned: _abandoned),
      VaultRecoverySource.dataBackup,
    );
    await _run(
      () => _words.fromNostr(session: _newSession(), abandoned: _abandoned),
      VaultRecoverySource.nostr,
    );
    if (isClosed) return;
    emit(state.copyWith(busy: false));
  }

  /// Searches both remote sources with someone else's backup words.
  ///
  /// Both always run: a hit on the server says nothing about what the relays
  /// hold, and one generation may live only on the other side.
  Future<void> searchWithWords(String words) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true, clearFailure: true));
    await _run(
      () => _words.fromDataBackup(words: words, abandoned: _abandoned),
      VaultRecoverySource.dataBackup,
    );
    await _run(
      () => _words.fromNostr(
        words: words,
        session: _newSession(),
        abandoned: _abandoned,
      ),
      VaultRecoverySource.nostr,
    );
    if (isClosed) return;
    emit(state.copyWith(busy: false));
  }

  /// Derives the backup words a mobile seed would have produced, then searches
  /// with them. The seed itself never leaves this call.
  ///
  /// A vault passphrase belongs to the signing key, not to the credential the
  /// backups were published under, so it is not asked for here.
  Future<void> searchWithMobileSeed({required List<String> mnemonic}) async {
    if (state.busy) return;
    final derived = _words.mobileSeedWords(mnemonic: mnemonic);
    switch (derived) {
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
      case Ok(:final value):
        await searchWithWords(value);
    }
  }

  /// The encrypted descriptor file the person chose, or null when they
  /// dismissed the picker or it could not be read.
  Future<Uint8List?> pickArtifact() async {
    switch (await _artifact.pickFile()) {
      case Ok(:final value):
        return value;
      case Err(:final failure):
        if (!isClosed) emit(state.copyWith(failure: failure));
        return null;
    }
  }

  /// Recovers every vault filed under one cosigner's public account key.
  Future<void> recoverFromCosignerKey(String accountKeyInput) =>
      _single(() => _cosignerKey.execute(accountKeyInput));

  /// Recovers one vault from a BIP138 file and the key that opens it.
  Future<void> recoverFromArtifact({
    required Uint8List bytes,
    required String accountKeyInput,
  }) => _single(() async {
    final outcome = await _artifact.execute(
      fileBytes: bytes,
      accountKeyInput: accountKeyInput,
    );
    return Ok(VaultRecoveryResult(outcomes: [outcome], incomplete: false));
  });

  NostrSession _newSession() => _session = NostrSession();

  /// Whether this journey is over. A search whose answer arrives afterwards
  /// must not go on writing vaults to a device the person has walked away
  /// from; what it already wrote stays.
  bool _abandoned() => isClosed;

  Future<void> _single(
    Future<Result<VaultRecoveryResult, BackupSettingsFailure>> Function()
    search,
  ) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true, clearFailure: true));
    await _run(search, VaultRecoverySource.dataBackup);
    if (isClosed) return;
    emit(state.copyWith(busy: false));
  }

  Future<void> _run(
    Future<Result<VaultRecoveryResult, BackupSettingsFailure>> Function()
    search,
    VaultRecoverySource source,
  ) async {
    if (isClosed) return;
    emit(
      state.copyWith(
        sources: {...state.sources, source: VaultRecoverySourceStatus.checking},
      ),
    );
    final result = await search();
    if (isClosed) return;
    switch (result) {
      case Err(:final failure):
        emit(
          state.copyWith(
            sources: {
              ...state.sources,
              source: VaultRecoverySourceStatus.unavailable,
            },
            failure: failure,
          ),
        );
      case Ok(:final value):
        emit(
          state.copyWith(
            sources: {...state.sources, source: _statusOf(value)},
            outcomes: [...state.outcomes, ...value.outcomes],
          ),
        );
    }
  }

  /// A search that did not finish is reported as unfinished even when it
  /// found something: the vaults it did find are in [VaultRecoveryState
  /// .outcomes] either way, and calling the source done would tell someone
  /// every generation had been seen when the older ones may not have been.
  VaultRecoverySourceStatus _statusOf(VaultRecoveryResult result) {
    if (result.incomplete) return VaultRecoverySourceStatus.incomplete;
    if (result.recovered.isNotEmpty) return VaultRecoverySourceStatus.found;
    return VaultRecoverySourceStatus.none;
  }
}
