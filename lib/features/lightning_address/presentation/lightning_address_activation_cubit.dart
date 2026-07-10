import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/update_wallet_behavior_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/get_get_paid_wallet_behaviors_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_error.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_nym_validation.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/activate_wallet_owned_lightning_address_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_lightning_address_receive_readiness_usecase.dart';
import 'package:bb_mobile/features/lightning_address/presentation/lightning_address_activation_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LightningAddressActivationCubit
    extends Cubit<LightningAddressActivationState> {
  final ActivateWalletOwnedLightningAddressUsecase _activate;
  final LookupLightningAddressReceiveReadinessUsecase _lookupReadiness;
  final GetGetPaidWalletBehaviorsUsecase _getWalletBehaviors;
  final UpdateWalletBehaviorUsecase _updateWalletBehavior;
  int _operationId = 0;

  LightningAddressActivationCubit(
    this._activate,
    this._lookupReadiness,
    this._getWalletBehaviors,
    this._updateWalletBehavior,
  ) : super(const LightningAddressActivationState());

  Future<void> load() async {
    if (state.isSubmitting) return;
    final wasSubmissionUncertain =
        state.failure == LightningAddressActivationFailure.submissionUncertain;
    final operationId = ++_operationId;
    emit(
      state.copyWith(
        status: LightningAddressActivationStatus.loading,
        localSetupRetryable: false,
        autoSweepConfirmed: false,
        clearFailure: !wasSubmissionUncertain,
        clearRegisteredAddress: true,
      ),
    );

    // Resolve the reserved wallet locally FIRST (label-match, no server) so the
    // behavior controls stay reachable even when the status lookup below fails.
    final walletBehavior = await _resolveWalletBehavior();
    if (isClosed || operationId != _operationId || state.isSubmitting) return;

    try {
      final readiness = await _lookupReadiness.execute();
      if (isClosed || operationId != _operationId || state.isSubmitting) return;
      final registration = readiness.registration;
      emit(
        state.copyWith(
          status: readiness.localSetupFailed
              ? LightningAddressActivationStatus.activeLocalSetupFailed
              : registration.active
              ? LightningAddressActivationStatus.active
              : LightningAddressActivationStatus.inactive,
          nym: registration.active || state.nym.trim().isEmpty
              ? registration.nym
              : null,
          registeredAddress: registration.lightningAddress,
          localSetupRetryable: readiness.localSetupRetryable,
          autoSweepConfirmed: readiness.autoSweepEnabled,
          clearFailure: true,
          clearRegisteredAddress: registration.lightningAddress == null,
          walletBehavior: walletBehavior,
          clearWalletBehavior: walletBehavior == null,
        ),
      );
    } catch (e, stack) {
      log.warning(
        'Failed to load Lightning Address status',
        error: e,
        trace: stack,
      );
      if (isClosed || operationId != _operationId || state.isSubmitting) return;
      final failure = _lookupFailureFor(e);
      if (wasSubmissionUncertain &&
          failure != LightningAddressActivationFailure.noDefaultBitcoinWallet) {
        emit(
          state.copyWith(
            status: LightningAddressActivationStatus.failure,
            walletBehavior: walletBehavior,
            clearWalletBehavior: walletBehavior == null,
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: LightningAddressActivationStatus.failure,
          failure: failure,
          localSetupRetryable: false,
          clearRegisteredAddress: true,
          walletBehavior: walletBehavior,
          clearWalletBehavior: walletBehavior == null,
        ),
      );
    }
  }

  void nymChanged(String value) {
    emit(
      state.copyWith(
        status: state.status == LightningAddressActivationStatus.failure
            ? LightningAddressActivationStatus.idle
            : null,
        nym: value,
        clearFailure: true,
      ),
    );
  }

  void showRegistrationForm() {
    if (state.isSubmitting) return;
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
    } on LightningAddressException {
      return LightningAddressActivationFailure.invalidNym;
    }
  }

  Future<void> submit() async {
    if (state.isSubmitting) return;
    final nym = state.nym.trim();
    final validationFailure = validateNym(nym);
    if (validationFailure != null) {
      emit(
        state.copyWith(
          status: LightningAddressActivationStatus.failure,
          failure: validationFailure,
        ),
      );
      return;
    }

    _operationId++;
    emit(
      state.copyWith(
        status: LightningAddressActivationStatus.submitting,
        nym: nym,
        localSetupRetryable: false,
        clearFailure: true,
        clearRegisteredAddress: true,
      ),
    );

    try {
      final result = await _activate.execute(nym: nym);
      if (isClosed) return;
      // Activation prepares wallet 101, so refresh its resolved behavior.
      final walletBehavior = await _resolveWalletBehavior();
      if (isClosed) return;
      emit(
        state.copyWith(
          status: LightningAddressActivationStatus.registered,
          nym: result.nym,
          registeredAddress: result.lightningAddress,
          localSetupRetryable: false,
          autoSweepConfirmed: false,
          clearFailure: true,
          walletBehavior: walletBehavior,
          clearWalletBehavior: walletBehavior == null,
        ),
      );
    } catch (e, stack) {
      log.warning(
        'Failed to register Lightning Address',
        error: e,
        trace: stack,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          status: LightningAddressActivationStatus.failure,
          failure: _registrationFailureFor(e),
          localSetupRetryable: false,
          clearRegisteredAddress: true,
        ),
      );
    }
  }

  /// Updates the reserved wallet's auto-sweep / hide-on-home behavior with the
  /// same optimistic-emit / revert-on-failure / saving-guard posture BTCPay
  /// uses (`BtcpayPairingCubit.updateWalletBehavior`).
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
    } catch (e, stack) {
      log.warning(
        'Lightning Address wallet behavior update failed',
        error: e,
        trace: stack,
      );
      if (isClosed) return;
      emit(
        state.copyWith(walletBehavior: previous, walletBehaviorSaving: false),
      );
    }
  }

  // Read-only resolution of the reserved wallet (101); null until it exists.
  Future<GetPaidWalletBehavior?> _resolveWalletBehavior() async {
    try {
      final behaviors = await _getWalletBehaviors.execute(
        only: GetPaidWalletProduct.lightningAddress,
      );
      return behaviors.isEmpty ? null : behaviors.first;
    } catch (e, stack) {
      log.warning(
        'Failed to load Lightning Address wallet behavior',
        error: e,
        trace: stack,
      );
      return null;
    }
  }

  LightningAddressActivationFailure _registrationFailureFor(Object error) {
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
      WalletOwnedLightningAddressActivationException(
        cause: LightningAddressException(
          kind: LightningAddressErrorKind.invalidNym,
        ),
      ) =>
        LightningAddressActivationFailure.invalidNym,
      WalletOwnedLightningAddressActivationException(
        cause: LightningAddressException(
          kind: LightningAddressErrorKind.serverRejectedRequest,
          retryable: true,
        ),
      ) =>
        LightningAddressActivationFailure.serverTemporary,
      WalletOwnedLightningAddressActivationException(
        cause: LightningAddressException(
          kind: LightningAddressErrorKind.serverRejectedRequest,
        ),
      ) =>
        LightningAddressActivationFailure.rejected,
      WalletOwnedLightningAddressActivationException(
        cause: LightningAddressException(
          kind: LightningAddressErrorKind.network,
        ),
      ) =>
        LightningAddressActivationFailure.network,
      LightningAddressException(kind: LightningAddressErrorKind.invalidNym) =>
        LightningAddressActivationFailure.invalidNym,
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
    };
  }

  LightningAddressActivationFailure _lookupFailureFor(Object error) {
    return switch (error) {
      LightningAddressException(code: 'NoDefaultBitcoinWallet') =>
        LightningAddressActivationFailure.noDefaultBitcoinWallet,
      LightningAddressException(
        kind: LightningAddressErrorKind.localPreparationFailed,
      ) =>
        LightningAddressActivationFailure.setupFailed,
      _ => LightningAddressActivationFailure.lookupFailed,
    };
  }
}
