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
    required WalletBloc walletBloc,
    required WalletSensitiveStorageRepository walletSensitiveStorage,
    required FileStorage fileStorage,
  })  : _walletBloc = walletBloc,
        _walletSensitiveStorage = walletSensitiveStorage,
        _fileStorage = fileStorage,
        super(BackupState(backup: const Backup()));

  final FileStorage _fileStorage;
  final WalletBloc _walletBloc;
  final WalletSensitiveStorageRepository _walletSensitiveStorage;

  Future<Backup> loadBackupData() async {
    emit(BackupState(loading: true, backup: const Backup()));

    final wallet = _walletBloc.state.wallet!;
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

    final backup = Backup(
      mnemonic: mnemonic,
      passphrases: passphrases,
      descriptors: descriptors,
      labels: labels,
    );

    emit(BackupState(backup: backup));
    return backup;
  }

  Future<(String?, Err?)> writeEncryptedBackup({
    required bool hasMnemonic,
    required bool hasPassphrases,
    required bool hasDescriptors,
  }) async {
    var backup = state.backup;
    if (!hasMnemonic) backup = backup.copyWith(mnemonic: []);
    if (!hasPassphrases) backup = backup.copyWith(passphrases: []);
    if (!hasDescriptors) backup = backup.copyWith(descriptors: []);
    if (backup.isEmpty) return (null, Err('Empty backup'));

    final secret = HEX.encode(Crypto.generateRandomBytes(32));
    final plaintext = json.encode(backup.toJson());
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
