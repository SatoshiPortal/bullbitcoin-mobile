import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/delete_seed_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_all_seeds_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/process_and_separate_seeds_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'all_seed_view_cubit.freezed.dart';
part 'all_seed_view_state.dart';

class AllSeedViewCubit extends Cubit<AllSeedViewState> {
  AllSeedViewCubit({
    required GetAllSeedsUsecase getAllSeedsUsecase,
    required GetWalletsUsecase getWalletsUsecase,
    required DeleteSeedUsecase deleteSeedUsecase,
    required ProcessAndSeparateSeedsUsecase processAndSeparateSeedsUsecase,
  }) : _getAllSeedsUsecase = getAllSeedsUsecase,
       _getWalletsUsecase = getWalletsUsecase,
       _deleteSeedUsecase = deleteSeedUsecase,
       _processAndSeparateSeedsUsecase = processAndSeparateSeedsUsecase,
       super(const AllSeedViewState());

  final GetAllSeedsUsecase _getAllSeedsUsecase;
  final GetWalletsUsecase _getWalletsUsecase;
  final DeleteSeedUsecase _deleteSeedUsecase;
  final ProcessAndSeparateSeedsUsecase _processAndSeparateSeedsUsecase;

  Future<void> fetchAllSeeds() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      // Fetch all seeds and wallets in parallel
      final seeds = await _getAllSeedsUsecase.execute();
      final wallets = await _getWalletsUsecase.execute();

      // Map wallets to their master fingerprints
      final existingFingerprints =
          wallets.map((wallet) => wallet.masterFingerprint).toSet();

      // Process and separate seeds into existing and old wallets
      final result = _processAndSeparateSeedsUsecase.execute(
        seeds: seeds,
        existingFingerprints: existingFingerprints,
      );

      emit(
        state.copyWith(
          existingWallets: result.existingWallets,
          oldWallets: result.oldWallets,
          error: null,
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    } finally {
      emit(state.copyWith(loading: false));
    }
  }

  void showSeeds() {
    emit(state.copyWith(seedsVisible: true));
  }

  void hideSeeds() {
    emit(state.copyWith(seedsVisible: false));
  }

  Future<void> deleteSeed(String fingerprint) async {
    try {
      await _deleteSeedUsecase.execute(fingerprint);

      // Remove the seed from state instead of reloading all seeds
      final updatedExistingWallets =
          state.existingWallets
              .where((seed) => seed.masterFingerprint != fingerprint)
              .toList();
      final updatedOldWallets =
          state.oldWallets
              .where((seed) => seed.masterFingerprint != fingerprint)
              .toList();

      emit(
        state.copyWith(
          existingWallets: updatedExistingWallets,
          oldWallets: updatedOldWallets,
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: 'Failed to delete seed: $e'));
    }
  }

  @override
  Future<void> close() {
    emit(const AllSeedViewState());
    return super.close();
  }
}
