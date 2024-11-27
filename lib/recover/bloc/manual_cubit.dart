import 'dart:convert';

import 'package:bb_mobile/_model/backup.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/crypto.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/create_sensitive.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';
import 'package:bb_mobile/recover/bloc/manual_state.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ManualCubit extends Cubit<ManualState> {
  ManualCubit({
    required this.bdkSensitiveCreate,
    required this.lwkSensitiveCreate,
    required this.walletSensitiveCreate,
    required this.walletsStorageRepository,
    required this.walletCreate,
    required this.wallets,
    required this.walletSensitiveStorage,
    required this.filePicker,
  }) : super(const ManualState());

  final FilePick filePicker;
  final List<WalletBloc> wallets;
  final WalletSensitiveStorageRepository walletSensitiveStorage;
  final WalletsStorageRepository walletsStorageRepository;
  final WalletSensitiveCreate walletSensitiveCreate;
  final BDKSensitiveCreate bdkSensitiveCreate;
  final WalletCreate walletCreate;
  final LWKSensitiveCreate lwkSensitiveCreate;

  void updateBackupKey(String value) => emit(state.copyWith(backupKey: value));
  void clearError() => emit(state.copyWith(error: ''));

  Future<void> selectFile() async {
    final (file, error) = await filePicker.pickFile();

    if (error != null) {
      emit(state.copyWith(error: error.toString()));
      return;
    }

    if (file == null || file.isEmpty) {
      emit(state.copyWith(error: 'Empty file'));
      return;
    }

    final json = jsonDecode(file);
    final id = json['id']?.toString() ?? '';
    final encrypted = json['encrypted']?.toString() ?? '';
    if (encrypted.isEmpty || id.isEmpty) {
      emit(state.copyWith(error: 'Invalid backup'));
      return;
    }

    emit(state.copyWith(backupId: id, encrypted: encrypted));
  }

  Future<void> clickRecover() async {
    final recovered = await _recoverBackup();
    if (recovered) emit(state.copyWith(recovered: true));
  }

  Future<bool> _recoverBackup() async {
    if (state.backupKey.length != 64) {
      emit(state.copyWith(error: 'Backup key should be 64 chars'));
      return false;
    }

    try {
      final plaintext = Crypto.aesDecrypt(state.encrypted, state.backupKey);
      final decodedJson = jsonDecode(plaintext) as List;

      final backups = decodedJson
          .map((item) => Backup.fromJson(item as Map<String, dynamic>))
          .toList();

      for (final backup in backups) {
        final network = switch (backup.network.toLowerCase()) {
          'mainnet' => BBNetwork.Mainnet,
          'testnet' => BBNetwork.Testnet,
          _ => null
        };

        final layer = switch (backup.layer.toLowerCase()) {
          'bitcoin' => BaseWalletType.Bitcoin,
          'liquid' => BaseWalletType.Liquid,
          _ => null
        };

        final script = switch (backup.script.toLowerCase()) {
          'bip44' => ScriptType.bip44,
          'bip49' => ScriptType.bip49,
          'bip84' => ScriptType.bip84,
          _ => null
        };

        final type = switch (backup.type.toLowerCase()) {
          'main' => BBWalletType.main,
          'xpub' => BBWalletType.xpub,
          'words' => BBWalletType.words,
          'descriptors' => BBWalletType.descriptors,
          'coldcard' => BBWalletType.coldcard,
          _ => null
        };

        if (network == null ||
            layer == null ||
            script == null ||
            type == null) {
          return false;
        }

        if (backup.mnemonic.isNotEmpty) {
          await _addWallet(
            backup.mnemonic.join(' '),
            backup.passphrase,
            network,
            layer,
            script,
            type,
          );
        }
      }

      return true;
    } catch (e) {
      emit(state.copyWith(error: 'Invalid backup key or file'));
      return false;
    }
  }

  Future<void> _addWallet(
    String mnemonic,
    String passphrase,
    BBNetwork network,
    BaseWalletType layer,
    ScriptType script,
    BBWalletType type,
  ) async {
    final (seed, error) =
        await walletSensitiveCreate.mnemonicSeed(mnemonic, network);

    await walletSensitiveStorage.newSeed(seed: seed!);

    Wallet? wallet;
    switch (layer) {
      case BaseWalletType.Bitcoin:
        final (btcWallet, btcError) = await bdkSensitiveCreate.oneFromBIP39(
          seed: seed,
          passphrase: passphrase,
          scriptType: script,
          network: network,
          walletType: type,
          walletCreate: walletCreate,
        );
        wallet = btcWallet;

      case BaseWalletType.Liquid:
        final (liqWallet, liqError) =
            await lwkSensitiveCreate.oneLiquidFromBIP39(
          seed: seed,
          passphrase: passphrase,
          scriptType: script,
          network: network,
          walletType: type,
          walletCreate: walletCreate,
        );
        wallet = liqWallet;
    }

    await walletsStorageRepository.newWallet(wallet!);
  }
}
