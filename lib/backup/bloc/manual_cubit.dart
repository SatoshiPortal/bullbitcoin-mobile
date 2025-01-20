import 'package:bb_mobile/_model/backup.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/backup/local.dart';
import 'package:bb_mobile/_pkg/wallet/labels.dart';
import 'package:bb_mobile/_repository/wallet/sensitive_wallet_storage.dart';
import 'package:bb_mobile/backup/bloc/manual_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ManualCubit extends Cubit<ManualState> {
  ManualCubit({
    required this.wallets,
    required this.walletSensitiveStorage,
    required this.manager,
  }) : super(const ManualState());

  final FileSystemBackupManager manager;
  final List<Wallet> wallets;
  final WalletSensitiveStorageRepository walletSensitiveStorage;

  Future<void> loadBackupData() async {
    emit(state.copyWith(loading: true, error: ''));
    final backups = <Backup>[];
    final selectedBackupOptions = state.selectedBackupOptions;
    String? backupKeyMnemonic;
    for (final wallet in wallets) {
      var backup = Backup(
        name: wallet.name ?? '',
        network: wallet.network.name.toLowerCase(),
        layer: wallet.baseWalletType.name.toLowerCase(),
        script: wallet.scriptType.name.toLowerCase(),
        type: wallet.type.name.toLowerCase(),
        mnemonicFingerPrint: wallet.mnemonicFingerprint,
      );
      final (seed, error) = await walletSensitiveStorage.readSeed(
        fingerprintIndex: wallet.getRelatedSeedStorageString(),
      );
      if (error != null) {
        emit(state.copyWith(error: 'Error reading seed: ${error.message}'));
        return;
      }

      if (seed == null) {
        emit(state.copyWith(error: 'Seed data is missing.'));
        return;
      }
      if (selectedBackupOptions["mnemonic"] == true &&
          selectedBackupOptions["passphrase"] == true) {
        if (wallet.hasPassphrase()) {
          final sourceSeedPassphrases = seed.passphrases
              .where((e) => e.sourceFingerprint == wallet.sourceFingerprint)
              .toList();
          if (sourceSeedPassphrases.isEmpty) {
            emit(
              state.copyWith(
                error: 'Passphrase not found for the wallet source fingerprint',
              ),
            );
            return;
          } else {
            backup = backup.copyWith(
              mnemonic: seed.mnemonic.split(' '),
              passphrase: sourceSeedPassphrases.first.passphrase,
            );
          }
        } else {
          backup = backup.copyWith(
            mnemonic: seed.mnemonic.split(' '),
            passphrase: '',
          );
        }
        backupKeyMnemonic ??= seed.mnemonic;
      } else {
        backupKeyMnemonic ??= seed.mnemonic;
      }

      if (selectedBackupOptions["descriptors"] == true) {
        backup = backup.copyWith(descriptors: [wallet.getDescriptorCombined()]);
      }

      if (selectedBackupOptions["labels"] == true) {
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
    emit(
      state.copyWith(
        loadedBackups: backups,
        loading: false,
        backupKeyMnemonic: backupKeyMnemonic ?? '',
      ),
    );
  }

  void toggleDescriptors() => _toggleBackupOption("descriptors");

  void toggleLabels() => _toggleBackupOption("labels");

  void _toggleBackupOption(String option) {
    final selectedBackupOptions =
        Map<String, bool>.from(state.selectedBackupOptions);
    selectedBackupOptions[option] = !(selectedBackupOptions[option] ?? false);
    emit(state.copyWith(selectedBackupOptions: selectedBackupOptions));
  }

  void toggleAllMnemonicAndPassphrase() {
    final selectedBackupOptions =
        Map<String, bool>.from(state.selectedBackupOptions);
    final areBothConfirmed = selectedBackupOptions["mnemonic"] == true &&
        selectedBackupOptions["passphrase"] == true;
    final newConfirmed = !areBothConfirmed;
    selectedBackupOptions["mnemonic"] = newConfirmed;
    selectedBackupOptions["passphrase"] = newConfirmed;
    emit(state.copyWith(selectedBackupOptions: selectedBackupOptions));
  }

  Future<void> saveEncryptedBackup() async {
    emit(state.copyWith(loading: true, error: ''));
    await loadBackupData();
    final backups = state.loadedBackups;

    if (backups.isEmpty) {
      emit(
        state.copyWith(
          loading: false,
          error:
              'No wallet details found. Please ensure your wallets have the necessary data available.',
        ),
      );
      return;
    }

    try {
      const String derivationPath = "m/1608'/0'";
      final (encData, err) = await manager.encryptBackups(
        backups: backups,
        derivationPath: derivationPath,
        backupKeyMnemonic: state.backupKeyMnemonic,
      );
      if (err != null) {
        emit(
          state.copyWith(
            loading: false,
            error: 'Failed to encrypt backups: ${err.message}',
          ),
        );
        return;
      }

      final (filePath, errSave) =
          await manager.saveEncryptedBackup(encrypted: encData!.$2);
      if (errSave != null) {
        emit(
          state.copyWith(
            loading: false,
            error: 'Failed to save backup file:',
          ),
        );
        return;
      }
      final fileName = filePath?.split('/').last;
      final backupId = fileName?.split('_').last.split('.').first;
      emit(
        state.copyWith(
          backupId: backupId ?? '',
          backupKey: encData.$1,
          backupPath: filePath ?? '',
          backupName: fileName ?? '',
          loading: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          loading: false,
          error: 'An unexpected error occurred: $e',
        ),
      );
    }
  }

  void clearError() => emit(state.copyWith(error: ''));
  Future<void> clearAndClose() async {
    emit(
      state.copyWith(
        loadedBackups: [],
        backupKeyMnemonic: '',
        backupKey: '',
        backupId: '',
        backupPath: '',
        backupName: '',
        error: '',
        loading: false,
        selectedBackupOptions: {},
      ),
    );
    await close();
  }
}
