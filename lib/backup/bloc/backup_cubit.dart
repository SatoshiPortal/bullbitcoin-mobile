import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/_model/backup.dart';
import 'package:bb_mobile/_pkg/crypto.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/wallet/labels.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/backup/bloc/backup_state.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:bip85/bip85.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hex/hex.dart';
import 'package:intl/intl.dart';

class BackupCubit extends Cubit<BackupState> {
  BackupCubit({
    required this.wallets,
    required this.walletSensitiveStorage,
    required this.fileStorage,
  }) : super(const BackupState());

  final FileStorage fileStorage;
  final List<WalletBloc> wallets;
  final WalletSensitiveStorageRepository walletSensitiveStorage;

  Future<void> loadBackupData() async {
    final backups = <Backup>[];

    for (final walletBloc in wallets) {
      final wallet = walletBloc.state.wallet!;

      final (seed, error) = await walletSensitiveStorage.readSeed(
        fingerprintIndex: wallet.getRelatedSeedStorageString(),
      );
      final mnemonic = seed?.mnemonic.split(' ') ?? [];

      final passphrase = wallet.hasPassphrase()
          ? seed!.passphrases
              .firstWhere(
                (e) => e.sourceFingerprint == wallet.sourceFingerprint,
              )
              .passphrase
          : '';

      final descriptors = [wallet.getDescriptorCombined()];

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

      backups.add(
        Backup(
          name: wallet.name ?? '',
          network: wallet.network.name.toLowerCase(),
          layer: wallet.baseWalletType.name.toLowerCase(),
          script: wallet.scriptType.name.toLowerCase(),
          type: wallet.type.name.toLowerCase(),
          mnemonic: mnemonic,
          passphrase: passphrase,
          descriptors: descriptors,
          labels: labels,
        ),
      );
    }

    emit(state.copyWith(backups: backups, loading: false));
  }

  Future<void> writeEncryptedBackup() async {
    final backups = state.backups;

    final firstMnemonic = backups.first.mnemonic;
    final bdkMnemonic = await bdk.Mnemonic.fromString(firstMnemonic.join(' '));
    final xprv = await bdk.DescriptorSecretKey.create(
      network: bdk.Network.bitcoin, // TODO: handle testnet?
      mnemonic: bdkMnemonic,
      password: '', // TODO: which passphrase?
    );
    final rootXprv = xprv.toString().substring(0, 111); // remove /*

    final derived = derive(xprv: rootXprv, path: "m/1608'/0'");
    final backupKey = HEX.encode(derived.sublist(0, 32));
    final backupId = HEX.encode(Crypto.generateRandomBytes(32));

    final plaintext = json.encode(backups.map((i) => i.toJson()).toList());
    final ciphertext = Crypto.aesEncrypt(plaintext, backupKey);
    // TODO : extract nonce?

    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);
    final filename = '$formattedDate.json';

    final (appDir, errDir) = await fileStorage.getAppDirectory();
    if (errDir != null) {
      emit(state.copyWith(error: 'Fail to get Download directory'));
    }

    final backupDir =
        await Directory(appDir! + '/backups/').create(recursive: true);
    final file = File(backupDir.path + filename);
    final content = json.encode({'id': backupId, 'encrypted': ciphertext});

    final (f, errSave) = await fileStorage.saveToFile(file, content);
    if (errSave != null) {
      emit(state.copyWith(error: 'Fail to save backup'));
    }

    emit(state.copyWith(backupId: backupId, backupKey: backupKey));
  }

  void clearError() => emit(state.copyWith(error: ''));
}
