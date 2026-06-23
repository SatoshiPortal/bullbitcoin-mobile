import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/delete_seed_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_all_seeds_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/process_and_separate_seeds_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/all_seed_view/domain/all_seed_view_failure.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'all_seed_view_cubit.freezed.dart';
part 'all_seed_view_state.dart';

class AllSeedViewCubit extends Cubit<AllSeedViewState> {
  AllSeedViewCubit({
    required this._getAllSeedsUsecase,
    required this._getWalletsUsecase,
    required this._deleteSeedUsecase,
    required this._processAndSeparateSeedsUsecase,
  }) : super(const AllSeedViewState());

  final GetAllSeedsUsecase _getAllSeedsUsecase;
  final GetWalletsUsecase _getWalletsUsecase;
  final DeleteSeedUsecase _deleteSeedUsecase;
  final ProcessAndSeparateSeedsUsecase _processAndSeparateSeedsUsecase;

  Future<void> fetchAllSeeds() async {
    emit(state.copyWith(loading: true, failure: null));

    final List<MnemonicSeed> seeds;
    switch ((await _getAllSeedsUsecase.execute())
        .mapErr((f) => AllSeedViewFetchFailure(f.logMessage))) {
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
      log.warning('fetchAllSeeds: wallets fetch failed', error: e, trace: st);
      emit(
        state.copyWith(
          loading: false,
          failure: AllSeedViewUnexpectedFailure(e.toString()),
        ),
      );
      return;
    }

    final processed = _processAndSeparateSeedsUsecase.execute(
      seeds: seeds,
      existingFingerprints: existingFingerprints,
    );
    emit(
      state.copyWith(
        loading: false,
        existingWallets: processed.existingWallets,
        oldWallets: processed.oldWallets,
        failure: null,
      ),
    );
  }

  void showSeeds() => emit(state.copyWith(seedsVisible: true));

  void hideSeeds() => emit(state.copyWith(seedsVisible: false));

  Future<void> deleteSeed(String fingerprint) async {
    switch ((await _deleteSeedUsecase.execute(fingerprint))
        .mapErr((f) => AllSeedViewDeleteFailure(f.logMessage))) {
      case Ok():
        emit(
          state.copyWith(
            existingWallets: state.existingWallets
                .where((s) => s.masterFingerprint != fingerprint)
                .toList(),
            oldWallets: state.oldWallets
                .where((s) => s.masterFingerprint != fingerprint)
                .toList(),
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }

  @override
  Future<void> close() {
    emit(const AllSeedViewState());
    return super.close();
  }
}
