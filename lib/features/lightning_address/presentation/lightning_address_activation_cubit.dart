import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_error.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_nym_validation.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/activate_wallet_owned_lightning_address_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_wallet_owned_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/presentation/lightning_address_activation_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LightningAddressActivationCubit
    extends Cubit<LightningAddressActivationState> {
  final ActivateWalletOwnedLightningAddressUsecase _activate;
  final LookupWalletOwnedLightningAddressRegistrationUsecase _lookupStatus;
  int _operationId = 0;

  LightningAddressActivationCubit(this._activate, this._lookupStatus)
    : super(const LightningAddressActivationState());

  Future<void> load() async {
    if (state.isSubmitting) return;
    final wasSubmissionUncertain =
        state.failure == LightningAddressActivationFailure.submissionUncertain;
    final operationId = ++_operationId;
    emit(
      state.copyWith(
        status: LightningAddressActivationStatus.loading,
        clearFailure: !wasSubmissionUncertain,
        clearRegisteredAddress: true,
      ),
    );

    try {
      final status = await _lookupStatus.execute();
      if (isClosed || operationId != _operationId || state.isSubmitting) return;
      emit(
        state.copyWith(
          status: status.active
              ? LightningAddressActivationStatus.active
              : LightningAddressActivationStatus.inactive,
          nym: status.active || state.nym.trim().isEmpty ? status.nym : null,
          clearFailure: true,
          clearRegisteredAddress: true,
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
        emit(state.copyWith(status: LightningAddressActivationStatus.failure));
        return;
      }
      emit(
        state.copyWith(
          status: LightningAddressActivationStatus.failure,
          failure: failure,
          clearRegisteredAddress: true,
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
        clearFailure: true,
        clearRegisteredAddress: true,
      ),
    );

    try {
      final result = await _activate.execute(nym: nym);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: LightningAddressActivationStatus.registered,
          nym: result.nym,
          registeredAddress: result.lightningAddress,
          clearFailure: true,
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
          clearRegisteredAddress: true,
        ),
      );
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
      _ => LightningAddressActivationFailure.lookupFailed,
    };
  }
}
