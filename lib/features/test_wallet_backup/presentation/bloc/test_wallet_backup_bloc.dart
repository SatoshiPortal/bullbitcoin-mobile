import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/get_mnemonic_from_fingerprint_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/load_wallets_for_network_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'test_wallet_backup_bloc.freezed.dart';
part 'test_wallet_backup_event.dart';
part 'test_wallet_backup_state.dart';

class TestWalletBackupBloc
    extends Bloc<TestWalletBackupEvent, TestWalletBackupState> {
  TestWalletBackupBloc({
    required this._completePhysicalBackupVerificationUsecase,
    required this._loadWalletsForNetworkUsecase,
    required this._getMnemonicFromFingerprintUsecase,
  }) : super(const TestWalletBackupState()) {
    on<OnWordsSelected>(_onWordsSelected);
    on<VerifyPhysicalBackup>(_verifyPhysicalBackup);
    on<StartPhysicalBackupVerification>((event, emit) {});
    on<LoadWallets>(_onLoadWallets);
    on<LoadMnemonicForWallet>(_onLoadMnemonicForWallet);
    on<ClearError>((event, emit) => emit(state.copyWith(failure: null)));
  }

  final CompletePhysicalBackupVerificationUsecase
  _completePhysicalBackupVerificationUsecase;
  final LoadWalletsForNetworkUsecase _loadWalletsForNetworkUsecase;
  final GetMnemonicFromFingerprintUsecase _getMnemonicFromFingerprintUsecase;

  /// Handles word selection during backup verification
  /// Validates word order and updates test state
  Future<void> _onWordsSelected(
    OnWordsSelected event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    final mnemonic = state.mnemonic;
    final reorderedMnemonic = List<String>.from(
      state.reorderedMnemonic + [event.word],
    );

    final isCorrect = mnemonic
        .join(' ')
        .startsWith(reorderedMnemonic.join(' '));

    if (isCorrect) {
      emit(
        state.copyWith(
          reorderedMnemonic: [...state.reorderedMnemonic, event.word],
          failure: null,
          selectedMnemonicWords: [...state.selectedMnemonicWords, event.index],
        ),
      );
    } else {
      final shuffled = List<String>.from(mnemonic)..shuffle();
      emit(
        state.copyWith(
          shuffledMnemonic: shuffled,
          reorderedMnemonic: [],
          selectedMnemonicWords: [],
          failure: const TestWalletBackupIncorrectOrderFailure(),
        ),
      );
    }
  }

  Future<void> _verifyPhysicalBackup(
    VerifyPhysicalBackup event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    if (state.mnemonic.isEmpty) {
      emit(state.copyWith(failure: const TestWalletBackupNoMnemonicFailure()));
      return;
    }

    if (state.reorderedMnemonic.length != state.mnemonic.length) {
      emit(
        state.copyWith(
          failure: const TestWalletBackupIncompleteMnemonicFailure(),
        ),
      );
      return;
    }

    final isCorrect =
        state.mnemonic.join(' ') == state.reorderedMnemonic.join(' ');

    if (isCorrect) {
      final selectedWallet = state.selectedWallet;
      if (selectedWallet == null) {
        emit(
          state.copyWith(
            failure: const TestWalletBackupUnexpectedFailure(
              'No wallet selected for physical backup verification',
            ),
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          isVerificationSaving: true,
          isVerificationComplete: false,
        ),
      );
      final result = await _completePhysicalBackupVerificationUsecase.execute(
        masterFingerprint: selectedWallet.masterFingerprint,
      );
      if (result case Err(:final failure)) {
        emit(
          state.copyWith(
            failure: failure,
            isVerificationSaving: false,
            isVerificationComplete: false,
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          isVerificationSaving: false,
          isVerificationComplete: true,
        ),
      );
    } else {
      final shuffled = state.mnemonic.toList()..shuffle();
      emit(
        state.copyWith(
          failure: const TestWalletBackupIncorrectOrderFailure(),
          shuffledMnemonic: shuffled,
          reorderedMnemonic: [],
          selectedMnemonicWords: [],
        ),
      );
    }
  }

  Future<void> _onLoadWallets(
    LoadWallets event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    emit(state.copyWith(selectedWallet: null));

    switch (await _loadWalletsForNetworkUsecase.execute()) {
      case Ok(:final value):
        final selected = value.firstWhere(
          (wallet) => wallet.isDefault,
          orElse: () => value.first,
        );
        emit(state.copyWith(wallets: value, selectedWallet: selected));
        add(LoadMnemonicForWallet(wallet: selected));
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }

  Future<void> _onLoadMnemonicForWallet(
    LoadMnemonicForWallet event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    emit(state.copyWith(selectedWallet: null));

    switch (await _getMnemonicFromFingerprintUsecase.execute(
      event.wallet.masterFingerprint,
    )) {
      case Ok(value: (final mnemonicWords, final passphrase)):
        emit(
          state.copyWith(
            selectedWallet: event.wallet,
            mnemonic: mnemonicWords,
            passphrase: passphrase ?? '',
            shuffledMnemonic: mnemonicWords.toList()..shuffle(),
            reorderedMnemonic: [],
            selectedMnemonicWords: [],
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }
}
