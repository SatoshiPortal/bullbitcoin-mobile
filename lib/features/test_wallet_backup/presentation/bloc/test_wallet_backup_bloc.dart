import 'dart:async';

import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
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
    required CompletePhysicalBackupVerificationUsecase
    completePhysicalBackupVerificationUsecase,
    required LoadWalletsForNetworkUsecase loadWalletsForNetworkUsecase,
    required GetMnemonicFromFingerprintUsecase
    getMnemonicFromFingerprintUsecase,
  }) : _completePhysicalBackupVerificationUsecase =
           completePhysicalBackupVerificationUsecase,
       _loadWalletsForNetworkUsecase = loadWalletsForNetworkUsecase,
       _getMnemonicFromFingerprintUsecase = getMnemonicFromFingerprintUsecase,
       super(const TestWalletBackupState()) {
    on<OnWordsSelected>(_onWordsSelected);
    on<VerifyPhysicalBackup>(_verifyPhysicalBackup);
    on<StartPhysicalBackupVerification>((event, emit) {});
    on<LoadWallets>(_onLoadWallets);
    on<LoadMnemonicForWallet>(_onLoadMnemonicForWallet);
    on<ClearError>((event, emit) => emit(state.copyWith(statusError: '')));
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
          statusError: '',
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
          statusError: 'Incorrect word order. Please try again.',
        ),
      );
    }
  }

  Future<void> _verifyPhysicalBackup(
    VerifyPhysicalBackup event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    try {
      if (state.mnemonic.isEmpty) {
        emit(state.copyWith(statusError: 'No mnemonic loaded'));
        return;
      }

      if (state.reorderedMnemonic.length != state.mnemonic.length) {
        emit(state.copyWith(statusError: 'Please select all words'));
        return;
      }

      // Compare with original mnemonic
      final isCorrect =
          state.mnemonic.join(' ') == state.reorderedMnemonic.join(' ');

      if (isCorrect) {
        await _completePhysicalBackupVerificationUsecase.execute();
      } else {
        // Reset test state when wrong
        final shuffled = state.mnemonic.toList()..shuffle();
        emit(
          state.copyWith(
            statusError: 'Incorrect word order. Please try again.',
            shuffledMnemonic: shuffled,
            reorderedMnemonic: [],
            selectedMnemonicWords: [],
          ),
        );
      }
    } catch (e) {
      emit(state.copyWith(statusError: 'Verification failed: $e'));
    }
  }

  Future<void> _onLoadWallets(
    LoadWallets event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    try {
      emit(state.copyWith(selectedWallet: null));

      final wallets = await _loadWalletsForNetworkUsecase.execute();
      if (wallets.isEmpty) throw Exception('No wallets found');
      final Wallet selected = wallets.firstWhere(
        (w) => w.isDefault,
        orElse: () => wallets.first,
      );
      emit(state.copyWith(wallets: wallets, selectedWallet: selected));

      add(LoadMnemonicForWallet(wallet: selected));
    } catch (e) {
      emit(state.copyWith(statusError: 'Failed to load wallets: $e'));
    }
  }

  Future<void> _onLoadMnemonicForWallet(
    LoadMnemonicForWallet event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    try {
      emit(state.copyWith(selectedWallet: null));

      final wallet = event.wallet;
      final (
        mnemonicWords,
        passphrase,
      ) = await _getMnemonicFromFingerprintUsecase.execute(
        wallet.masterFingerprint,
      );

      emit(
        state.copyWith(
          selectedWallet: wallet,
          mnemonic: mnemonicWords,
          passphrase: passphrase ?? '',
          shuffledMnemonic: mnemonicWords.toList()..shuffle(),
          reorderedMnemonic: [],
          selectedMnemonicWords: [],
        ),
      );
    } catch (e) {
      emit(state.copyWith(statusError: 'Failed to load mnemonic: $e'));
    }
  }
}
