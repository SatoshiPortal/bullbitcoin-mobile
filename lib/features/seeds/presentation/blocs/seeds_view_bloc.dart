import 'package:bb_mobile/core/primitives/seeds/seed_secret.dart';
import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';
import 'package:bb_mobile/features/seeds/application/usecases/delete_seed_usecase.dart';
import 'package:bb_mobile/features/seeds/application/usecases/list_used_seeds_usecase.dart';
import 'package:bb_mobile/features/seeds/application/usecases/load_all_stored_seed_secrets_usecase.dart';
import 'package:bb_mobile/features/seeds/application/usecases/load_legacy_seeds_usecase.dart';
import 'package:bb_mobile/features/seeds/presentation/blocs/seeds_view_event.dart';
import 'package:bb_mobile/features/seeds/presentation/seeds_presentation_errors.dart';
import 'package:bb_mobile/features/seeds/presentation/view_models/seed_view_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

part 'seeds_view_bloc.freezed.dart';
part 'seeds_view_state.dart';

class SeedsViewBloc extends Bloc<SeedsViewEvent, SeedsViewState> {
  SeedsViewBloc({
    required LoadAllStoredSeedSecretsUseCase loadAllStoredSeedSecretsUseCase,
    required ListUsedSeedsUseCase listUsedSeedsUseCase,
    required DeleteSeedUseCase deleteSeedUsecase,
    required LoadLegacySeedsUseCase loadLegacySeedsUseCase,
  }) : _loadAllStoredSeedSecretsUsecase = loadAllStoredSeedSecretsUseCase,
       _listUsedSeedsUsecase = listUsedSeedsUseCase,
       _deleteSeedUsecase = deleteSeedUsecase,
       _loadLegacySeedsUseCase = loadLegacySeedsUseCase,
       super(const SeedsViewState.initial()) {
    on<SeedsViewLoadRequested>(_onLoadRequested, transformer: droppable());
    on<SeedsViewDeleteRequested>(_onDeleteRequested, transformer: droppable());
  }

  final LoadAllStoredSeedSecretsUseCase _loadAllStoredSeedSecretsUsecase;
  final ListUsedSeedsUseCase _listUsedSeedsUsecase;
  final DeleteSeedUseCase _deleteSeedUsecase;
  final LoadLegacySeedsUseCase _loadLegacySeedsUseCase;

  Future<void> _onLoadRequested(
    SeedsViewLoadRequested event,
    Emitter<SeedsViewState> emit,
  ) async {
    emit(const SeedsViewState.loading());

    try {
      // CRITICAL: Load current seeds and usage list in parallel - both must succeed
      final criticalResults = await Future.wait([
        _loadAllStoredSeedSecretsUsecase.execute(
          const LoadAllStoredSeedSecretsQuery(),
        ),
        _listUsedSeedsUsecase.execute(const ListUsedSeedsQuery()),
      ]);

      final loadAllStoredSeedsResult =
          criticalResults[0] as LoadAllStoredSeedSecretsResult;
      final listUsedSeedsResult = criticalResults[1] as ListUsedSeedsResult;

      // OPTIONAL: Try to load legacy seeds - if this fails, continue anyway
      LoadLegacySeedsResult? loadLegacySeedsResult;
      try {
        loadLegacySeedsResult = await _loadLegacySeedsUseCase.execute(
          const LoadLegacySeedsQuery(),
        );
      } catch (e) {
        // Legacy seeds failed to load, but that's okay - continue without them
        loadLegacySeedsResult = null;
      }

      emit(
        SeedsViewState.loaded(
          seeds: loadAllStoredSeedsResult.secretsByFingerprint,
          inUseFingerprints: listUsedSeedsResult.fingerprints,
          legacySeeds: loadLegacySeedsResult?.secretsByFingerprint ?? {},
        ),
      );
    } on SeedsApplicationError catch (e) {
      emit(
        SeedsViewState.failedToLoad(
          error: SeedsPresentationError.fromApplicationError(e),
        ),
      );
    } catch (e) {
      emit(
        SeedsViewState.failedToLoad(
          error: UnknownSeedsPresentationError.fromException(e),
        ),
      );
    }
  }

  Future<void> _onDeleteRequested(
    SeedsViewDeleteRequested event,
    Emitter<SeedsViewState> emit,
  ) async {
    if (state is! SeedsViewLoaded) {
      // Cannot delete if not in loaded state
      return;
    } else {
      emit((state as SeedsViewLoaded).copyWith(isSeedBeingDeleted: true));

      try {
        await _deleteSeedUsecase.execute(
          DeleteSeedCommand(fingerprint: event.fingerprint),
        );

        // After successful deletion, remove the seed from the state too
        final remainingSeeds = Map<String, SeedSecret>.from(
          (state as SeedsViewLoaded).seeds,
        );
        remainingSeeds.remove(event.fingerprint);
        final remainingInUseFingerprints = (state as SeedsViewLoaded)
            .inUseFingerprints
            .where((fp) => fp != event.fingerprint)
            .toList();

        emit(
          SeedsViewState.loaded(
            seeds: remainingSeeds,
            inUseFingerprints: remainingInUseFingerprints,
          ),
        );
      } on SeedsApplicationError catch (e) {
        emit(
          (state as SeedsViewLoaded).copyWith(
            isSeedBeingDeleted: false,
            deletionError: SeedsPresentationError.fromApplicationError(e),
          ),
        );
      } catch (e) {
        emit(
          (state as SeedsViewLoaded).copyWith(
            isSeedBeingDeleted: false,
            deletionError: UnknownSeedsPresentationError.fromException(e),
          ),
        );
      }
    }
  }
}
