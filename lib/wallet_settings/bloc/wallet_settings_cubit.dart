import 'dart:io';

import 'package:bb_mobile/_model/bip329_label.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/wallet/labels.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/_repository/app_wallets_repository.dart';
import 'package:bb_mobile/_repository/wallet/sensitive_wallet_storage.dart';
import 'package:bb_mobile/_repository/wallet/wallet_storage.dart';
import 'package:bb_mobile/_repository/wallet_service.dart';
import 'package:bb_mobile/_ui/alert.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/wallet_settings/bloc/state.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

WalletSettingsCubit createWalletSettingsCubit(
  String wallet,
) {
  final w = locator<AppWalletsRepository>().getWalletById(wallet);
  return WalletSettingsCubit(
    wallet: w!,
    appWalletsRepository: locator<AppWalletsRepository>(),
    walletsStorageRepository: locator<WalletsStorageRepository>(),
    walletSensRepository: locator<WalletSensitiveStorageRepository>(),
    fileStorage: locator<FileStorage>(),
  );
}

class WalletSettingsCubit extends Cubit<WalletSettingsState> {
  WalletSettingsCubit({
    required Wallet wallet,
    required AppWalletsRepository appWalletsRepository,
    required WalletsStorageRepository walletsStorageRepository,
    required WalletSensitiveStorageRepository walletSensRepository,
    required FileStorage fileStorage,
  })  : _fileStorage = fileStorage,
        _walletSensRepository = walletSensRepository,
        _walletsStorageRepository = walletsStorageRepository,
        _appWalletsRepository = appWalletsRepository,
        _wallet = wallet,
        super(
          const WalletSettingsState(),
        );

  final WalletsStorageRepository _walletsStorageRepository;

  final WalletSensitiveStorageRepository _walletSensRepository;
  final FileStorage _fileStorage;
  final AppWalletsRepository _appWalletsRepository;

  final Wallet _wallet;

  void changeName(String name) {
    emit(state.copyWith(name: name));
  }

  Future<void> saveNameClicked() async {
    emit(state.copyWith(savingName: true, errSavingName: ''));

    final wallet = _wallet.copyWith(name: state.name);

    await _appWalletsRepository
        .getWalletServiceById(wallet.id)
        ?.updateWallet(wallet, updateTypes: [UpdateWalletTypes.settings]);

    emit(
      state.copyWith(
        savingName: false,
        savedName: true,
      ),
    );

    await Future.delayed(const Duration(seconds: 4));

    emit(state.copyWith(savedName: false));
  }

  Future<void> loadBackupClicked() async {
    final (seed, err) = await _walletSensRepository.readSeed(
      fingerprintIndex: _wallet.getRelatedSeedStorageString(),
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
        password:
            seed.getPassphraseFromIndex(_wallet.sourceFingerprint).passphrase,
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
  }

  Future<void> invalidTestOrderClicked() async {
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

  void changePassword(String password) {
    emit(
      state.copyWith(
        testBackupPassword: password,
        errTestingBackup: '',
      ),
    );
  }

  Future<void> testBackupClicked() async {
    emit(state.copyWith(testingBackup: true, errTestingBackup: ''));
    final words = state.testMneString();
    final password = state.testBackupPassword;
    final (seed, err) = await _walletSensRepository.readSeed(
      fingerprintIndex: _wallet.getRelatedSeedStorageString(),
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

    final psd =
        seed.getPassphraseFromIndex(_wallet.sourceFingerprint).passphrase ==
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

    final wallet =
        _wallet.copyWith(backupTested: true, lastBackupTested: DateTime.now());

    await _appWalletsRepository
        .getWalletServiceById(wallet.id)
        ?.updateWallet(wallet, updateTypes: [UpdateWalletTypes.settings]);

    emit(
      state.copyWith(
        backupTested: true,
        testingBackup: false,
      ),
    );
    clearSensitive();
  }

  Future<void> resetBackupTested() async {
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

  Future<void> backupToSD() async {
    emit(state.copyWith(savingFile: true, errSavingFile: ''));
    final (seed, err) = await _walletSensRepository.readSeed(
      fingerprintIndex: _wallet.getRelatedSeedStorageString(),
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
        File('${appDocDir!}/bullbitcoin_backup/$folder/$fingerprint.json');

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

  Future<void> deleteWalletClicked() async {
    emit(state.copyWith(deleting: true, errDeleting: ''));
    final walletService =
        _appWalletsRepository.getWalletServiceById(_wallet.id);

    walletService?.killSync();

    if (walletService!.wallet.type == BBWalletType.main) {
      emit(
        state.copyWith(
          deleting: false,
          errDeleting: 'Instant or Secure wallets cannot be deleted.',
        ),
      );
      return;
    }
    final mnemonicFingerprint = _wallet.getRelatedSeedStorageString();
    final sourceFingerprint = _wallet.sourceFingerprint;
    final hasPassphrase = _wallet.hasPassphrase();
    final err = await _walletsStorageRepository.deleteWallet(
      walletHashId: _wallet.getWalletStorageString(),
    );

    if (err != null) {
      emit(
        state.copyWith(
          deleting: false,
          deleted: false,
          errDeleting: err.toString(),
        ),
      );
      return;
    }
    await Future.delayed(const Duration(seconds: 1));

    final appDocDir = await getApplicationDocumentsDirectory();
    final dbDir = '${appDocDir.path}/${_wallet.getWalletStorageString()}';

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
        ? wallets.where((wallet) => wallet.network == _wallet.network).toList()
        : [];

    final walletInUse = await WalletUpdate().walletExists(
      mnemonicFingerprint,
      networkSpecificWallets,
    );
    if (!walletInUse) {
      final errr = await _walletSensRepository.deleteSeed(
        fingerprint: _wallet.getRelatedSeedStorageString(),
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
    _appWalletsRepository.deleteWallet(_wallet.id);

    emit(
      state.copyWith(
        deleting: false,
        deleted: true,
      ),
    );
  }

  Future<void> exportLabelsClicked() async {
    try {
      emit(state.copyWith(exporting: true, errExporting: '', errImporting: ''));
      final key = _wallet.generateBIP329Key();
      final fileName = _wallet.id;
      final walletLabels = WalletLabels();
      final labelsToExport = await walletLabels.txsToBip329(
        _wallet.transactions,
        _wallet.originString(),
      )
        ..addAll(
          await walletLabels.addressesToBip329(
            _wallet.myAddressBook,
            _wallet.originString(),
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

  Future<void> importLabelsClicked() async {
    try {
      emit(state.copyWith(importing: true, errImporting: '', errExporting: ''));
      final wallet = _wallet;
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

      await _appWalletsRepository
          .getWalletServiceById(updatedWallet!.id)
          ?.updateWallet(
        updatedWallet,
        updateTypes: [
          UpdateWalletTypes.addresses,
          UpdateWalletTypes.transactions,
        ],
      );

      emit(state.copyWith(importing: false, imported: true));
      await Future.delayed(2.seconds);
      emit(state.copyWith(imported: false));
    } catch (e) {
      emit(state.copyWith(errImporting: e.toString(), importing: false));
    }
  }

  Future<void> addNewBIP85BackupKey(String label) async {
    try {
      emit(state.copyWith(savingFile: true, errSavingFile: ''));
      final wallet = _wallet;
      final newBIP85Path = wallet.generateNextBIP85Path();

      //TODO; find a way to get the label from the wallet
      final updatedWallet = WalletUpdate().updateBIP85Paths(
        wallet,
        newBIP85Path,
        "${label}_bip85Path_${wallet.bip85Derivations.entries.length + 1}",
      );

      await _appWalletsRepository
          .getWalletServiceById(updatedWallet.id)
          ?.updateWallet(
        updatedWallet,
        updateTypes: [
          UpdateWalletTypes.bip85Paths,
        ],
      );

      emit(state.copyWith(savingFile: false, savedFile: true));
      await Future.delayed(2.seconds);
      emit(state.copyWith(savedFile: false));
    } catch (e) {
      emit(state.copyWith(errImporting: e.toString(), importing: false));
    }
  }

  Future clearSensitive() async {
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
