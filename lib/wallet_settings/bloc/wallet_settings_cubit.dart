import 'dart:io';

import 'package:bb_mobile/_model/bip329_label.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/wallet/labels.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/_ui/alert.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bb_mobile/wallet_settings/bloc/state.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

class WalletSettingsCubit extends Cubit<WalletSettingsState> {
  WalletSettingsCubit({
    required Wallet wallet,
    required WalletBloc walletBloc,
    required HomeCubit homeCubit,
    required WalletsStorageRepository walletsStorageRepository,
    required WalletSensitiveStorageRepository walletSensRepository,
    required FileStorage fileStorage,
  })  : _fileStorage = fileStorage,
        _walletSensRepository = walletSensRepository,
        _homeCubit = homeCubit,
        _walletsStorageRepository = walletsStorageRepository,
        _walletBloc = walletBloc,
        super(WalletSettingsState(wallet: wallet));

  final WalletBloc _walletBloc;
  final WalletsStorageRepository _walletsStorageRepository;
  final HomeCubit _homeCubit;
  final WalletSensitiveStorageRepository _walletSensRepository;
  final FileStorage _fileStorage;

  void changeName(String name) {
    emit(state.copyWith(name: name));
  }

  void saveNameClicked() async {
    emit(state.copyWith(savingName: true, errSavingName: ''));

    final wallet = state.wallet.copyWith(name: state.name);
    // final err = await walletsStorageRepository.updateWallet(
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
    _walletBloc
        .add(UpdateWallet(wallet, updateTypes: [UpdateWalletTypes.settings]));

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
    final (seed, err) = await _walletSensRepository.readSeed(
      fingerprintIndex: state.wallet.getRelatedSeedStorageString(),
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
        password: seed
            .getPassphraseFromIndex(state.wallet.sourceFingerprint)
            .passphrase,
        shuffledMnemonic: shuffled,
      ),
    );
  }

  void wordClicked(int shuffledIdx) {
    emit(state.copyWith(errTestingBackup: ''));
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
    emit(state.copyWith(errTestingBackup: ''));
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
    BBAlert.showErrorAlertPopUp(
      err: 'Invalid mnemonic order.',
      onClose: () {
        emit(state.copyWith(errTestingBackup: ''));
      },
    );
    await Future.delayed(const Duration(milliseconds: 500));
    final shuffled = state.mnemonic.toList()..shuffle();
    emit(
      state.copyWith(
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

  //   // final updateErr = await walletsStorageRepository.updateWallet(
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
    final (seed, err) = await _walletSensRepository.readSeed(
      fingerprintIndex: state.wallet.getRelatedSeedStorageString(),
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
    final psd = seed
            .getPassphraseFromIndex(state.wallet.sourceFingerprint)
            .passphrase ==
        password;
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

    final wallet = state.wallet
        .copyWith(backupTested: true, lastBackupTested: DateTime.now());

    // final updateErr = await walletsStorageRepository.updateWallet(
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

    _walletBloc
        .add(UpdateWallet(wallet, updateTypes: [UpdateWalletTypes.settings]));

    await Future.delayed(100.ms);

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
    final (seed, err) = await _walletSensRepository.readSeed(
      fingerprintIndex: state.wallet.getRelatedSeedStorageString(),
    );

    if (err != null) {
      emit(state.copyWith(savingFile: false, errSavingFile: err.toString()));
      return;
    }

    final wallet = seed!;

    final fingerprint = seed.mnemonicFingerprint;
    final folder = wallet.network == BBNetwork.Mainnet ? 'bitcoin' : 'testnet';

    final (appDocDir, errDir) = await _fileStorage.getDownloadDirectory();

    if (errDir == null) {
      emit(
        state.copyWith(
          savingFile: false,
          errSavingFile: errDir.toString(),
        ),
      );
      return;
    }
    final file =
        File(appDocDir! + '/bullbitcoin_backup/$folder/$fingerprint.json');

    final (_, errSave) = await _fileStorage.saveToFile(
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
    _walletBloc.add(KillSync());
    await Future.delayed(200.ms);
    final mnemonicFingerprint = state.wallet.getRelatedSeedStorageString();
    final sourceFingerprint = state.wallet.sourceFingerprint;
    final hasPassphrase = state.wallet.hasPassphrase();
    final err = await _walletsStorageRepository.deleteWallet(
      walletHashId: state.wallet.getWalletStorageString(),
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
    await Future.delayed(const Duration(seconds: 1));

    final appDocDir = await getApplicationDocumentsDirectory();
    final dbDir = appDocDir.path + '/' + state.wallet.getWalletStorageString();

    final errDeleting = await _fileStorage.deleteFile(dbDir);
    if (errDeleting != null) {
      emit(
        state.copyWith(
          deleting: false,
          errDeleting: errDeleting.toString(),
        ),
      );
      return;
    }

    if (hasPassphrase) {
      final errr = await _walletSensRepository.deletePassphrase(
        passphraseFingerprintIndex: sourceFingerprint,
        seedFingerprintIndex: mnemonicFingerprint,
      );
      if (errr != null) {
        emit(
          state.copyWith(
            deleting: false,
            errDeleting: errr.toString(),
          ),
        );
      }
    }

    final (wallets, wErrs) = await _walletsStorageRepository.readAllWallets();
    if (wErrs != null) {
      emit(
        state.copyWith(
          deleting: false,
          errDeleting: 'Could not read wallets from storage',
        ),
      );
    }

    final List<Wallet> networkSpecificWallets = (wallets != null)
        ? wallets
            .where((wallet) => wallet.network == state.wallet.network)
            .toList()
        : [];
    // check if a wallet exists for this seed, if it does we should not delete the seed
    final walletInUse = await WalletUpdate().walletExists(
      mnemonicFingerprint,
      networkSpecificWallets,
    );
    if (!walletInUse) {
      final errr = await _walletSensRepository.deleteSeed(
        fingerprint: state.wallet.getRelatedSeedStorageString(),
      );
      if (errr != null) {
        emit(
          state.copyWith(
            deleting: false,
            errDeleting: errr.toString(),
          ),
        );
      }
    }
    _homeCubit.removeWallet(_walletBloc);
    // homeCubit.removeWalletPostDelete(state.wallet.id);

    emit(
      state.copyWith(
        deleting: false,
        deleted: true,
      ),
    );
  }

  void exportLabelsClicked() async {
    try {
      emit(state.copyWith(exporting: true, errExporting: '', errImporting: ''));
      final key = state.wallet.generateBIP329Key();
      final fileName = state.wallet.id;
      final walletLabels = WalletLabels();
      final labelsToExport = await walletLabels.txsToBip329(
        state.wallet.transactions,
        state.wallet.originString(),
      )
        ..addAll(
          await walletLabels.addressesToBip329(
            state.wallet.myAddressBook,
            state.wallet.originString(),
          ),
        );
      final err = await Bip329LabelHelpers.encryptWrite(
        fileName,
        labelsToExport,
        key,
      );
      if (err != null) {
        emit(state.copyWith(errExporting: err.toString(), exporting: false));
        return;
      }
      emit(state.copyWith(exporting: false, exported: true));
      await Future.delayed(2.seconds);
      emit(state.copyWith(exported: false));
    } catch (e) {
      emit(state.copyWith(errExporting: e.toString(), exporting: false));
    }
  }

  void importLabelsClicked() async {
    try {
      emit(state.copyWith(importing: true, errImporting: '', errExporting: ''));
      final wallet = state.wallet;
      final key = wallet.generateBIP329Key();
      final fileName = wallet.id;
      final walletLabels = WalletLabels();
      final (importedLabels, iErr) = await Bip329LabelHelpers.decryptRead(
        fileName,
        key,
      );
      if (iErr != null) {
        emit(state.copyWith(errImporting: iErr.toString(), importing: false));
        return;
      }
      final importedTxs = walletLabels.txsFromBip329(importedLabels!);
      final importedAddresses =
          walletLabels.addressesFromBip329(importedLabels);
      final (updatedAddressWallet, err) =
          await WalletUpdate().updateAddressLabels(wallet, importedAddresses);
      if (err != null) {
        emit(state.copyWith(errImporting: err.toString(), importing: false));
        return;
      }
      final (updatedWallet, err2) = await WalletUpdate()
          .updateTransactionLabels(updatedAddressWallet!, importedTxs);
      if (err2 != null) {
        emit(state.copyWith(errImporting: err2.toString(), importing: false));
        return;
      }

      _walletBloc.add(
        UpdateWallet(
          updatedWallet!,
          updateTypes: [
            UpdateWalletTypes.addresses,
            UpdateWalletTypes.transactions,
          ],
        ),
      );

      emit(state.copyWith(importing: false, imported: true));
      await Future.delayed(2.seconds);
      emit(state.copyWith(imported: false));
    } catch (e) {
      emit(state.copyWith(errImporting: e.toString(), importing: false));
    }
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
