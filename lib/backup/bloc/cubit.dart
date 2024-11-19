import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/_model/backup.dart';
import 'package:bb_mobile/_model/seed.dart';
import 'package:bb_mobile/_pkg/crypto.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/wallet/labels.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/backup/bloc/state.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hex/hex.dart';
import 'package:intl/intl.dart';

class BackupCubit extends Cubit<BackupState> {
  BackupCubit({
    required List<WalletBloc> wallets,
    required WalletSensitiveStorageRepository walletSensitiveStorage,
    required FileStorage fileStorage,
  })  : _wallets = wallets,
        _walletSensitiveStorage = walletSensitiveStorage,
        _fileStorage = fileStorage,
        super(BackupState(backups: []));

  final FileStorage _fileStorage;
  final List<WalletBloc> _wallets;
  final WalletSensitiveStorageRepository _walletSensitiveStorage;

  Future<List<Backup>> loadBackupData() async {
    emit(BackupState(loading: true, backups: []));

    final backups = <Backup>[];

    for (final walletBloc in _wallets) {
      final wallet = walletBloc.state.wallet!;

      final (seed, error) = await _walletSensitiveStorage.readSeed(
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

  Future<(String?, Err?)> writeEncryptedBackup() async {
    final backups = state.backups;

    final secret = HEX.encode(Crypto.generateRandomBytes(32));
    final plaintext = json.encode(backups.map((i) => i.toJson()).toList());
    final ciphertext = Crypto.aesEncrypt(plaintext, secret);

    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);
    final filename = '${formattedDate}_backup.txt';

    final (directory, errDir) = await _fileStorage.getDownloadDirectory();
    if (errDir != null) return (null, Err('Fail to get Download directory'));
    final file = File(directory! + '/' + filename);

    final (f, errSave) = await _fileStorage.saveToFile(file, ciphertext);
    if (errSave != null) return (null, Err('Fail to save backup'));

    print(f?.path);

    return (secret, null);
  }
}
