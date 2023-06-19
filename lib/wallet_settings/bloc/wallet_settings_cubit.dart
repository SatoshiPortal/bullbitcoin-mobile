import 'dart:io';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/storage.dart';
import 'package:bb_mobile/_pkg/wallet/delete.dart';
import 'package:bb_mobile/_pkg/wallet/read.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/wallet/bloc/wallet_cubit.dart';
import 'package:bb_mobile/wallet_settings/bloc/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

class WalletSettingsCubit extends Cubit<WalletSettingsState> {
  WalletSettingsCubit({
    required Wallet wallet,
    required this.walletCubit,
    required this.walletUpdate,
    required this.storage,
    required this.walletRead,
    required this.walletDelete,
  }) : super(
          WalletSettingsState(
            wallet: wallet,
            mnemonic: [
              // ...mn1,
              // for (var i = 0; i < 12; i++) '',
            ],
          ),
        );

  final WalletCubit walletCubit;
  final WalletUpdate walletUpdate;
  final IStorage storage;
  final WalletRead walletRead;
  final WalletDelete walletDelete;

  void changeName(String name) {
    emit(state.copyWith(name: name));
  }

  void saveNameClicked() async {
    emit(state.copyWith(savingName: true, errSavingName: ''));
    try {
      final wallet = state.wallet.copyWith(name: state.name);
      final err = await walletUpdate.updateWallet(
        wallet: wallet,
        storage: storage,
        walletRead: walletRead,
      );
      if (err != null) throw err;

      emit(
        state.copyWith(
          savingName: false,
          wallet: wallet,
          savedName: true,
        ),
      );
      walletCubit.updateWallet(wallet);
      await Future.delayed(const Duration(seconds: 1));
      emit(state.copyWith(savedName: false));
    } catch (e) {
      emit(
        state.copyWith(
          errSavingName: e.toString(),
          savingName: false,
        ),
      );
    }
  }

  void wordChanged(int index, String word) {
    final words = state.mnemonic.toList();
    words[index] = word;
    emit(
      state.copyWith(
        mnemonic: words,
        errTestingBackup: '',
      ),
    );
  }

  void loadBackupClicked() async {
    final (w, err) = await walletRead.getWalletDetails(
      saveDir: state.wallet.getStorageString(),
      storage: storage,
    );

    if (err != null) {
      emit(state.copyWith(errTestingBackup: err.toString()));
      return;
    }

    final words = w!.mnemonic.split(' ');
    final shuffled = words.toList()..shuffle();

    emit(
      state.copyWith(
        mnemonic: words,
        password: w.password ?? '',
        shuffledMnemonic: shuffled,
      ),
    );
  }

  void wordClicked(String word) {
    final order = state.testMnemonicOrder.toList();
    if (order.contains(word)) return;
    if (order.length == 12) return;

    final actualIdx = state.mnemonic.indexOf(word);
    if (actualIdx != order.length) {
      invalidTestOrderClicked();
      return;
    }

    order.add(word);
    emit(state.copyWith(testMnemonicOrder: order));

    if (order.length == 12) testingOrderCompleted();
  }

  void invalidTestOrderClicked() async {
    emit(
      state.copyWith(
        testMnemonicOrder: [],
        errTestingBackup: 'Invalid order',
      ),
    );
    await Future.delayed(const Duration(seconds: 2));
    final shuffled = state.mnemonic.toList()..shuffle();
    emit(
      state.copyWith(
        errTestingBackup: '',
        shuffledMnemonic: shuffled,
      ),
    );
  }

  void testingOrderCompleted() async {
    if (state.testMnemonicOrder != state.mnemonic) {
      return;
    }
    if (state.password != state.testBackupPassword) {
      return;
    }
    emit(state.copyWith(testingBackup: true, errTestingBackup: ''));

    final wallet = state.wallet.copyWith(backupTested: true);

    final updateErr = await walletUpdate.updateWallet(
      wallet: wallet,
      storage: storage,
      walletRead: walletRead,
    );
    if (updateErr != null) {
      emit(
        state.copyWith(
          errTestingBackup: updateErr.toString(),
          testingBackup: false,
        ),
      );
      return;
    }

    walletCubit.updateWallet(wallet);
    emit(
      state.copyWith(
        backupTested: true,
        testingBackup: false,
        wallet: wallet,
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

  void testBackupClicked() async {
    emit(state.copyWith(testingBackup: true, errTestingBackup: ''));
    try {
      final words = state.mnemonic.toList().join(' ');
      final password = state.testBackupPassword;
      final (w, err) = await walletRead.getWalletDetails(
        saveDir: state.wallet.getStorageString(),
        storage: storage,
      );

      if (err != null) throw err;

      final mne = w!.mnemonic == words;
      final psd = (w.password ?? '') == password;
      if (!mne) throw 'Mnemonic does not match';
      if (!psd) throw 'Passphase does not match';

      final wallet = state.wallet.copyWith(backupTested: true);

      final updateErr = await walletUpdate.updateWallet(
        wallet: wallet,
        storage: storage,
        walletRead: walletRead,
      );
      if (updateErr != null) throw updateErr;

      walletCubit.updateWallet(wallet);
      emit(
        state.copyWith(
          backupTested: true,
          testingBackup: false,
          wallet: wallet,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          errTestingBackup: e.toString(),
          testingBackup: false,
        ),
      );
    }
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
    try {
      emit(state.copyWith(savingFile: true, errSavingFile: ''));
      final (w, err) = await walletRead.getWalletDetails(
        saveDir: state.wallet.getStorageString(),
        storage: storage,
      );

      if (err != null) throw err;

      final wallet = w!;

      final fingerprint = wallet.cleanFingerprint();
      final folder = wallet.network == BBNetwork.Mainnet ? 'bitcoin' : 'testnet';

      final appDocDir = await getDownloadsDirectory();
      if (appDocDir == null) throw 'Could not get downloads directory';
      final file = File(appDocDir.path + '/bullbitcoin_backup/$folder/$fingerprint.json');

      await file.writeAsString(wallet.toJson().toString());

      emit(state.copyWith(savingFile: false, savedFile: true));
      await Future.delayed(const Duration(seconds: 4));
      emit(state.copyWith(savedFile: false));
    } catch (e) {
      emit(state.copyWith(savingFile: false, errSavingFile: e.toString()));
    }
  }

  void deleteWalletClicked() async {
    try {
      emit(state.copyWith(deleting: true, errDeleting: ''));
      // final fingerprint = state.wallet.fingerprint;
      // final bdkWallet = walletCubit.state.bdkWallet;
      // if (bdkWallet == null) throw 'Wallet not loaded';

      final err = await walletDelete.deleteWallet(
        saveDir: state.wallet.getStorageString(),
        storage: storage,
      );

      if (err != null) throw err;

      // final fingerPrint = fingerPrintFromDescr(edesc, isTesnet: isTesnet);
      final appDocDir = await getApplicationDocumentsDirectory();
      final dbDir = appDocDir.path + '/' + state.wallet.getStorageString();
      final dbFile = File(dbDir);
      if (dbFile.existsSync()) {
        await dbFile.delete(recursive: true);
      }

      emit(
        state.copyWith(
          deleting: false,
          deleted: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          deleting: false,
          errDeleting: e.toString(),
        ),
      );
    }
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
  'earn'
];

// arrive term same weird genuine year trash autumn fancy need olive earn
// arrive term same weird genuine year trash autumn fancy need olive earn
