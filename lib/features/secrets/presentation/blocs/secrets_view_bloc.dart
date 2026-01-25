import 'package:bb_mobile/features/secrets/domain/entities/secret_entity.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_error.dart';
import 'package:bb_mobile/features/secrets/application/usecases/delete_secret_usecase.dart';
import 'package:bb_mobile/features/secrets/application/usecases/list_used_secrets_usecase.dart';
import 'package:bb_mobile/features/secrets/application/usecases/load_all_stored_secrets_usecase.dart';
import 'package:bb_mobile/features/secrets/application/usecases/load_legacy_secrets_usecase.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';
import 'package:bb_mobile/features/secrets/presentation/blocs/secrets_view_event.dart';
import 'package:bb_mobile/features/secrets/presentation/secrets_presentation_error.dart';
import 'package:bb_mobile/features/secrets/presentation/view_models/secret_view_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

part 'secrets_view_bloc.freezed.dart';
part 'secrets_view_state.dart';

class SecretsViewBloc extends Bloc<SecretsViewEvent, SecretsViewState> {
  SecretsViewBloc({
    required LoadAllStoredSecretsUseCase loadAllStoredSecretsUseCase,
    required ListUsedSecretsUseCase listUsedSecretsUseCase,
    required DeleteSecretUseCase deleteSecretUsecase,
    required LoadLegacySecretsUseCase loadLegacySecretsUseCase,
  }) : _loadAllStoredSecretsUsecase = loadAllStoredSecretsUseCase,
       _listUsedSecretsUsecase = listUsedSecretsUseCase,
       _deleteSecretUsecase = deleteSecretUsecase,
       _loadLegacySecretsUseCase = loadLegacySecretsUseCase,
       super(const SecretsViewState.initial()) {
    on<SecretsViewLoadRequested>(_onLoadRequested, transformer: droppable());
    on<SecretsViewDeleteRequested>(
      _onDeleteRequested,
      transformer: droppable(),
    );
  }

  final LoadAllStoredSecretsUseCase _loadAllStoredSecretsUsecase;
  final ListUsedSecretsUseCase _listUsedSecretsUsecase;
  final DeleteSecretUseCase _deleteSecretUsecase;
  final LoadLegacySecretsUseCase _loadLegacySecretsUseCase;

  Future<void> _onLoadRequested(
    SecretsViewLoadRequested event,
    Emitter<SecretsViewState> emit,
  ) async {
    emit(const SecretsViewState.loading());

    try {
      // CRITICAL: Load current seeds and usage list in parallel - both must succeed
      final criticalResults = await Future.wait([
        _loadAllStoredSecretsUsecase.execute(const LoadAllStoredSecretsQuery()),
        _listUsedSecretsUsecase.execute(const ListUsedSecretsQuery()),
      ]);

      final loadAllStoredSecretsResult =
          criticalResults[0] as LoadAllStoredSecretsResult;
      final listUsedSecretsResult = criticalResults[1] as ListUsedSecretsResult;

      // OPTIONAL: Try to load legacy seeds - if this fails, continue anyway
      LoadLegacySecretsResult? loadLegacySecretsResult;
      try {
        loadLegacySecretsResult = await _loadLegacySecretsUseCase.execute(
          const LoadLegacySecretsQuery(),
        );
      } catch (e) {
        // Legacy seeds failed to load, but that's okay - continue without them
        loadLegacySecretsResult = null;
      }

      emit(
        SecretsViewState.loaded(
          secrets: loadAllStoredSecretsResult.secrets,
          inUseFingerprints: listUsedSecretsResult.fingerprints,
          legacySecrets: loadLegacySecretsResult?.secrets ?? [],
        ),
      );
    } on SecretsApplicationError catch (e) {
      emit(
        SecretsViewState.failedToLoad(
          error: SecretsPresentationError.fromApplicationError(e),
        ),
      );
    } catch (e) {
      emit(
        SecretsViewState.failedToLoad(
          error: UnknownSecretsPresentationError.fromException(e),
        ),
      );
    }
  }

  Future<void> _onDeleteRequested(
    SecretsViewDeleteRequested event,
    Emitter<SecretsViewState> emit,
  ) async {
    if (state is! SecretsViewLoaded) {
      // Cannot delete if not in loaded state
      return;
    } else {
      emit((state as SecretsViewLoaded).copyWith(isSecretBeingDeleted: true));

      try {
        await _deleteSecretUsecase.execute(
          DeleteSecretCommand(fingerprint: event.fingerprint.value),
        );

        // After successful deletion, remove the secret from the state too
        final remainingSecrets = List<Secret>.from(
          (state as SecretsViewLoaded).secrets,
        );
        remainingSecrets.removeWhere(
          (secret) => secret.fingerprint == event.fingerprint,
        );
        final remainingInUseFingerprints = (state as SecretsViewLoaded)
            .inUseFingerprints
            .where((fp) => fp != event.fingerprint)
            .toList();

        emit(
          SecretsViewState.loaded(
            secrets: remainingSecrets,
            inUseFingerprints: remainingInUseFingerprints,
          ),
        );
      } on SecretsApplicationError catch (e) {
        emit(
          (state as SecretsViewLoaded).copyWith(
            isSecretBeingDeleted: false,
            deletionError: SecretsPresentationError.fromApplicationError(e),
          ),
        );
      } catch (e) {
        emit(
          (state as SecretsViewLoaded).copyWith(
            isSecretBeingDeleted: false,
            deletionError: UnknownSecretsPresentationError.fromException(e),
          ),
        );
      }
    }
  }
}
