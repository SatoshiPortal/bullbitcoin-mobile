import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/delete_seed_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_all_seeds_from_secure_storage_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/process_and_separate_seeds_usecase.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'all_seed_view_cubit.freezed.dart';
part 'all_seed_view_state.dart';

class AllSeedViewCubit extends Cubit<AllSeedViewState> {
  AllSeedViewCubit({
    required GetAllSeedsFromSecureStorageUsecase
    getAllSeedsFromSecureStorageUsecase,
    required WalletMetadataDatasource walletMetadataDatasource,
    required DeleteSeedUsecase deleteSeedUsecase,
    required ProcessAndSeparateSeedsUsecase processAndSeparateSeedsUsecase,
  }) : _getAllSeedsFromSecureStorageUsecase =
           getAllSeedsFromSecureStorageUsecase,
       _walletMetadataDatasource = walletMetadataDatasource,
       _deleteSeedUsecase = deleteSeedUsecase,
       _processAndSeparateSeedsUsecase = processAndSeparateSeedsUsecase,
       super(const AllSeedViewState());

  final GetAllSeedsFromSecureStorageUsecase
  _getAllSeedsFromSecureStorageUsecase;
  final WalletMetadataDatasource _walletMetadataDatasource;
  final DeleteSeedUsecase _deleteSeedUsecase;
  final ProcessAndSeparateSeedsUsecase _processAndSeparateSeedsUsecase;

  Future<void> fetchAllSeeds() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      // Fetch all seeds and wallet metadata in parallel
      final seedsFuture = _getAllSeedsFromSecureStorageUsecase.execute();
      final walletMetadataFuture = _walletMetadataDatasource.fetchAll();

      final seeds = await seedsFuture;
      final walletMetadata = await walletMetadataFuture;

      // Get set of fingerprints from existing wallets
      final existingFingerprints =
          walletMetadata.map((metadata) => metadata.masterFingerprint).toSet();

      // Process and separate seeds into existing and old wallets
      final result = _processAndSeparateSeedsUsecase.execute(
        seeds: seeds,
        existingFingerprints: existingFingerprints,
      );

      emit(
        state.copyWith(
          loading: false,
          existingWallets: result.existingWallets,
          oldWallets: result.oldWallets,
          error: null,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  void clearState() {
    emit(const AllSeedViewState());
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
}
