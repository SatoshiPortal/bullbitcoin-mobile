import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_failure.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/get_lightning_address_wallet_behavior_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_nym_validation.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_lightning_address_receive_readiness_usecase.dart';
import 'package:bb_mobile/features/lightning_address/presentation/lightning_address_activation_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LightningAddressActivationCubit
    extends Cubit<LightningAddressActivationState> {
  final Future<Result<bool, LightningAddressFailure>> Function() _getCapability;
  final Future<Result<LightningAddressRegistration, LightningAddressFailure>>
  Function({required String nym})
  _activate;
  final Future<Result<void, LightningAddressFailure>> Function({
    required String nym,
  })
  _deactivate;
  final Future<
    Result<LightningAddressReceiveReadiness, LightningAddressFailure>
  >
  Function()
  _lookupReadiness;
  final Future<LightningAddressWalletBehaviorRead> Function()
  _getWalletBehavior;
  final Future<bool> Function({
    required String walletId,
    bool? hideOnHome,
    bool? autoSweepEnabled,
  })
  _updateWalletBehavior;
  int _operationId = 0;

  LightningAddressActivationCubit({
    required this._getCapability,
    required this._activate,
    required this._deactivate,
    required this._lookupReadiness,
    required this._getWalletBehavior,
    required this._updateWalletBehavior,
  }) : super(const LightningAddressActivationState());

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
    final walletBehaviorRead = await _resolveWalletBehavior();
    if (_isStale(operationId)) return;

    final capability = await _getCapability();
    if (_isStale(operationId)) return;
    if (capability case Err(:final failure)) {
      log.warning(
        'Failed to load Bullnym permanent-name capability',
        error: failure.runtimeType,
      );
      _emitCapabilityInconsistency(walletBehaviorRead);
      return;
    }
    final permanentNamesSupported =
        (capability as Ok<bool, LightningAddressFailure>).value;

    if (!permanentNamesSupported) {
      await _loadLegacyStatus(
        operationId: operationId,
        walletBehaviorRead: walletBehaviorRead,
      );
      return;
    }

    await _loadPermanentNameStatus(
      operationId: operationId,
      walletBehaviorRead: walletBehaviorRead,
      hadPermanentNym: hadPermanentNym,
      preserveSubmissionUncertain: wasSubmissionUncertain,
    );
  }

  Future<void> _loadLegacyStatus({
    required int operationId,
    required LightningAddressWalletBehaviorRead walletBehaviorRead,
  }) async {
    final result = await _lookupReadiness();
    if (_isStale(operationId)) return;
    if (result case Err()) {
      // An old/unknown policy never enables claim or management controls. A
      // failed legacy lookup therefore degrades to a hidden, usable feature.
      _emitUnsupported(walletBehaviorRead: walletBehaviorRead);
      return;
    }
    final readiness =
        (result
                as Ok<
                  LightningAddressReceiveReadiness,
                  LightningAddressFailure
                >)
            .value;
    if (readiness.registration.permanentNameStatus != null) {
      _emitCapabilityInconsistency(walletBehaviorRead);
      return;
    }
    final registration = readiness.registration;
    if (!registration.active) {
      _emitUnsupported(
        walletBehaviorRead: walletBehaviorRead,
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
        walletBehavior: _behaviorFrom(walletBehaviorRead),
        clearWalletBehavior: _behaviorFrom(walletBehaviorRead) == null,
        walletBehaviorUnavailable:
            walletBehaviorRead is LightningAddressWalletBehaviorUnavailable,
      ),
    );
  }

  Future<void> _loadPermanentNameStatus({
    required int operationId,
    required LightningAddressWalletBehaviorRead walletBehaviorRead,
    required bool hadPermanentNym,
    required bool preserveSubmissionUncertain,
  }) async {
    final result = await _lookupReadiness();
    if (_isStale(operationId)) return;
    switch (result) {
      case Ok(:final value):
        _emitPermanentNameReadiness(
          value,
          walletBehaviorRead: walletBehaviorRead,
        );
      case Err(:final failure):
        if (failure.code == 'NymNotFound' && !hadPermanentNym) {
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
              walletBehavior: _behaviorFrom(walletBehaviorRead),
              clearWalletBehavior: _behaviorFrom(walletBehaviorRead) == null,
              walletBehaviorUnavailable:
                  walletBehaviorRead
                      is LightningAddressWalletBehaviorUnavailable,
            ),
          );
          return;
        }
        log.warning(
          'Failed to load Lightning Address permanent-name status',
          error: failure.runtimeType,
        );
        final presentationFailure = preserveSubmissionUncertain
            ? LightningAddressActivationFailure.submissionUncertain
            : switch (failure) {
                LightningAddressFailure(code: 'NoDefaultBitcoinWallet') =>
                  LightningAddressActivationFailure.noDefaultBitcoinWallet,
                LightningAddressFailure(
                  kind: LightningAddressFailureKind.localPreparation,
                ) =>
                  LightningAddressActivationFailure.setupFailed,
                _ => LightningAddressActivationFailure.lookupFailed,
              };
        emit(
          state.copyWith(
            status: LightningAddressActivationStatus.failure,
            failure: presentationFailure,
            permanentNamesSupported: true,
            hasPermanentNym: hadPermanentNym,
            onlineSaving: false,
            localSetupRetryable: false,
            clearRegisteredAddress: true,
            walletBehavior: _behaviorFrom(walletBehaviorRead),
            clearWalletBehavior: _behaviorFrom(walletBehaviorRead) == null,
            walletBehaviorUnavailable:
                walletBehaviorRead is LightningAddressWalletBehaviorUnavailable,
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
    return switch (validateLightningAddressNym(value)) {
      Ok() => null,
      Err(
        failure: LightningAddressFailure(
          kind: LightningAddressFailureKind.reservedNym,
        ),
      ) =>
        LightningAddressActivationFailure.reservedNym,
      Err() => LightningAddressActivationFailure.invalidNym,
    };
  }

  Future<void> submit() async {
    if (state.isBusy ||
        state.hasPermanentNym ||
        !state.permanentNamesSupported) {
      return;
    }
    final validation = validateLightningAddressNym(state.nym);
    if (validation case Err(:final failure)) {
      emit(
        state.copyWith(
          status: LightningAddressActivationStatus.idle,
          nym: normalizeLightningAddressNym(state.nym),
          failure: failure.kind == LightningAddressFailureKind.reservedNym
              ? LightningAddressActivationFailure.reservedNym
              : LightningAddressActivationFailure.invalidNym,
        ),
      );
      return;
    }
    final nym = (validation as Ok<String, LightningAddressFailure>).value;

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

    final activation = await _activate(nym: nym);
    if (_isStale(operationId)) return;
    if (activation case Err(:final failure)) {
      log.warning(
        'Failed to claim permanent Lightning Address nym',
        error: failure.runtimeType,
      );
      if (failure.code == 'NymAlreadyAssigned') {
        await _reconcileAlreadyAssigned(operationId, failure);
        return;
      }
      emit(
        state.copyWith(
          status: LightningAddressActivationStatus.failure,
          failure: _registrationFailureFor(failure),
          hasPermanentNym: false,
          localSetupRetryable: false,
          onlineSaving: false,
          clearRegisteredAddress: true,
          clearPermanentNameQuota: true,
        ),
      );
      return;
    }
    final registration =
        (activation
                as Ok<LightningAddressRegistration, LightningAddressFailure>)
            .value;
    // A successful mutation locks the returned owner nym immediately, then
    // status is re-read before any online/offline UI is rendered.
    emit(
      state.copyWith(
        nym: registration.nym,
        hasPermanentNym: true,
        permanentNamesSupported: true,
      ),
    );
    final walletBehaviorRead = await _resolveWalletBehavior();
    if (_isStale(operationId)) return;
    final refreshFailure = await _refreshAfterMutation(
      operationId: operationId,
      walletBehaviorRead: walletBehaviorRead,
    );
    if (refreshFailure != null && !_isStale(operationId)) {
      emit(
        state.copyWith(
          status: LightningAddressActivationStatus.failure,
          failure: LightningAddressActivationFailure.submissionUncertain,
          hasPermanentNym: true,
          onlineSaving: false,
          clearRegisteredAddress: true,
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
    emit(state.copyWith(onlineSaving: true, clearFailure: true));

    final Result<void, LightningAddressFailure> mutation;
    if (online) {
      mutation = (await _activate(nym: state.nym)).map<void>((_) {});
    } else {
      mutation = await _deactivate(nym: state.nym);
    }
    if (_isStale(operationId)) return;
    if (mutation case Err(:final failure)) {
      log.warning(
        online
            ? 'Failed to reactivate permanent Lightning Address'
            : 'Failed to deactivate permanent Lightning Address',
        error: failure.runtimeType,
      );
      if (failure.code == 'NymAlreadyAssigned') {
        await _reconcileAlreadyAssigned(operationId, failure);
        return;
      }
      emit(
        state.copyWith(
          status: previousStatus,
          failure: _toggleFailureFor(failure),
          onlineSaving: false,
        ),
      );
      return;
    }
    final walletBehaviorRead = await _resolveWalletBehavior();
    if (_isStale(operationId)) return;
    final refreshFailure = await _refreshAfterMutation(
      operationId: operationId,
      walletBehaviorRead: walletBehaviorRead,
    );
    if (refreshFailure != null && !_isStale(operationId)) {
      emit(
        state.copyWith(
          status: LightningAddressActivationStatus.failure,
          failure: LightningAddressActivationFailure.toggleUncertain,
          hasPermanentNym: true,
          onlineSaving: false,
          clearRegisteredAddress: true,
        ),
      );
    }
  }

  Future<LightningAddressFailure?> _refreshAfterMutation({
    required int operationId,
    required LightningAddressWalletBehaviorRead walletBehaviorRead,
  }) async {
    final readiness = await _lookupReadiness();
    if (_isStale(operationId)) return null;
    return switch (readiness) {
      Ok(:final value) => () {
        _emitPermanentNameReadiness(
          value,
          walletBehaviorRead: walletBehaviorRead,
        );
        return null;
      }(),
      Err(:final failure) => failure,
    };
  }

  Future<void> _reconcileAlreadyAssigned(
    int operationId,
    LightningAddressFailure failure,
  ) async {
    emit(
      state.copyWith(
        status: LightningAddressActivationStatus.failure,
        failure: LightningAddressActivationFailure.alreadyAssigned,
        nym: failure.ownedNym ?? state.nym,
        permanentNamesSupported: true,
        hasPermanentNym: true,
        onlineSaving: false,
        clearRegisteredAddress: true,
      ),
    );
    final walletBehaviorRead = await _resolveWalletBehavior();
    if (_isStale(operationId)) return;
    final readiness = await _lookupReadiness();
    if (_isStale(operationId)) return;
    switch (readiness) {
      case Ok(:final value):
        _emitPermanentNameReadiness(
          value,
          walletBehaviorRead: walletBehaviorRead,
          failure: LightningAddressActivationFailure.alreadyAssigned,
        );
      case Err(:final failure):
        log.warning(
          'Failed to reconcile owned permanent nym after conflict',
          error: failure.runtimeType,
        );
    }
  }

  void _emitPermanentNameReadiness(
    LightningAddressReceiveReadiness readiness, {
    required LightningAddressWalletBehaviorRead walletBehaviorRead,
    LightningAddressActivationFailure? failure,
  }) {
    final registration = readiness.registration;
    final permanentName = registration.permanentNameStatus;
    if (permanentName == null) {
      _emitCapabilityInconsistency(walletBehaviorRead);
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
        walletBehavior: _behaviorFrom(walletBehaviorRead),
        clearWalletBehavior: _behaviorFrom(walletBehaviorRead) == null,
        walletBehaviorUnavailable:
            walletBehaviorRead is LightningAddressWalletBehaviorUnavailable,
      ),
    );
  }

  void _emitCapabilityInconsistency(
    LightningAddressWalletBehaviorRead walletBehaviorRead,
  ) {
    emit(
      state.copyWith(
        status: LightningAddressActivationStatus.failure,
        failure: LightningAddressActivationFailure.capabilityUnavailable,
        permanentNamesSupported: false,
        hasPermanentNym: false,
        onlineSaving: false,
        clearRegisteredAddress: true,
        clearPermanentNameQuota: true,
        walletBehavior: _behaviorFrom(walletBehaviorRead),
        clearWalletBehavior: _behaviorFrom(walletBehaviorRead) == null,
        walletBehaviorUnavailable:
            walletBehaviorRead is LightningAddressWalletBehaviorUnavailable,
      ),
    );
  }

  void _emitUnsupported({
    required LightningAddressWalletBehaviorRead walletBehaviorRead,
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
        walletBehavior: _behaviorFrom(walletBehaviorRead),
        clearWalletBehavior: _behaviorFrom(walletBehaviorRead) == null,
        walletBehaviorUnavailable:
            walletBehaviorRead is LightningAddressWalletBehaviorUnavailable,
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
        walletBehavior: previous.withRequestedChange(
          hideOnHome: hideOnHome,
          autoSweepEnabled: autoSweepEnabled,
        ),
        walletBehaviorSaving: true,
      ),
    );
    final saved = await _updateWalletBehavior(
      walletId: walletId,
      hideOnHome: hideOnHome,
      autoSweepEnabled: autoSweepEnabled,
    );
    if (isClosed) return;
    if (!saved) {
      // The write did not land: restore what was optimistically shown.
      emit(
        state.copyWith(walletBehavior: previous, walletBehaviorSaving: false),
      );
      return;
    }
    final refreshed = await _resolveWalletBehavior();
    if (isClosed) return;
    emit(
      state.copyWith(
        walletBehavior: _behaviorFrom(refreshed),
        clearWalletBehavior: _behaviorFrom(refreshed) == null,
        walletBehaviorUnavailable:
            refreshed is LightningAddressWalletBehaviorUnavailable,
        walletBehaviorSaving: false,
      ),
    );
  }

  /// Retries only the reserved-wallet settings read. Registration drafts stay
  /// untouched, and the shared guard prevents overlapping reads or writes.
  Future<void> retryWalletBehavior() async {
    if (state.walletBehaviorSaving) return;
    emit(state.copyWith(walletBehaviorSaving: true));
    final refreshed = await _resolveWalletBehavior();
    if (isClosed) return;
    final behavior = _behaviorFrom(refreshed);
    emit(
      state.copyWith(
        walletBehavior: behavior,
        clearWalletBehavior: behavior == null,
        walletBehaviorUnavailable:
            refreshed is LightningAddressWalletBehaviorUnavailable,
        walletBehaviorSaving: false,
      ),
    );
  }

  Future<LightningAddressWalletBehaviorRead> _resolveWalletBehavior() =>
      _getWalletBehavior();

  GetPaidWalletBehavior? _behaviorFrom(
    LightningAddressWalletBehaviorRead result,
  ) => switch (result) {
    LightningAddressWalletBehaviorFound(:final behavior) => behavior,
    LightningAddressWalletBehaviorAbsent() => null,
    LightningAddressWalletBehaviorUnavailable() => null,
  };

  LightningAddressActivationFailure _registrationFailureFor(
    LightningAddressFailure failure,
  ) {
    if (failure.code == 'NameTaken') {
      return LightningAddressActivationFailure.nameTaken;
    }
    if (failure.code == 'NymReserved') {
      return LightningAddressActivationFailure.reservedNym;
    }
    if (failure.code == 'NymInvalid' ||
        failure.kind == LightningAddressFailureKind.invalidNym) {
      return LightningAddressActivationFailure.invalidNym;
    }
    return switch (failure) {
      LightningAddressFailure(code: 'NoDefaultBitcoinWallet') =>
        LightningAddressActivationFailure.noDefaultBitcoinWallet,
      LightningAddressFailure(
        phase: LightningAddressFailurePhase.localPreparation,
      ) =>
        LightningAddressActivationFailure.setupFailed,
      // A timeout or an unreachable server produced no answer to interpret:
      // report that plainly and offer a retry, rather than telling the user the
      // outcome is unknown. If the claim did land, the retry reconciles it
      // through the NymAlreadyAssigned path.
      LightningAddressFailure(
        phase: LightningAddressFailurePhase.registrationSubmission,
        kind: LightningAddressFailureKind.timeout ||
            LightningAddressFailureKind.network,
      ) =>
        LightningAddressActivationFailure.noServerResponse,
      LightningAddressFailure(
        phase: LightningAddressFailurePhase.registrationSubmission,
        submissionMayBeUncertain: true,
      ) =>
        LightningAddressActivationFailure.submissionUncertain,
      _ => switch (failure) {
        LightningAddressFailure(
          kind: LightningAddressFailureKind.reservedNym,
        ) =>
          LightningAddressActivationFailure.reservedNym,
        LightningAddressFailure(
          kind: LightningAddressFailureKind.serverRejected,
          retryable: true,
        ) =>
          LightningAddressActivationFailure.serverTemporary,
        LightningAddressFailure(
          kind: LightningAddressFailureKind.serverRejected,
        ) =>
          LightningAddressActivationFailure.rejected,
        LightningAddressFailure(kind: LightningAddressFailureKind.network) =>
          LightningAddressActivationFailure.network,
        _ => LightningAddressActivationFailure.generic,
      },
    };
  }

  LightningAddressActivationFailure _toggleFailureFor(
    LightningAddressFailure failure,
  ) {
    return switch (failure.kind) {
      LightningAddressFailureKind.network ||
      LightningAddressFailureKind.timeout ||
      LightningAddressFailureKind.invalidResponse =>
        LightningAddressActivationFailure.toggleUncertain,
      LightningAddressFailureKind.serverRejected when failure.retryable =>
        LightningAddressActivationFailure.serverTemporary,
      _ => LightningAddressActivationFailure.generic,
    };
  }

  bool _isStale(int operationId) => isClosed || operationId != _operationId;
}
