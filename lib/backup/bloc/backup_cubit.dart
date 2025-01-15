import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/_model/backup.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/wallet/labels.dart';
import 'package:bb_mobile/_repository/wallet/sensitive_wallet_storage.dart';
import 'package:bb_mobile/backup/bloc/backup_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hex/hex.dart';
import 'package:recoverbull_dart/recoverbull_dart.dart';

class BackupCubit extends Cubit<BackupState> {
  BackupCubit({
    required this.wallets,
    required this.walletSensitiveStorage,
    required this.fileStorage,
  }) : super(const BackupState());

  final FileStorage fileStorage;
  final List<Wallet> wallets;
  final WalletSensitiveStorageRepository walletSensitiveStorage;

  Future<void> loadBackupData() async {
    emit(state.copyWith(loading: true, error: ''));
    final backups = <Backup>[];
    final confirmedBackups = state.confirmedBackups;

    for (final wallet in wallets) {
      var backup = Backup(
        name: wallet.name ?? '',
        network: wallet.network.name.toLowerCase(),
        layer: wallet.baseWalletType.name.toLowerCase(),
        script: wallet.scriptType.name.toLowerCase(),
        type: wallet.type.name.toLowerCase(),
        mnemonicFingerPrint: wallet.mnemonicFingerprint,
      );

      final seedStorageString = wallet.getRelatedSeedStorageString();

      if (confirmedBackups["mnemonic"] == true &&
          confirmedBackups["passphrase"] == true) {
        final (seed, error) = await walletSensitiveStorage.readSeed(
          fingerprintIndex: seedStorageString,
        );
        if (error != null) {
          emit(state.copyWith(error: 'Error reading seed: ${error.message}'));
          return;
        }
        if (seed == null) {
          emit(state.copyWith(error: 'Seed data is missing.'));
          return;
        }

        final mnemonic = seed.mnemonic.split(' ');

        final passphrase = wallet.hasPassphrase()
            ? seed.passphrases
                .firstWhere(
                  (e) => e.sourceFingerprint == wallet.sourceFingerprint,
                )
                .passphrase
            : '';
        backup = backup.copyWith(mnemonic: mnemonic, passphrase: passphrase);
      }
      // why backup the descriptors since in _recoverBackup() calling [oneFromBIP39] to generate the descriptors again
      if (confirmedBackups["descriptors"] == true) {
        final descriptors = [wallet.getDescriptorCombined()];
        backup = backup.copyWith(descriptors: descriptors);
      }

      if (confirmedBackups["labels"] == true) {
        final walletLabels = WalletLabels();
        final labels = await walletLabels.txsToBip329(
          wallet.transactions,
          wallet.originString(),
        )
          ..addAll(
            await walletLabels.addressesToBip329(
              wallet.myAddressBook,
              wallet.originString(),
            ),
          );
        backup = backup.copyWith(labels: labels);
      }
      backups.add(backup);
    }

    emit(state.copyWith(loadedBackups: backups, loading: false));
  }

  Future<void> loadConfirmedBackups() async {
    const confirmedBackups = <String, bool>{
      "mnemonic": true,
      "passphrase": true,
      "descriptors": true,
      "labels": true,
      "script": true,
    };
    emit(state.copyWith(confirmedBackups: confirmedBackups, loading: false));
  }

  void toggleDescriptors() {
    _toggleBackupOption("descriptors");
  }

  void toggleLabels() {
    _toggleBackupOption("labels");
  }

  void _toggleBackupOption(String option) {
    final confirmedBackups = Map<String, bool>.from(state.confirmedBackups);
    final confirmed = confirmedBackups[option] ?? false;
    confirmedBackups[option] = !confirmed;
    emit(state.copyWith(confirmedBackups: confirmedBackups));
  }

  void toggleAllMnemonicAndPassphrase() {
    final confirmedBackups = Map<String, bool>.from(state.confirmedBackups);
    final areBothConfirmed = confirmedBackups["mnemonic"] == true &&
        confirmedBackups["passphrase"] == true;
    final newConfirmed = !areBothConfirmed;
    confirmedBackups["mnemonic"] = newConfirmed;
    confirmedBackups["passphrase"] = newConfirmed;
    emit(state.copyWith(confirmedBackups: confirmedBackups));
  }

  Future<void> writeEncryptedBackup() async {
    emit(state.copyWith(loading: true, error: ''));
    await loadBackupData();
    final backups = state.loadedBackups;
    if (backups.isEmpty) {
      emit(state.copyWith(error: 'No backup data available.'));
      return;
    }
    final firstMnemonic = backups.first.mnemonic.join(' ');

    try {
      final plaintext = json.encode(backups.map((i) => i.toJson()).toList());
      const String derivationPath = "m/1608'/0'";
      final (backupKey, encrypted) = await BackupService.createBackupWithBIP85(
        plaintext: plaintext,
        mnemonic: firstMnemonic,
        derivationPath: derivationPath,
      );
      final backupId = jsonDecode(encrypted)["backupId"] as String;
      final formattedDate = jsonDecode(encrypted)["createdAt"];
      final filename = '${formattedDate}_$backupId.json';
      final (appDir, errDir) = await fileStorage.getAppDirectory();
      if (errDir != null) {
        emit(state.copyWith(error: 'Failed to get application directory.'));
        return;
      }

      final backupDir =
          await Directory('${appDir!}/backups/').create(recursive: true);
      final file = File(backupDir.path + filename);

      final (f, errSave) = await fileStorage.saveToFile(
        file,
        HEX.encode(utf8.encode(encrypted)),
      );
      if (errSave != null) {
        emit(state.copyWith(error: 'Failed to save backup file.'));
        return;
      }

      emit(
        state.copyWith(
          backupId: backupId,
          backupKey: backupKey,
          backupPath: file.path,
          backupName: filename,
          loading: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: 'An unexpected error occurred: $e'));
    }
  }

  void clearError() => emit(state.copyWith(error: ''));
}
