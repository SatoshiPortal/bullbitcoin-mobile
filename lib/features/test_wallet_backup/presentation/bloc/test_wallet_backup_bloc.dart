import 'dart:async';

import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/vault_provider.dart';
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
    on<StartPhysicalBackupVerification>((event, emit) {
      emit(state.copyWith(status: TestWalletBackupStatus.verifying));
    });
    on<LoadWallets>(_onLoadWallets);
    on<LoadMnemonicForWallet>(_onLoadMnemonicForWallet);
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
    final testMnemonic = state.testMnemonicOrder.toList();
    if (testMnemonic.length == 12) return;

    final (word, isSelected, actualIdx) = state.shuffleElementAt(
      event.shuffledIdx,
    );
    if (isSelected) return;
    if (actualIdx != testMnemonic.length) {
      await Future.delayed(const Duration(milliseconds: 300));
      final shuffled = state.mnemonic.toList()..shuffle();
      emit(
        state.copyWith(
          shuffledMnemonic: shuffled,
          testMnemonicOrder: [], // Reset selection when order is wrong
        ),
      );
      return;
    }

    // Add the selected word to testMnemonicOrder
    testMnemonic.add((
      word: word,
      shuffleIdx: event.shuffledIdx,
      selectedActualIdx: actualIdx,
    ));

    // Emit new state with updated testMnemonicOrder
    emit(state.copyWith(testMnemonicOrder: testMnemonic, statusError: ''));
  }

  Future<void> _verifyPhysicalBackup(
    VerifyPhysicalBackup event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    try {
      if (state.mnemonic.isEmpty) {
        emit(
          state.copyWith(
            status: TestWalletBackupStatus.error,
            statusError: 'No mnemonic loaded',
          ),
        );
        return;
      }

      if (state.testMnemonicOrder.length != state.mnemonic.length) {
        emit(
          state.copyWith(
            status: TestWalletBackupStatus.error,
            statusError: 'Please select all words',
          ),
        );
        return;
      }

      // Get the words in order from testMnemonicOrder
      final submittedWords =
          state.testMnemonicOrder.map((e) => e.word).toList();

      // Compare with original mnemonic
      final isCorrect = List.generate(
        state.mnemonic.length,
        (i) => state.mnemonic[i] == submittedWords[i],
      ).every((matched) => matched);

      if (isCorrect) {
        await _completePhysicalBackupVerificationUsecase.execute();
        emit(state.copyWith(status: TestWalletBackupStatus.success));
      } else {
        // Reset test state when wrong
        final shuffled = state.mnemonic.toList()..shuffle();
        emit(
          state.copyWith(
            status: TestWalletBackupStatus.error,
            statusError: 'Incorrect word order. Please try again.',
            shuffledMnemonic: shuffled,
            testMnemonicOrder: [],
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: TestWalletBackupStatus.error,
          statusError: 'Verification failed: $e',
        ),
      );
    }
  }

  Future<void> _onLoadWallets(
    LoadWallets event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    emit(state.copyWith(status: TestWalletBackupStatus.loading));
    try {
      final wallets = await _loadWalletsForNetworkUsecase.execute();
      if (wallets.isEmpty) throw Exception('No wallets found');
      final Wallet selected = wallets.firstWhere(
        (w) => w.isDefault,
        orElse: () => wallets.first,
      );
      emit(state.copyWith(wallets: wallets, selectedWallet: selected));

      // Small delay to allow smooth UI transition before loading mnemonic
      Future.delayed(const Duration(milliseconds: 500), () {
        add(LoadMnemonicForWallet(wallet: selected));
      });
    } catch (e) {
      emit(
        state.copyWith(
          status: TestWalletBackupStatus.error,
          statusError: 'Failed to load wallets: $e',
        ),
      );
    }
  }

  Future<void> _onLoadMnemonicForWallet(
    LoadMnemonicForWallet event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    try {
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
          testMnemonicOrder: [],
          status: TestWalletBackupStatus.success,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: TestWalletBackupStatus.error,
          statusError: 'Failed to load mnemonic: $e',
        ),
      );
    }
  }
}
