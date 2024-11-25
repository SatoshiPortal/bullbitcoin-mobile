import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/_model/backup.dart';
import 'package:bb_mobile/_model/seed.dart';
import 'package:bb_mobile/_pkg/crypto.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/wallet/labels.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/backup/bloc/backup_state.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hex/hex.dart';
import 'package:intl/intl.dart';

class BackupCubit extends Cubit<BackupState> {
  BackupCubit({
    required this.wallets,
    required this.walletSensitiveStorage,
    required this.fileStorage,
  }) : super(BackupState(backups: []));

  final FileStorage fileStorage;
  final List<WalletBloc> wallets;
  final WalletSensitiveStorageRepository walletSensitiveStorage;

  Future<List<Backup>> loadBackupData() async {
    emit(BackupState(loading: true, backups: []));

    final backups = <Backup>[];

    for (final walletBloc in wallets) {
      final wallet = walletBloc.state.wallet!;

      final (seed, error) = await walletSensitiveStorage.readSeed(
        fingerprintIndex: wallet.getRelatedSeedStorageString(),
      );
      final mnemonic = seed?.mnemonic.split(' ') ?? [];

      final passphrases = <String>[];
      for (final Passphrase passphrase in seed?.passphrases ?? []) {
        passphrases.add(passphrase.passphrase);
      }

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
          mnemonic: mnemonic,
          passphrases: passphrases,
          descriptors: descriptors,
          labels: labels,
        ),
      );
    }

    emit(BackupState(backups: backups));
    return backups;
  }

  Future<(String?, String?)> writeEncryptedBackup() async {
    final backups = state.backups;

    final firstMnemonic = backups.first.mnemonic;
    final bdkMnemonic = await bdk.Mnemonic.fromString(firstMnemonic.join(' '));
    final xprv = await bdk.DescriptorSecretKey.create(
      network: bdk.Network.bitcoin, // TODO: handle testnet?
      mnemonic: bdkMnemonic,
      password: '', // TODO: which passphrase?
    );
    final rootXprv = xprv.toString().substring(0, 64); // remove /*
    print('rootXprv: $rootXprv');

    // const derivation = "m/1608'/0'"; // TODO: key rotation ?
    // final derived = derive(xprv: rootXprv, path: derivation);
    // print('derived: $derived');

    final backupKey = HEX.encode(Crypto.generateRandomBytes(32));
    final backupId = HEX.encode(Crypto.generateRandomBytes(32));

    final plaintext = json.encode(backups.map((i) => i.toJson()).toList());
    final ciphertext =
        Crypto.aesEncrypt(plaintext, backupKey); // TODO : extract nonce?

    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);
    final filename = '${formattedDate}_backup.json';

    final (directory, errDir) = await fileStorage.getDownloadDirectory();
    if (errDir != null) return (null, null); // Fail to get Download directory

    final file = File(directory! + '/' + filename);
    final content = json.encode({'id': backupId, 'encrypted': ciphertext});

    final (f, errSave) = await fileStorage.saveToFile(file, content);
    if (errSave != null) return (null, null); // Fail to save backup

    print(f?.path);

    return (backupKey, backupId);
  }
}
