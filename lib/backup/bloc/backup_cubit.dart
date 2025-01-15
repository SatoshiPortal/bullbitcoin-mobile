import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/_model/backup.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/crypto.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/wallet/labels.dart';
import 'package:bb_mobile/_repository/wallet/sensitive_wallet_storage.dart';
import 'package:bb_mobile/backup/bloc/backup_state.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:bip85/bip85.dart';
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

      // why backup the labels since in restore we are not using them _recoverBackup()
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
    // TODO; Implement a proper backup key generation logic in case the user has not provided a mnemonic
    final firstMnemonic = backups.first.mnemonic;

    try {
      final backupKey = await _createBackupKey(
        firstMnemonic,
        // TODO; Implement a proper network selection logic
        bdk.Network.bitcoin,
      );
      final backupId = HEX.encode(Crypto.generateRandomBytes(32));

      final plaintext = json.encode(backups.map((i) => i.toJson()).toList());
      final encrypted =
          await BackupService.createBackup(backupId, plaintext, backupKey);
      final now = DateTime.now();
      //TODO; Find a better filename format.
      final formattedDate = now.millisecondsSinceEpoch;
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

Future<String> _createBackupKey(
  List<String>? mnemonicWords,
  bdk.Network network,
) async {
  late final bdk.Mnemonic bdkMnemonic;

  if (mnemonicWords != null && mnemonicWords.isNotEmpty) {
    // Mnemonic is present: Use it
    final mnemonicString = mnemonicWords.join(' ');
    bdkMnemonic = await bdk.Mnemonic.fromString(mnemonicString);
  } else {
    // Mnemonic is absent: Generate a new random one
    bdkMnemonic = await bdk.Mnemonic.create(bdk.WordCount.words12);
  }
  final descriptorSecretKey = await bdk.DescriptorSecretKey.create(
    network: network,
    mnemonic: bdkMnemonic,
    //TODO: Implement actual password logic
    password: '', // Passphrase (if any)
  );

  final extendedPrivateKey = descriptorSecretKey.asString().substring(0, 111);
  const String derivationPath = "m/1608'/0'";
  final derivedKeyBytes =
      _deriveBip85(xprv: extendedPrivateKey, path: derivationPath);
  final backupKeyHex = HEX.encode(derivedKeyBytes.sublist(0, 32));
  return backupKeyHex;
}

List<int> _deriveBip85({required String xprv, required String path}) {
  //TODO: Implement actual derivation logic
  // This is a dummy implementation for demonstration purposes.
  // Replace this with your actual derivation logic.
  print("Deriving with xprv: $xprv and path: $path");
  final derived = derive(xprv: xprv, path: path);
  return derived.sublist(0, 64); // Dummy 64-byte result
}
