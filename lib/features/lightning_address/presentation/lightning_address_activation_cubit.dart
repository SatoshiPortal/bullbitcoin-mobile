import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/update_wallet_behavior_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/get_get_paid_wallet_behaviors_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_error.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_nym_validation.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/activate_wallet_owned_lightning_address_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/deactivate_wallet_owned_lightning_address_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/get_lightning_address_permanent_name_capability_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_lightning_address_receive_readiness_usecase.dart';
import 'package:bb_mobile/features/lightning_address/presentation/lightning_address_activation_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LightningAddressActivationCubit
    extends Cubit<LightningAddressActivationState> {
  final GetLightningAddressPermanentNameCapabilityUsecase _getCapability;
  final ActivateWalletOwnedLightningAddressUsecase _activate;
  final DeactivateWalletOwnedLightningAddressUsecase _deactivate;
  final LookupLightningAddressReceiveReadinessUsecase _lookupReadiness;
  final GetGetPaidWalletBehaviorsUsecase _getWalletBehaviors;
  final UpdateWalletBehaviorUsecase _updateWalletBehavior;
  int _operationId = 0;

  LightningAddressActivationCubit(
    this._getCapability,
    this._activate,
    this._deactivate,
    this._lookupReadiness,
    this._getWalletBehaviors,
    this._updateWalletBehavior,
  ) : super(const LightningAddressActivationState());

  Future<void> load() async {
    if (state.isBusy) return;
    final wasSubmissionUncertain =
        state.failure == LightningAddressActivationFailure.submissionUncertain;
    final hadPermanentNym = state.hasPermanentNym;
    final operationId = ++_operationId;
    emit(
      state.copyWith(
        status: LightningAddressActivationStatus.loading,
        localSetupRetryable: false,
        autoSweepConfirmed: false,
        onlineSaving: false,
        clearFailure: !wasSubmissionUncertain,
        clearRegisteredAddress: true,
      ),
    );

    // Resolve the local wallet independently so its behavior controls remain
    // available if a later read fails. This never authorizes a name mutation.
    final walletBehavior = await _resolveWalletBehavior();
    if (_isStale(operationId)) return;

    late final bool permanentNamesSupported;
    try {
      permanentNamesSupported = await _getCapability.execute();
    } catch (error, stack) {
      log.warning(
        'Failed to load Bullnym permanent-name capability',
        error: error,
        trace: stack,
      );
      if (_isStale(operationId)) return;
      emit(
        state.copyWith(
          status: LightningAddressActivationStatus.failure,
          failure: LightningAddressActivationFailure.capabilityUnavailable,
          permanentNamesSupported: false,
          onlineSaving: false,
          walletBehavior: walletBehavior,
          clearWalletBehavior: walletBehavior == null,
          clearRegisteredAddress: true,
          clearPermanentNameQuota: true,
        ),
      );
      return;
    }
    if (_isStale(operationId)) return;

    if (!permanentNamesSupported) {
      await _loadLegacyStatus(
        operationId: operationId,
        walletBehavior: walletBehavior,
      );
      return;
    }

    await _loadPermanentNameStatus(
      operationId: operationId,
      walletBehavior: walletBehavior,
      hadPermanentNym: hadPermanentNym,
      preserveSubmissionUncertain: wasSubmissionUncertain,
    );
  }

  Future<void> _loadLegacyStatus({
    required int operationId,
    required GetPaidWalletBehavior? walletBehavior,
  }) async {
    try {
      final readiness = await _lookupReadiness.execute();
      if (_isStale(operationId)) return;
      if (readiness.registration.permanentNameStatus != null) {
        _emitCapabilityInconsistency(walletBehavior);
        return;
      }
      final registration = readiness.registration;
      if (!registration.active) {
        _emitUnsupported(
          walletBehavior: walletBehavior,
          legacyNym: registration.nym,
        );
        return;
      }
      emit(
        state.copyWith(
          status: readiness.localSetupFailed
              ? LightningAddressActivationStatus.activeLocalSetupFailed
              : LightningAddressActivationStatus.active,
          nym: registration.nym,
          registeredAddress: registration.lightningAddress,
          permanentNamesSupported: false,
          hasPermanentNym: false,
          localSetupRetryable: readiness.localSetupRetryable,
          autoSweepConfirmed: readiness.autoSweepEnabled,
          onlineSaving: false,
          clearFailure: true,
          clearRegisteredAddress: registration.lightningAddress == null,
          clearPermanentNameQuota: true,
          walletBehavior: walletBehavior,
          clearWalletBehavior: walletBehavior == null,
        ),
      );
    } catch (_) {
      if (_isStale(operationId)) return;
      // An old/unknown policy never enables claim or management controls. A
      // failed legacy lookup therefore degrades to a hidden, usable feature.
      _emitUnsupported(walletBehavior: walletBehavior);
    }
  }

  Future<void> _loadPermanentNameStatus({
    required int operationId,
    required GetPaidWalletBehavior? walletBehavior,
    required bool hadPermanentNym,
    required bool preserveSubmissionUncertain,
  }) async {
    try {
      final readiness = await _lookupReadiness.execute();
      if (_isStale(operationId)) return;
      _emitPermanentNameReadiness(readiness, walletBehavior: walletBehavior);
    } catch (error, stack) {
      log.warning(
        'Failed to load Lightning Address permanent-name status',
        error: error,
        trace: stack,
      );
      if (_isStale(operationId)) return;
      final cause = _lightningAddressCause(error);
      if (cause?.code == 'NymNotFound' && !hadPermanentNym) {
        emit(
          state.copyWith(
            status: LightningAddressActivationStatus.idle,
            nym: '',
            permanentNamesSupported: true,
            hasPermanentNym: false,
            localSetupRetryable: false,
            autoSweepConfirmed: false,
            onlineSaving: false,
            clearFailure: true,
            clearRegisteredAddress: true,
            clearPermanentNameQuota: true,
            walletBehavior: walletBehavior,
            clearWalletBehavior: walletBehavior == null,
          ),
        );
        return;
      }
      final failure = preserveSubmissionUncertain
          ? LightningAddressActivationFailure.submissionUncertain
          : switch (cause) {
              LightningAddressException(code: 'NoDefaultBitcoinWallet') =>
                LightningAddressActivationFailure.noDefaultBitcoinWallet,
              LightningAddressException(
                kind: LightningAddressErrorKind.localPreparationFailed,
              ) =>
                LightningAddressActivationFailure.setupFailed,
              _ => LightningAddressActivationFailure.lookupFailed,
            };
      emit(
        state.copyWith(
          status: LightningAddressActivationStatus.failure,
          failure: failure,
          permanentNamesSupported: true,
          hasPermanentNym: hadPermanentNym,
          onlineSaving: false,
          localSetupRetryable: false,
          clearRegisteredAddress: true,
          walletBehavior: walletBehavior,
          clearWalletBehavior: walletBehavior == null,
        ),
      );
    }
  }

  void nymChanged(String value) {
    if (state.isBusy ||
        state.hasPermanentNym ||
        !state.permanentNamesSupported) {
      return;
    }
    final normalized = normalizeLightningAddressNym(value);
    emit(
      state.copyWith(
        status: LightningAddressActivationStatus.idle,
        nym: normalized,
        clearFailure: true,
      ),
    );
  }

  void showRegistrationForm() {
    if (state.isBusy ||
        state.hasPermanentNym ||
        !state.permanentNamesSupported) {
      return;
    }
    emit(
      state.copyWith(
        status: LightningAddressActivationStatus.idle,
        localSetupRetryable: false,
        clearFailure: true,
        clearRegisteredAddress: true,
      ),
    );
  }

  LightningAddressActivationFailure? validateNym(String value) {
    try {
      validateLightningAddressNym(value);
      return null;
    } on LightningAddressException catch (error) {
      return error.kind == LightningAddressErrorKind.reservedNym
          ? LightningAddressActivationFailure.reservedNym
          : LightningAddressActivationFailure.invalidNym;
    }
  }

  Future<void> submit() async {
    if (state.isBusy ||
        state.hasPermanentNym ||
        !state.permanentNamesSupported) {
      return;
    }
    late final String nym;
    try {
      nym = validateLightningAddressNym(state.nym);
    } on LightningAddressException catch (error) {
      emit(
        state.copyWith(
          status: LightningAddressActivationStatus.idle,
          nym: normalizeLightningAddressNym(state.nym),
          failure: error.kind == LightningAddressErrorKind.reservedNym
              ? LightningAddressActivationFailure.reservedNym
              : LightningAddressActivationFailure.invalidNym,
        ),
      );
      return;
    }

    final operationId = ++_operationId;
    emit(
      state.copyWith(
        status: LightningAddressActivationStatus.submitting,
        nym: nym,
        localSetupRetryable: false,
        onlineSaving: false,
        clearFailure: true,
        clearRegisteredAddress: true,
      ),
    );

    var mutationSucceeded = false;
    try {
      final result = await _activate.execute(nym: nym);
      mutationSucceeded = true;
      if (_isStale(operationId)) return;
      // A successful mutation locks the returned owner nym immediately, then
      // status is re-read before any online/offline UI is rendered.
      emit(
        state.copyWith(
          nym: result.nym,
          hasPermanentNym: true,
          permanentNamesSupported: true,
        ),
      );
      final walletBehavior = await _resolveWalletBehavior();
      if (_isStale(operationId)) return;
      await _refreshAfterMutation(
        operationId: operationId,
        walletBehavior: walletBehavior,
      );
    } catch (error, stack) {
      log.warning(
        'Failed to claim permanent Lightning Address nym',
        error: error,
        trace: stack,
      );
      if (_isStale(operationId)) return;
      if (_lightningAddressCause(error)?.code == 'NymAlreadyAssigned') {
        await _reconcileAlreadyAssigned(operationId, error);
        return;
      }
      if (mutationSucceeded) {
        emit(
          state.copyWith(
            status: LightningAddressActivationStatus.failure,
            failure: LightningAddressActivationFailure.submissionUncertain,
            hasPermanentNym: true,
            onlineSaving: false,
            clearRegisteredAddress: true,
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: LightningAddressActivationStatus.failure,
          failure: _registrationFailureFor(error),
          hasPermanentNym: false,
          localSetupRetryable: false,
          onlineSaving: false,
          clearRegisteredAddress: true,
          clearPermanentNameQuota: true,
        ),
      );
    }
  }

  Future<void> activateExisting() => _setOnline(true);

  Future<void> deactivate() => _setOnline(false);

  Future<void> _setOnline(bool online) async {
    if (state.isBusy ||
        !state.permanentNamesSupported ||
        !state.hasPermanentNym ||
        state.nym.isEmpty ||
        (online && !state.isInactive) ||
        (!online && !state.isActive && !state.isActiveLocalSetupFailed)) {
      return;
    }
    final previousStatus = state.status;
    final operationId = ++_operationId;
    var mutationSucceeded = false;
    emit(state.copyWith(onlineSaving: true, clearFailure: true));

    try {
      if (online) {
        await _activate.execute(nym: state.nym);
      } else {
        await _deactivate.execute(nym: state.nym);
      }
      mutationSucceeded = true;
      if (_isStale(operationId)) return;
      final walletBehavior = await _resolveWalletBehavior();
      if (_isStale(operationId)) return;
      await _refreshAfterMutation(
        operationId: operationId,
        walletBehavior: walletBehavior,
      );
    } catch (error, stack) {
      log.warning(
        online
            ? 'Failed to reactivate permanent Lightning Address'
            : 'Failed to deactivate permanent Lightning Address',
        error: error,
        trace: stack,
      );
      if (_isStale(operationId)) return;
      if (_lightningAddressCause(error)?.code == 'NymAlreadyAssigned') {
        await _reconcileAlreadyAssigned(operationId, error);
        return;
      }
      if (mutationSucceeded) {
        emit(
          state.copyWith(
            status: LightningAddressActivationStatus.failure,
            failure: LightningAddressActivationFailure.toggleUncertain,
            hasPermanentNym: true,
            onlineSaving: false,
            clearRegisteredAddress: true,
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: previousStatus,
          failure: _toggleFailureFor(error),
          onlineSaving: false,
        ),
      );
    }
  }

  Future<void> _refreshAfterMutation({
    required int operationId,
    required GetPaidWalletBehavior? walletBehavior,
  }) async {
    final readiness = await _lookupReadiness.execute();
    if (_isStale(operationId)) return;
    _emitPermanentNameReadiness(readiness, walletBehavior: walletBehavior);
  }

  Future<void> _reconcileAlreadyAssigned(int operationId, Object error) async {
    final cause = _lightningAddressCause(error);
    final ownedNym = cause is LightningAddressServerRejectedRequestException
        ? cause.ownedNym
        : null;
    emit(
      state.copyWith(
        status: LightningAddressActivationStatus.failure,
        failure: LightningAddressActivationFailure.alreadyAssigned,
        nym: ownedNym ?? state.nym,
        permanentNamesSupported: true,
        hasPermanentNym: true,
        onlineSaving: false,
        clearRegisteredAddress: true,
      ),
    );
    try {
      final walletBehavior = await _resolveWalletBehavior();
      if (_isStale(operationId)) return;
      final readiness = await _lookupReadiness.execute();
      if (_isStale(operationId)) return;
      _emitPermanentNameReadiness(
        readiness,
        walletBehavior: walletBehavior,
        failure: LightningAddressActivationFailure.alreadyAssigned,
      );
    } catch (lookupError, stack) {
      log.warning(
        'Failed to reconcile owned permanent nym after conflict',
        error: lookupError,
        trace: stack,
      );
    }
  }

  void _emitPermanentNameReadiness(
    LightningAddressReceiveReadiness readiness, {
    required GetPaidWalletBehavior? walletBehavior,
    LightningAddressActivationFailure? failure,
  }) {
    final registration = readiness.registration;
    final permanentName = registration.permanentNameStatus;
    if (permanentName == null) {
      _emitCapabilityInconsistency(walletBehavior);
      return;
    }
    final lightningAddress = registration.lightningAddress;
    emit(
      state.copyWith(
        status: lightningAddress == null
            ? LightningAddressActivationStatus.addressUnavailable
            : readiness.localSetupFailed
            ? LightningAddressActivationStatus.activeLocalSetupFailed
            : permanentName.lightningAddressOnline
            ? LightningAddressActivationStatus.active
            : LightningAddressActivationStatus.inactive,
        failure: failure,
        nym: permanentName.nym,
        registeredAddress: lightningAddress,
        permanentNamesSupported: true,
        hasPermanentNym: true,
        permanentNameQuota: permanentName.quota,
        localSetupRetryable: readiness.localSetupRetryable,
        autoSweepConfirmed: readiness.autoSweepEnabled,
        onlineSaving: false,
        clearFailure: failure == null,
        clearRegisteredAddress: lightningAddress == null,
        walletBehavior: walletBehavior,
        clearWalletBehavior: walletBehavior == null,
      ),
    );
  }

  void _emitCapabilityInconsistency(GetPaidWalletBehavior? walletBehavior) {
    emit(
      state.copyWith(
        status: LightningAddressActivationStatus.failure,
        failure: LightningAddressActivationFailure.capabilityUnavailable,
        permanentNamesSupported: false,
        hasPermanentNym: false,
        onlineSaving: false,
        clearRegisteredAddress: true,
        clearPermanentNameQuota: true,
        walletBehavior: walletBehavior,
        clearWalletBehavior: walletBehavior == null,
      ),
    );
  }

  void _emitUnsupported({
    required GetPaidWalletBehavior? walletBehavior,
    String legacyNym = '',
  }) {
    emit(
      state.copyWith(
        status: LightningAddressActivationStatus.unsupported,
        nym: legacyNym,
        permanentNamesSupported: false,
        hasPermanentNym: false,
        onlineSaving: false,
        clearFailure: true,
        clearRegisteredAddress: true,
        clearPermanentNameQuota: true,
        walletBehavior: walletBehavior,
        clearWalletBehavior: walletBehavior == null,
      ),
    );
  }

  /// Updates only local wallet display/sweep behavior. Permanent-name and
  /// Page/POS server state are neither read nor optimistically mutated here.
  Future<void> updateWalletBehavior({
    required String walletId,
    bool? hideOnHome,
    bool? autoSweepEnabled,
  }) async {
    if (state.walletBehaviorSaving) return;
    final previous = state.walletBehavior;
    if (previous == null || previous.walletId != walletId) return;
    emit(
      state.copyWith(
        walletBehavior: previous.copyWith(
          hideOnHome: hideOnHome,
          autoSweepEnabled: autoSweepEnabled,
        ),
        walletBehaviorSaving: true,
      ),
    );
    try {
      await _updateWalletBehavior.execute(
        walletId: walletId,
        hideOnHome: hideOnHome,
        autoSweepEnabled: autoSweepEnabled,
      );
      if (isClosed) return;
      final refreshed = await _resolveWalletBehavior();
      if (isClosed) return;
      emit(
        state.copyWith(
          walletBehavior: refreshed,
          clearWalletBehavior: refreshed == null,
          walletBehaviorSaving: false,
        ),
      );
    } catch (error, stack) {
      log.warning(
        'Lightning Address wallet behavior update failed',
        error: error,
        trace: stack,
      );
      if (isClosed) return;
      emit(
        state.copyWith(walletBehavior: previous, walletBehaviorSaving: false),
      );
    }
  }

  Future<GetPaidWalletBehavior?> _resolveWalletBehavior() async {
    try {
      final behaviors = await _getWalletBehaviors.execute(
        only: GetPaidWalletProduct.lightningAddress,
      );
      return behaviors.isEmpty ? null : behaviors.first;
    } catch (error, stack) {
      log.warning(
        'Failed to load Lightning Address wallet behavior',
        error: error,
        trace: stack,
      );
      return null;
    }
  }

  LightningAddressActivationFailure _registrationFailureFor(Object error) {
    final cause = _lightningAddressCause(error);
    if (cause?.code == 'NameTaken') {
      return LightningAddressActivationFailure.nameTaken;
    }
    if (cause?.code == 'NymReserved') {
      return LightningAddressActivationFailure.reservedNym;
    }
    if (cause?.code == 'NymInvalid' ||
        cause?.kind == LightningAddressErrorKind.invalidNym) {
      return LightningAddressActivationFailure.invalidNym;
    }
    return switch (error) {
      WalletOwnedLightningAddressActivationException(
        cause: LightningAddressException(code: 'NoDefaultBitcoinWallet'),
      ) =>
        LightningAddressActivationFailure.noDefaultBitcoinWallet,
      WalletOwnedLightningAddressActivationException(
        phase: WalletOwnedLightningAddressActivationFailurePhase
            .localPreparation,
      ) =>
        LightningAddressActivationFailure.setupFailed,
      WalletOwnedLightningAddressActivationException(
        phase: WalletOwnedLightningAddressActivationFailurePhase
            .registrationSubmission,
        submissionMayBeUncertain: true,
      ) =>
        LightningAddressActivationFailure.submissionUncertain,
      _ => switch (cause) {
        LightningAddressException(
          kind: LightningAddressErrorKind.reservedNym,
        ) =>
          LightningAddressActivationFailure.reservedNym,
        LightningAddressException(
          kind: LightningAddressErrorKind.serverRejectedRequest,
          retryable: true,
        ) =>
          LightningAddressActivationFailure.serverTemporary,
        LightningAddressException(
          kind: LightningAddressErrorKind.serverRejectedRequest,
        ) =>
          LightningAddressActivationFailure.rejected,
        LightningAddressException(kind: LightningAddressErrorKind.network) =>
          LightningAddressActivationFailure.network,
        _ => LightningAddressActivationFailure.generic,
      },
    };
  }

  LightningAddressActivationFailure _toggleFailureFor(Object error) {
    final cause = _lightningAddressCause(error);
    return switch (cause?.kind) {
      LightningAddressErrorKind.network ||
      LightningAddressErrorKind.timeout ||
      LightningAddressErrorKind.invalidServerResponse =>
        LightningAddressActivationFailure.toggleUncertain,
      LightningAddressErrorKind.serverRejectedRequest when cause!.retryable =>
        LightningAddressActivationFailure.serverTemporary,
      _ => LightningAddressActivationFailure.generic,
    };
  }

  LightningAddressException? _lightningAddressCause(Object error) {
    return switch (error) {
      WalletOwnedLightningAddressActivationException(:final cause) => cause,
      WalletOwnedLightningAddressRegistrationException(:final cause) => cause,
      final LightningAddressException exception => exception,
      _ => null,
    };
  }

  bool _isStale(int operationId) => isClosed || operationId != _operationId;
}
