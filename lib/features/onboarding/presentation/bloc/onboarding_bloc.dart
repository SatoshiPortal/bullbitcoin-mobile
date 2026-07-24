import 'dart:async';

import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_birthday_checkpoint.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_compact_block_filters_available_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/resolve_wallet_birthday_checkpoint_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_birthday_checkpoint_failure.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_bloc.freezed.dart';
part 'onboarding_event.dart';
part 'onboarding_state.dart';

/// The mnemonic + its metadata as entered on `OnboardingPhysicalRecovery`,
/// already validated by `MnemonicWidget` before `onSubmit` ever fires.
/// Named here (rather than left as an inline anonymous record everywhere)
/// since it is now carried across two events —
/// [OnboardingRecoverWalletClicked] and, once resolved,
/// [OnboardingBitcoinBirthdayResolved]'s [OnboardingState.pendingRecoveryMnemonic]
/// — via `state.copyWith`.
typedef RecoveryMnemonic = ({
  List<String> words,
  String passphrase,
  String label,
  bip39.Language language,
});

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc({
    required this._createDefaultWalletsUsecase,
    required this._completePhysicalBackupVerificationUsecase,
    required this._getSettingsUsecase,
    required this._checkCompactBlockFiltersAvailableUsecase,
    required this._resolveWalletBirthdayCheckpointUsecase,
  }) : super(const OnboardingState()) {
    on<OnboardingCreateNewWallet>(_onCreateNewWallet);
    on<OnboardingRecoverWalletClicked>(_onRecoverWalletClicked);
    on<OnboardingBitcoinBirthdayResolved>(_onBitcoinBirthdayResolved);

    on<OnboardingGoBack>((event, emit) {
      emit(state.copyWith(step: OnboardingStep.splash));
    });
  }

  final CreateDefaultWalletsUsecase _createDefaultWalletsUsecase;

  final CompletePhysicalBackupVerificationUsecase
  _completePhysicalBackupVerificationUsecase;

  // The three collaborators below exist solely to gate/resolve the
  // compact-block-filter birthday picker for a mnemonic recovery — see
  // `_onRecoverWalletClicked` and `_onBitcoinBirthdayResolved`. A freshly
  // generated wallet never touches them: `CreateDefaultWalletsUsecase`
  // resolves that checkpoint entirely on its own (see its doc).
  final GetSettingsUsecase _getSettingsUsecase;
  final CheckCompactBlockFiltersAvailableUsecase
  _checkCompactBlockFiltersAvailableUsecase;
  final ResolveWalletBirthdayCheckpointUsecase
  _resolveWalletBirthdayCheckpointUsecase;

  /// The single call point `WalletBirthdayPicker` (via
  /// `OnboardingPhysicalRecovery`) uses to resolve a candidate birthday
  /// while the user is still choosing one — not an `on<Event>` handler
  /// since the picker's own retry/genesis-fallback UI is purely local
  /// widget state (AGENTS.md rule #5), not something that needs to flow
  /// back through a bloc state transition on every attempt. Always
  /// `WalletBirthdayLookupMode.recovery`: this method only ever runs for
  /// the mnemonic-recovery flow (see [RecoveryMnemonic] above).
  Future<Result<WalletBirthdayCheckpoint, WalletBirthdayCheckpointFailure>>
  resolveBitcoinBirthdayCheckpoint(DateTime requestedBirthday) {
    return _resolveWalletBirthdayCheckpointUsecase.execute(
      requestedBirthday: requestedBirthday,
      isTestnet: state.pendingRecoveryIsTestnet,
      lookupMode: WalletBirthdayLookupMode.recovery,
    );
  }

  Future<void> _handleError(Object error, Emitter<OnboardingState> emit) async {
    log.severe(error: error, trace: StackTrace.current);
    emit(
      state.copyWith(
        onboardingStepStatus: OnboardingStepStatus.none,
        step: OnboardingStep.splash,
        statusError: error.toString(),
      ),
    );
  }

  Future<void> _onCreateNewWallet(
    OnboardingCreateNewWallet event,
    Emitter<OnboardingState> emit,
  ) async {
    // Bloc events are processed serially. By the time a 2nd queued event
    // dequeues, the 1st emit has already flipped the status to loading,
    // so this guard drops the duplicate (#2015).
    if (state.onboardingStepStatus == OnboardingStepStatus.loading) return;
    try {
      emit(
        state.copyWith(
          onboardingStepStatus: OnboardingStepStatus.loading,
          step: OnboardingStep.create,
          statusError: '',
        ),
      );
      await _createDefaultWalletsUsecase.execute();
      emit(state.copyWith(onboardingStepStatus: OnboardingStepStatus.success));
    } catch (e) {
      await _handleError(e, emit);
    }
  }

  Future<void> _onRecoverWalletClicked(
    OnboardingRecoverWalletClicked event,
    Emitter<OnboardingState> emit,
  ) async {
    // Same serialized-event guard as `_onCreateNewWallet` (#2015).
    if (state.onboardingStepStatus == OnboardingStepStatus.loading) return;
    try {
      emit(
        state.copyWith(
          onboardingStepStatus: OnboardingStepStatus.loading,
          step: OnboardingStep.recover,
          statusError: '',
        ),
      );

      // Gate the birthday picker on the CBF preference selected earlier in
      // the wizard (`SettingsEntity.useCompactBlockFiltersByDefault`) AND
      // its own availability gate — mirrors exactly what
      // `CreateDefaultWalletsUsecase` itself checks before choosing
      // `BitcoinSyncBackend.compactBlockFilters`, so the picker is offered
      // if and only if the recovered default Bitcoin wallet will actually
      // use CBF.
      final settings = await _getSettingsUsecase.execute();
      final needsBirthdayPicker =
          settings.useCompactBlockFiltersByDefault &&
          await _checkCompactBlockFiltersAvailableUsecase.execute();

      if (needsBirthdayPicker) {
        emit(
          state.copyWith(
            onboardingStepStatus: OnboardingStepStatus.none,
            needsBitcoinBirthdaySelection: true,
            pendingRecoveryMnemonic: event.mnemonic,
            pendingRecoveryIsTestnet: settings.environment.isTestnet,
          ),
        );
        return;
      }

      await _createDefaultWalletsUsecase.execute(
        mnemonicWords: event.mnemonic.words,
      );
      await _completePhysicalBackupVerificationUsecase.execute();
      emit(state.copyWith(onboardingStepStatus: OnboardingStepStatus.success));
    } catch (e) {
      await _handleError(e, emit);
    }
  }

  Future<void> _onBitcoinBirthdayResolved(
    OnboardingBitcoinBirthdayResolved event,
    Emitter<OnboardingState> emit,
  ) async {
    final pending = state.pendingRecoveryMnemonic;
    // Defensive only — `OnboardingPhysicalRecovery` never dispatches this
    // without first observing `needsBitcoinBirthdaySelection`.
    if (pending == null) return;

    if (event.checkpoint == null) {
      // The user backed out of `WalletBirthdayPicker` (see its class doc)
      // without a resolved checkpoint — abort the recovery attempt with no
      // wallet created at all, never a partial (Bitcoin-only or
      // Liquid-only) pair. They land back on the mnemonic entry step and
      // can retry from there.
      emit(
        state.copyWith(
          needsBitcoinBirthdaySelection: false,
          pendingRecoveryMnemonic: null,
          step: OnboardingStep.recover,
        ),
      );
      return;
    }

    try {
      emit(
        state.copyWith(
          onboardingStepStatus: OnboardingStepStatus.loading,
          needsBitcoinBirthdaySelection: false,
          step: OnboardingStep.recover,
        ),
      );
      await _createDefaultWalletsUsecase.execute(
        mnemonicWords: pending.words,
        bitcoinBirthdayCheckpoint: event.checkpoint,
      );
      await _completePhysicalBackupVerificationUsecase.execute();
      emit(
        state.copyWith(
          onboardingStepStatus: OnboardingStepStatus.success,
          pendingRecoveryMnemonic: null,
        ),
      );
    } catch (e) {
      await _handleError(e, emit);
    }
  }
}
