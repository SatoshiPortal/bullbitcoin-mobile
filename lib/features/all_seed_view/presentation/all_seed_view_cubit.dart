import 'package:bb_mobile/features/all_seed_view/domain/usecases/delete_secret_usecase.dart';
import 'package:bb_mobile/features/all_seed_view/domain/usecases/get_all_secrets_usecase.dart';
import 'package:bb_mobile/features/all_seed_view/domain/usecases/separate_secrets_usecase.dart';
import 'package:primitives/primitives.dart' show Fingerprint;
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap_master_key_info.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/delete_swap_master_key_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_master_key_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_mnemonic_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/all_seed_view/domain/all_seed_view_failure.dart';
import 'package:bb_mobile/features/app_unlock/public/app_unlock_facade.dart';
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
    required this._getSwapMnemonicUsecase,
    required this._deleteSwapMasterKeyUsecase,
  }) : super(const AllSeedViewState());

  final GetAllSecretsUsecase _getAllSecretsUsecase;
  final GetWalletsUsecase _getWalletsUsecase;
  final DeleteSecretUsecase _deleteSecretUsecase;
  final SeparateSecretsUsecase _separateSecretsUsecase;
  final GetSwapMasterKeyUsecase _getSwapMasterKeyUsecase;
  final GetSwapMnemonicUsecase _getSwapMnemonicUsecase;
  final DeleteSwapMasterKeyUsecase _deleteSwapMasterKeyUsecase;

  /// Called once the user has re-confirmed the app PIN on this screen.
  /// Seeds are only ever read from secure storage past this point.
  Future<void> unlock(AppUnlockGrant grant) async {
    if (state.isUnlocked) return;
    emit(state.copyWith(isUnlocked: true));
    await fetchAllSeeds();
  }

  Future<void> fetchAllSeeds() async {
    // The gate is enforced here, not only in the UI: no code path may pull
    // raw seed phrases out of secure storage before re-authentication.
    if (!state.isUnlocked) return;
    emit(state.copyWith(loading: true, failure: null));

    final List<Secret> seeds;
    switch ((await _getAllSecretsUsecase.execute()).mapErr(
      (f) => AllSeedViewFetchFailure(f.logMessage),
    )) {
      case Ok(:final value):
        seeds = value;
      case Err(:final failure):
        emit(state.copyWith(loading: false, failure: failure));
        return;
    }

    // GetWalletsUsecase still throws — this cubit is the boundary for it as
    // the first layer this feature owns. NoWalletsFoundException is normal:
    // seeds can exist before any wallet is created.
    final existingFingerprints = <String>{};
    try {
      final wallets = await _getWalletsUsecase.execute();
      existingFingerprints.addAll(wallets.map((w) => w.masterFingerprint));
    } on NoWalletsFoundException {
      // intentionally empty — all seeds treated as "old"
    } catch (e, st) {
      // The seeds were fetched successfully; only the wallet lookup failed.
      // Degrade gracefully: treat every seed as "old" and still display them,
      // rather than discarding a good fetch and showing "No seeds found".
      log.severe(
        message:
            'fetchAllSeeds: wallets fetch failed, treating all seeds as old',
        error: e,
        trace: st,
      );
    }

    final processed = _separateSecretsUsecase.execute(
      secrets: seeds,
      existingFingerprints: existingFingerprints,
    );

    // Best-effort: the swap mnemonic is a separate secret from the wallet
    // seeds; a failure to read it must not hide the wallet seeds.
    SwapMasterKeyInfo? swapMasterKey;
    try {
      swapMasterKey = await _getSwapMasterKeyUsecase.execute();
    } catch (_) {
      swapMasterKey = null;
    }

    emit(
      state.copyWith(
        loading: false,
        existingWallets: processed.existingWallets,
        oldWallets: processed.oldWallets,
        swapMasterKey: swapMasterKey,
        failure: null,
      ),
    );
  }

  /// The swap mnemonic, at the moment the card draws it.
  ///
  /// Not in state, by design: the words used to be carried in
  /// [SwapMasterKeyInfo] and live for as long as this screen. The caller is
  /// the card's own `FutureBuilder` — the sealed-display shape, for a
  /// credential that belongs to `swaps` and so cannot use `MnemonicView`.
  Future<String?> loadSwapMnemonic() async {
    final walletFingerprint = state.swapMasterKey?.walletFingerprint;
    if (walletFingerprint == null) return null;
    return _getSwapMnemonicUsecase.execute(
      walletFingerprint: walletFingerprint,
    );
  }

  void showSeeds() => emit(state.copyWith(seedsVisible: true));

  void hideSeeds() => emit(state.copyWith(seedsVisible: false));

  Future<void> deleteSeed(String fingerprint) async {
    switch (await _deleteSecretUsecase.execute(Fingerprint(fingerprint))) {
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

  Future<void> deleteSwapMnemonic() async {
    try {
      await _deleteSwapMasterKeyUsecase.execute();
      emit(state.copyWith(swapMasterKey: null));
    } catch (e, st) {
      // Raw reason to logs only; the UI translates the typed failure.
      log.severe(message: 'deleteSwapMnemonic failed', error: e, trace: st);
      emit(state.copyWith(failure: AllSeedViewDeleteFailure(e.toString())));
    }
  }

  @override
  Future<void> close() {
    emit(const AllSeedViewState());
    return super.close();
  }
}
