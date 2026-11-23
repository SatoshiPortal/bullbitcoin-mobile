import 'package:all_seed_view/src/domain/usecases/delete_swap_master_key_usecase.dart';
import 'package:all_seed_view/src/domain/usecases/get_swap_master_key_usecase.dart';
import 'package:all_seed_view/src/domain/usecases/delete_secret_usecase.dart';
import 'package:all_seed_view/src/domain/usecases/get_all_secrets_usecase.dart';
import 'package:all_seed_view/src/domain/usecases/separate_secrets_usecase.dart';
import 'package:primitives/primitives.dart' show Err, Fingerprint, Ok;
import 'package:secrets/secrets.dart';
import 'package:swaps/swaps.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:all_seed_view/src/domain/usecases/get_wallets_usecase.dart';
import 'package:all_seed_view/src/domain/all_seed_view_failure.dart';
import 'package:access/access.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'all_seed_view_cubit.freezed.dart';
part 'all_seed_view_state.dart';

class AllSeedViewCubit extends Cubit<AllSeedViewState> {
  AllSeedViewCubit({
    required this._getAllSecretsUsecase,
    required this._getWalletsUsecase,
    required this._deleteSecretUsecase,
    required this._separateSecretsUsecase,
    required this._getSwapMasterKeyUsecase,
    required this._deleteSwapMasterKeyUsecase,
  }) : super(const AllSeedViewState());

  final GetAllSecretsUsecase _getAllSecretsUsecase;
  final GetWalletsUsecase _getWalletsUsecase;
  final DeleteSecretUsecase _deleteSecretUsecase;
  final SeparateSecretsUsecase _separateSecretsUsecase;
  final GetSwapMasterKeyUsecase _getSwapMasterKeyUsecase;
  final DeleteSwapMasterKeyUsecase _deleteSwapMasterKeyUsecase;

  /// Called once the user has re-confirmed the app PIN on this screen.
  /// Seeds are only ever read from secure storage past this point.
  Future<void> unlock(AppUnlockGrant grant) async {
    if (isClosed || state.isUnlocked) return;
    emit(state.copyWith(isUnlocked: true));
    await fetchAllSeeds();
  }

  Future<void> fetchAllSeeds() async {
    // The gate is enforced here, not only in the UI: no code path may pull
    // raw seed phrases out of secure storage before re-authentication.
    if (isClosed || !state.isUnlocked) return;
    emit(state.copyWith(loading: true, failure: null));

    final List<Secret> seeds;
    final int unreadable;
    final secretsResult = await _getAllSecretsUsecase.execute();
    if (isClosed) return;
    switch (secretsResult.mapErr(
      (f) => AllSeedViewFetchFailure(f.logMessage),
    )) {
      case Ok(:final value):
        seeds = value.whereType<Secret>().toList();
        unreadable = value.whereType<UnreadableSecret>().length;
      case Err(:final failure):
        emit(state.copyWith(loading: false, failure: failure));
        return;
    }

    // "No wallets yet" is normal here: seeds can exist before any wallet is
    // created, and every seed is then simply treated as "old".
    final existingFingerprints = <String>{};
    final walletsResult = await _getWalletsUsecase.execute();
    if (isClosed) return;
    switch (walletsResult) {
      case Ok(:final value):
        existingFingerprints.addAll(value);
      case Err(:final failure):
        // The seeds were fetched successfully; only the wallet lookup failed.
        // Degrade gracefully: treat every seed as "old" and still display
        // them, rather than discarding a good fetch and showing
        // "No seeds found".
        log.warning('all seeds: wallet lookup failed: ${failure.logMessage}');
    }

    final processed = _separateSecretsUsecase.execute(
      secrets: seeds,
      existingFingerprints: existingFingerprints,
    );

    // Best-effort: the swap mnemonic is a separate secret from the wallet
    // seeds; a failure to read it must not hide the wallet seeds.
    final swapResult = await _getSwapMasterKeyUsecase.execute();
    if (isClosed) return;
    final swapMasterKey = switch (swapResult) {
      Ok(:final value) => value,
      Err() => null,
    };

    emit(
      state.copyWith(
        loading: false,
        existingWallets: processed.existingWallets,
        oldWallets: processed.oldWallets,
        unreadableEntries: unreadable,
        swapMasterKey: swapMasterKey,
        failure: null,
      ),
    );
  }

  void showSeeds() {
    if (!isClosed) emit(state.copyWith(seedsVisible: true));
  }

  void hideSeeds() {
    if (!isClosed) emit(state.copyWith(seedsVisible: false));
  }

  Future<void> deleteSeed(String fingerprint) async {
    final result = await _deleteSecretUsecase.execute(Fingerprint(fingerprint));
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(
          state.copyWith(
            existingWallets: state.existingWallets
                .where((s) => s.id.hex != fingerprint)
                .toList(),
            oldWallets: state.oldWallets
                .where((s) => s.id.hex != fingerprint)
                .toList(),
            failure: null,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }

  Future<void> deleteSwapMnemonic(SwapMasterKeyInfo key) async {
    final result = await _deleteSwapMasterKeyUsecase.execute(key);
    if (isClosed) return;
    switch (result) {
      case Ok():
        final current = state.swapMasterKey;
        if (current != null &&
            current.fingerprint == key.fingerprint &&
            current.walletFingerprint == key.walletFingerprint &&
            current.network == key.network) {
          emit(state.copyWith(swapMasterKey: null));
        }
      case Err(:final failure):
        log.warning('deleteSwapMnemonic failed (${failure.runtimeType})');
        emit(state.copyWith(failure: const AllSeedViewDeleteFailure()));
    }
  }

  @override
  Future<void> close() {
    if (isClosed) return Future.value();
    emit(const AllSeedViewState());
    return super.close();
  }
}
