import 'dart:io';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sync.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bb_mobile/wallet_settings/bloc/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WalletSettingsCubit extends Cubit<WalletSettingsState> {
  WalletSettingsCubit({
    required Wallet wallet,
    required this.walletBloc,
    required this.homeCubit,
    required this.hiveStorage,
    required this.walletRead,
    required this.walletRepository,
    required this.walletSensRepository,
    required this.fileStorage,
    required this.secureStorage,
  }) : super(
          WalletSettingsState(
            wallet: wallet,
          ),
        );

  final WalletBloc walletBloc;
  final HiveStorage hiveStorage;
  final SecureStorage secureStorage;
  final WalletSync walletRead;
  final WalletRepository walletRepository;
  final HomeCubit homeCubit;
  final WalletSensitiveRepository walletSensRepository;

  final FileStorage fileStorage;

  void changeName(String name) {
    emit(state.copyWith(name: name));
  }

  void saveNameClicked() async {
    emit(state.copyWith(savingName: true, errSavingName: ''));

    final wallet = state.wallet.copyWith(name: state.name);
    // final err = await walletRepository.updateWallet(
    //   wallet: wallet,
    //   hiveStore: hiveStorage,
    // );
    // if (err != null) {
    //   emit(
    //     state.copyWith(
    //       errSavingName: err.toString(),
    //       savingName: false,
    //     ),
    //   );
    //   return;
    // }
    walletBloc.add(UpdateWallet(wallet, updateTypes: [UpdateWalletTypes.settings]));

    emit(
      state.copyWith(
        savingName: false,
        wallet: wallet,
        savedName: true,
      ),
    );

    await Future.delayed(const Duration(seconds: 4));

    emit(state.copyWith(savedName: false));
  }

  // void wordChanged(int index, String word) {
  //   final words = state.mnemonic.toList();
  //   words[index] = word;
  //   emit(
  //     state.copyWith(
  //       mnemonic: words,
  //       errTestingBackup: '',
  //     ),
  //   );
  // }

  void loadBackupClicked() async {
    final (seed, err) = await walletSensRepository.readSeed(
      fingerprintIndex: state.wallet.getRelatedSeedStorageString(),
      secureStore: secureStorage,
    );
    if (err != null) {
      emit(state.copyWith(errTestingBackup: err.toString()));
      return;
    }

    final words = seed!.mnemonic.split(' ');
    final shuffled = words.toList()..shuffle();

    emit(
      state.copyWith(
        testMnemonicOrder: [],
        mnemonic: words,
        errTestingBackup: '',
        password: seed.getPassphraseFromIndex(state.wallet.sourceFingerprint).passphrase,
        shuffledMnemonic: shuffled,
      ),
    );
  }

  void wordClicked(int shuffledIdx) {
    final testMnemonic = state.testMnemonicOrder.toList();
    if (testMnemonic.length == 12) return;

    final (word, isSelected, actualIdx) = state.shuffleElementAt(shuffledIdx);
    if (isSelected) return;
    if (actualIdx != testMnemonic.length) {
      invalidTestOrderClicked();
      return;
    }

    testMnemonic.add(
      (
        word: word,
        shuffleIdx: shuffledIdx,
        selectedActualIdx: actualIdx,
      ),
    );

    emit(state.copyWith(testMnemonicOrder: testMnemonic));

    // if (testMnemonic.length == 12) testBackupClicked();
  }

  void word24Clicked(int shuffledIdx) {
    final testMnemonic = state.testMnemonicOrder.toList();
    if (testMnemonic.length == 24) return;

    final (word, isSelected, actualIdx) = state.shuffleElementAt(shuffledIdx);
    if (isSelected) return;
    if (actualIdx != testMnemonic.length) {
      invalidTestOrderClicked();
      return;
    }

    testMnemonic.add(
      (
        word: word,
        shuffleIdx: shuffledIdx,
        selectedActualIdx: actualIdx,
      ),
    );

    emit(state.copyWith(testMnemonicOrder: testMnemonic));

    // if (testMnemonic.length == 24) testBackupClicked();
  }

  void invalidTestOrderClicked() async {
    emit(
      state.copyWith(
        testMnemonicOrder: [],
        errTestingBackup: 'Invalid order',
      ),
    );
    await Future.delayed(const Duration(milliseconds: 500));
    final shuffled = state.mnemonic.toList()..shuffle();
    emit(
      state.copyWith(
        errTestingBackup: '',
        shuffledMnemonic: shuffled,
      ),
    );
  }

  // void testingOrderCompleted() async {
  //   final words = state.testMneString();
  //   final mne = state.mnemonic.join(' ');
  //   if (words != mne) {
  //     return;
  //   }
  //   if (state.password != state.testBackupPassword) {
  //     return;
  //   }
  //   emit(state.copyWith(testingBackup: true, errTestingBackup: ''));

  //   final wallet = state.wallet.copyWith(backupTested: true);

  //   // final updateErr = await walletRepository.updateWallet(
  //   //   wallet: wallet,
  //   //   hiveStore: hiveStorage,
  //   // );
  //   // if (updateErr != null) {
  //   //   emit(
  //   //     state.copyWith(
  //   //       errTestingBackup: updateErr.toString(),
  //   //       testingBackup: false,
  //   //     ),
  //   //   );
  //   //   return;
  //   // }

  //   walletBloc.add(UpdateWallet(wallet, updateTypes: [UpdateWalletTypes.settings]));

  //   emit(
  //     state.copyWith(
  //       backupTested: true,
  //       testingBackup: false,
  //       wallet: wallet,
  //     ),
  //   );
  //   clearSensitive();
  // }

  void changePassword(String password) {
    emit(
      state.copyWith(
        testBackupPassword: password,
        errTestingBackup: '',
      ),
    );
  }

  void testBackupClicked() async {
    emit(state.copyWith(testingBackup: true, errTestingBackup: ''));
    final words = state.testMneString();
    final password = state.testBackupPassword;
    final (seed, err) = await walletSensRepository.readSeed(
      fingerprintIndex: state.wallet.getRelatedSeedStorageString(),
      secureStore: secureStorage,
    );

    if (err != null) {
      emit(
        state.copyWith(
          errTestingBackup: err.toString(),
          testingBackup: false,
        ),
      );
      return;
    }

    final mne = seed!.mnemonic == words;
    // final pp = seed.getPassphraseFromIndex(state.wallet.sourceFingerprint).passphrase;
    final psd = seed.getPassphraseFromIndex(state.wallet.sourceFingerprint).passphrase == password;
    if (!mne) {
      {
        emit(
          state.copyWith(
            errTestingBackup: 'Your seed words are incorrect',
            testingBackup: false,
          ),
        );
        return;
      }
    }
    if (!psd) {
      emit(
        state.copyWith(
          errTestingBackup: 'Your passphrase is incorrect',
          testingBackup: false,
        ),
      );
      return;
    }

    final wallet = state.wallet.copyWith(backupTested: true, lastBackupTested: DateTime.now());

    // final updateErr = await walletRepository.updateWallet(
    //   wallet: wallet,
    //   hiveStore: hiveStorage,
    // );

    // if (updateErr != null) {
    //   emit(
    //     state.copyWith(
    //       errTestingBackup: updateErr.toString(),
    //       testingBackup: false,
    //     ),
    //   );
    //   return;
    // }

    walletBloc.add(UpdateWallet(wallet, updateTypes: [UpdateWalletTypes.settings]));

    emit(
      state.copyWith(
        backupTested: true,
        testingBackup: false,
        wallet: wallet,
      ),
    );
    clearSensitive();
  }

  void resetBackupTested() async {
    await Future.delayed(const Duration(milliseconds: 800));
    emit(state.copyWith(backupTested: false));
  }

  void clearnMnemonic() {
    emit(
      state.copyWith(
        mnemonic: [
          for (var i = 0; i < 12; i++) '',
        ],
        testBackupPassword: '',
      ),
    );
  }

  void backupToSD() async {
    emit(state.copyWith(savingFile: true, errSavingFile: ''));
    final (seed, err) = await walletSensRepository.readSeed(
      fingerprintIndex: state.wallet.getRelatedSeedStorageString(),
      secureStore: secureStorage,
    );

    if (err != null) {
      emit(state.copyWith(savingFile: false, errSavingFile: err.toString()));
      return;
    }

    final wallet = seed!;

    final fingerprint = seed.mnemonicFingerprint;
    final folder = wallet.network == BBNetwork.Mainnet ? 'bitcoin' : 'testnet';

    final (appDocDir, errDir) = await fileStorage.getDownloadDirectory();

    if (errDir == null) {
      emit(
        state.copyWith(
          savingFile: false,
          errSavingFile: errDir.toString(),
        ),
      );
      return;
    }
    final file = File(appDocDir! + '/bullbitcoin_backup/$folder/$fingerprint.json');

    final (_, errSave) = await fileStorage.saveToFile(
      file,
      wallet.toJson().toString(),
    );
    if (errSave != null) {
      emit(
        state.copyWith(
          savingFile: false,
          errSavingFile: errSave.toString(),
        ),
      );
      return;
    }

    emit(state.copyWith(savingFile: false, savedFile: true));
    await Future.delayed(const Duration(seconds: 4));
    emit(state.copyWith(savedFile: false));
  }

  void deleteWalletClicked() async {
    emit(state.copyWith(deleting: true, errDeleting: ''));
    final mnemonicFingerprint = state.wallet.getRelatedSeedStorageString();
    final sourceFingerprint = state.wallet.sourceFingerprint;
    final hasPassphrase = state.wallet.hasPassphrase();
    final err = await walletRepository.deleteWallet(
      walletHashId: state.wallet.getWalletStorageString(),
      storage: hiveStorage,
    );

    if (err != null) {
      emit(
        state.copyWith(
          deleting: false,
          errDeleting: err.toString(),
        ),
      );
      return;
    }

    final (appDocDir, errDir) = await fileStorage.getAppDirectory();
    if (errDir != null) {
      emit(
        state.copyWith(
          deleting: false,
          errDeleting: errDir.toString(),
        ),
      );
      return;
    }
    final dbDir = appDocDir! + '/' + state.wallet.getWalletStorageString();
    final errDeleting = await fileStorage.deleteFile(dbDir);
    if (errDeleting != null) {
      emit(
        state.copyWith(
          deleting: false,
          errDeleting: errDeleting.toString(),
        ),
      );
      return;
    }

    homeCubit.removeWalletPostDelete(state.wallet.id);

    if (hasPassphrase) {
      final errr = await walletSensRepository.deletePassphrase(
        passphraseFingerprintIndex: sourceFingerprint,
        seedFingerprintIndex: mnemonicFingerprint,
        secureStore: secureStorage,
      );
      if (errr != null) {
        emit(
          state.copyWith(
            deleting: false,
            errDeleting: errr.toString(),
          ),
        );
        return;
      }
    }
    final (wallets, wErrs) = await walletRepository.readAllWallets(
      hiveStore: hiveStorage,
    );
    if (wErrs != null) {
      emit(
        state.copyWith(
          deleting: false,
          errDeleting: 'Could not read wallets from storage',
        ),
      );
      return;
    }

    final exists = await WalletUpdate().walletExists(mnemonicFingerprint, wallets!);
    if (!exists) {
      final errr = await walletSensRepository.deleteSeed(
        fingerprint: state.wallet.getRelatedSeedStorageString(),
        storage: secureStorage,
      );
      if (errr != null) {
        emit(
          state.copyWith(
            deleting: false,
            errDeleting: errr.toString(),
          ),
        );
        return;
      }
    }

    emit(
      state.copyWith(
        deleting: false,
        deleted: true,
      ),
    );
  }

  void clearSensitive() {
    clearnMnemonic();
    emit(
      state.copyWith(
        password: '',
        shuffledMnemonic: [],
        testMnemonicOrder: [],
      ),
    );
  }
}

const mn1 = [
  'arrive',
  'term',
  'same',
  'weird',
  'genuine',
  'year',
  'trash',
  'autumn',
  'fancy',
  'need',
  'olive',
  'earn',
];

// arrive term same weird genuine year trash autumn fancy need olive earn
// arrive term same weird genuine year trash autumn fancy need olive earn
