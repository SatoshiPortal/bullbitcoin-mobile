import 'dart:async';
import 'dart:convert';

import 'package:bb_mobile/_model/seed.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_model/wallet_sensitive_data.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/_pkg/recoverbull/google_drive.dart';
import 'package:bb_mobile/_pkg/recoverbull/local.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/create_sensitive.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/sensitive_create.dart';
import 'package:bb_mobile/_repository/app_wallets_repository.dart';
import 'package:bb_mobile/_repository/wallet/sensitive_wallet_storage.dart';
import 'package:bb_mobile/_repository/wallet/wallet_storage.dart';
import 'package:bb_mobile/_repository/wallet_service.dart';
import 'package:bb_mobile/home/bloc/home_bloc.dart';
import 'package:bb_mobile/home/bloc/home_event.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/recoverbull/bloc/backup_settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hex/hex.dart';

BackupSettingsCubit createBackupSettingsCubit({String? walletId}) {
  final appWalletsRepo = locator<AppWalletsRepository>();
  final wallets = appWalletsRepo.allWallets;

  final currentWallet = walletId != null
      ? wallets.firstWhere((w) => w.id == walletId, orElse: () => wallets.first)
      : null;

  return BackupSettingsCubit(
    wallets: wallets,
    appWalletsRepository: appWalletsRepo,
    walletSensRepository: locator<WalletSensitiveStorageRepository>(),
    manager: locator<FileSystemBackupManager>(),
    driveManager: locator<GoogleDriveBackupManager>(),
    lwkSensitiveCreate: locator<LWKSensitiveCreate>(),
    bdkSensitiveCreate: locator<BDKSensitiveCreate>(),
    walletCreate: locator<WalletCreate>(),
    walletSensitiveCreate: locator<WalletSensitiveCreate>(),
    walletsStorageRepository: locator<WalletsStorageRepository>(),
    currentWallet: currentWallet,
  );
}

class BackupSettingsCubit extends Cubit<BackupSettingsState> {
  BackupSettingsCubit({
    required List<Wallet> wallets,
    required AppWalletsRepository appWalletsRepository,
    required WalletSensitiveStorageRepository walletSensRepository,
    required LWKSensitiveCreate lwkSensitiveCreate,
    required BDKSensitiveCreate bdkSensitiveCreate,
    required WalletCreate walletCreate,
    required WalletSensitiveCreate walletSensitiveCreate,
    required WalletsStorageRepository walletsStorageRepository,
    required GoogleDriveBackupManager driveManager,
    required FileSystemBackupManager manager,
    required Wallet? currentWallet,
  })  : _walletSensRepository = walletSensRepository,
        _appWalletsRepository = appWalletsRepository,
        _wallets = wallets,
        _currentWallet = currentWallet,
        _fileSystemBackupManager = manager,
        _googleDriveBackupManager = driveManager,
        _filePicker = locator<FilePick>(),
        _walletSensitiveCreate = walletSensitiveCreate,
        _bdkSensitiveCreate = bdkSensitiveCreate,
        _walletCreate = walletCreate,
        _lwkSensitiveCreate = lwkSensitiveCreate,
        _walletsStorageRepository = walletsStorageRepository,
        super(const BackupSettingsState());

  final WalletsStorageRepository _walletsStorageRepository;
  final WalletSensitiveStorageRepository _walletSensRepository;
  final AppWalletsRepository _appWalletsRepository;
  final WalletSensitiveCreate _walletSensitiveCreate;
  final BDKSensitiveCreate _bdkSensitiveCreate;
  final WalletCreate _walletCreate;
  final LWKSensitiveCreate _lwkSensitiveCreate;
  Wallet? _currentWallet;
  final List<Wallet> _wallets;
  final FileSystemBackupManager _fileSystemBackupManager;
  final GoogleDriveBackupManager _googleDriveBackupManager;
  final FilePick? _filePicker;
  static const _kDelayDuration = Duration(milliseconds: 800);
  static const _kShuffleDelay = Duration(milliseconds: 500);
  static const _kMinBackupInterval = Duration(seconds: 5);

  void changePassword(String password) {
    emit(
      state.copyWith(
        testBackupPassword: password,
        errTestingBackup: '',
      ),
    );
  }

  void clearError() => emit(
        state.copyWith(
          errTestingBackup: '',
          errorLoadingBackups: '',
          errorSavingBackups: '',
        ),
      );

  void clearMnemonic() {
    emit(
      state.copyWith(
        mnemonic: List.filled(12, ''),
        testBackupPassword: '',
      ),
    );
  }

  Future<void> clearSensitive() async {
    clearMnemonic();
    emit(
      state.copyWith(
        mnemonic: [],
        password: '',
        shuffledMnemonic: [],
        testMnemonicOrder: [],
      ),
    );
  }

  Future<void> connectToGoogleDrive() async {
    try {
      final (api, err) = await _googleDriveBackupManager.connect();
      if (err != null) {
        _emitBackupError('Failed to connect to Google Drive: ${err.message}');
        return;
      }
      _emitSafe(state.copyWith(errorSavingBackups: ''));
    } catch (e) {
      _emitBackupError('Google Drive connection error: $e');
    }
  }

  void disconnectGoogleDrive() {
    _googleDriveBackupManager.disconnect();
    emit(state.copyWith(backupFolderPath: ''));
  }

  Future<void> deleteFsBackup() async {
    if (_filePicker == null) return;

    final (file, error) = await _filePicker.pickFile();

    if (error != null) {
      debugPrint('Error picking the file: ${error.message}');
      emit(state.copyWith(errorLoadingBackups: "Error picking file"));
      return;
    }
    if (file == null) {
      emit(state.copyWith(errorLoadingBackups: 'Corrupted backup file'));
      return;
    }

    final (deleted, err) = await _fileSystemBackupManager.removeEncryptedBackup(
      path: file.path,
    );

    if (err != null) {
      emit(state.copyWith(errorSavingBackups: 'Failed to delete backup'));
      return;
    }

    emit(state.copyWith(backupFolderPath: ''));
  }

  Future<void> deleteGoogleDriveBackup(String path) async {
    if (state.backupFolderPath.isEmpty) {
      emit(state.copyWith(errorSavingBackups: 'No backup to delete'));
      return;
    }

    final (deleted, err) =
        await _googleDriveBackupManager.removeEncryptedBackup(path: path);

    if (err != null) {
      emit(state.copyWith(errorSavingBackups: 'Failed to delete backup'));
      return;
    }

    emit(state.copyWith(backupFolderPath: ''));
  }

  Future<void> fetchFsBackup() async {
    if (_filePicker == null) return;

    final (file, error) = await _filePicker.pickFile();

    if (error != null) {
      emit(state.copyWith(errorLoadingBackups: "Error picking file"));
      return;
    }
    final fileContent = await file?.readAsString();
    if (file == null || fileContent == null) {
      emit(state.copyWith(errorLoadingBackups: 'Corrupted backup file'));
      return;
    }
    final (loadedBackup, err) =
        await _fileSystemBackupManager.loadEncryptedBackup(backup: fileContent);
    if (loadedBackup != null) {
      loadedBackup.addAll({'source': 'fs'});
      emit(
        state.copyWith(
          loadingBackups: false,
          latestRecoveredBackup: loadedBackup,
          lastBackupAttempt: DateTime.now(),
        ),
      );
      return;
    } else if ((err != null) || loadedBackup?["id"] == null) {
      debugPrint('Error loading backups: ${err?.message}');
      emit(
        state.copyWith(
          loadingBackups: false,
          errorLoadingBackups: "Corrupted backup file",
        ),
      );
      return;
    }
  }

  Future<void> fetchGoogleDriveBackup({bool forceRefresh = false}) async {
    try {
      if (!forceRefresh && state.loadedBackups.isNotEmpty) {
        emit(state.copyWith(loadingBackups: false));
        return;
      }

      _emitSafe(state.copyWith(loadingBackups: true));

      final (api, connectErr) = await _googleDriveBackupManager.connect();
      if (connectErr != null) {
        _handleLoadError(connectErr.message);
        return;
      }

      final (availableBackups, err) =
          await _googleDriveBackupManager.loadAllEncryptedBackupFiles();

      if (err != null) {
        debugPrint('Error loading backups: ${err.message}');
        _handleLoadError("Failed to get backup files");
        return;
      }

      if (availableBackups != null && availableBackups.isNotEmpty) {
        final latestBackup = availableBackups.reduce((a, b) {
          final aTime = a.createdTime;
          final bTime = b.createdTime;
          if (aTime == null) return b;
          if (bTime == null) return a;
          return aTime.compareTo(bTime) > 0 ? a : b;
        });

        final backupId = latestBackup.name?.split('_').last.split('.').first;
        if (backupId == null) {
          _handleLoadError("Corrupted backup file");
          return;
        }

        final (loadedBackupMetaData, mediaErr) =
            await _googleDriveBackupManager.fetchMediaStream(
          file: latestBackup,
        );

        if (mediaErr != null || loadedBackupMetaData == null) {
          debugPrint('Error loading backups: ${mediaErr?.message}');
          _handleLoadError("Failed to load backup data");
          return;
        }

        final (loadedBackup, err) =
            await _googleDriveBackupManager.loadEncryptedBackup(
          backup: utf8.decode(loadedBackupMetaData),
        );
        if (loadedBackup != null) {
          loadedBackup.addAll({
            'source': 'drive',
            'filename': latestBackup.name,
          });

          emit(
            state.copyWith(
              loadingBackups: false,
              latestRecoveredBackup: loadedBackup,
              lastBackupAttempt: DateTime.now(),
            ),
          );
          return;
        } else if ((err != null) || loadedBackup?["id"] == null) {
          debugPrint('Error loading backups: ${err?.message}');
          _handleLoadError("Corrupted backup file");
          return;
        }
      } else {
        _handleLoadError("Failed to get backup files");
      }
    } catch (e) {
      _handleLoadError('Failed to fetch backup: $e');
    }
  }

  Future<void> loadBackupForVerification() async {
    if (_currentWallet == null) {
      emit(
        state.copyWith(
          errorLoadingBackups: 'No wallet selected for verification',
          loadingBackups: false,
        ),
      );
      return;
    }

    emit(state.copyWith(loadingBackups: true));
    final (seed, error) = await _loadWalletSeed(_currentWallet!);
    if (error != null || seed == null) {
      emit(
        state.copyWith(
          errTestingBackup: error?.toString() ?? 'Seed data not found',
          loadingBackups: false,
        ),
      );
      return;
    }

    _emitBackupState(seed);
  }

  Future<void> recoverBackup(String encrypted, String backupKey) async {
    _emitSafe(
      state.copyWith(
        loadingBackups: true,
        backupKey: backupKey,
        errorLoadingBackups: '',
      ),
    );

    if (backupKey.isEmpty) {
      _handleLoadError('WalletSensitiveData key is missing');
      return;
    }

    final backupId = jsonDecode(encrypted)['id'] as String?;

    if (backupId == null) {
      _handleLoadError('Invalid backup format');
      return;
    }

    final (backups, decryptErr) =
        await _fileSystemBackupManager.restoreEncryptedBackup(
      backup: encrypted,
      backupKey: HEX.decode(backupKey),
    );

    if (decryptErr != null || backups == null || backups.isEmpty) {
      _handleLoadError(decryptErr?.message ?? 'No wallets found in backup');
      return;
    }

    for (final backup in backups) {
      final err = await _processBackupRecovery(backup);
      if (err != null) {
        _handleLoadError(err.message);
        return;
      }
    }

    // Update home state and sort wallets
    locator<HomeBloc>().add(LoadWalletsFromStorage());
    await locator<WalletsStorageRepository>().sortWallets();

    _emitSafe(
      state.copyWith(
        loadingBackups: false,
        loadedBackups: backups,
        errorLoadingBackups: '',
      ),
    );
  }

  Future<void> recoverBackupKeyFromMnemonic(int? backupKeyIndex) async {
    _emitSafe(state.copyWith(loadingBackups: true, errorLoadingBackups: ''));

    try {
      if (backupKeyIndex == null) {
        _handleLoadError('Invalid backup format - missing index');
        return;
      }

      final (mainSeed, fetchMainSeedErr) = await _fetchMainSeed();
      if (fetchMainSeedErr != null || mainSeed == null) {
        _handleLoadError('Failed to load seed data');
        return;
      }

      final (backupKey, deriveErr) =
          await _fileSystemBackupManager.deriveBackupKey(
        mainSeed.mnemonic.split(' '),
        mainSeed.network.toString(),
        backupKeyIndex,
      );

      if (backupKey == null) {
        debugPrint('Error deriving backup key: $deriveErr');
        _handleLoadError('Failed to derive backup key');
        return;
      }
      _emitSafe(
        state.copyWith(
          loadingBackups: false,
          backupKey: HEX.encode(backupKey),
          errorLoadingBackups: '',
        ),
      );
    } catch (e) {
      _handleLoadError('Recovery failed: $e');
    }
  }

  Future<void> resetBackupTested() async {
    await Future.delayed(_kDelayDuration);
    emit(state.copyWith(backupTested: false));
  }

  Future<void> saveFileSystemBackup() async {
    if (!_canStartBackup()) {
      _handleSaveError('Please wait before attempting another backup');
      return;
    }

    _emitSafe(state.copyWith(savingBackups: true, errorSavingBackups: ''));
    if (_wallets.isEmpty) {
      _handleLoadError('No wallets available for backup');
      return;
    }
    final backups = await _createBackupsForAllWallets();
    if (backups.isEmpty) {
      _handleSaveError('Failed to create backups');
      return;
    }

    final (backup, err) = await _createBackup(backups);
    if (err != null || backup == null) {
      _handleSaveError(err?.message ?? 'Encryption failed');
      return;
    }

    final (savePath, pickErr) = await _filePicker?.getDirectoryPath() ??
        (null, Err('File picker not initialized'));
    if (pickErr != null) {
      _handleSaveError('Failed to select backup location: ${pickErr.message}');
      return;
    }

    if (savePath == null || savePath.isEmpty) {
      _handleSaveError('No location selected for backup');
      return;
    }

    final (filePath, saveErr) =
        await _fileSystemBackupManager.saveEncryptedBackup(
      backup: backup.file,
      backupFolder: savePath,
    );

    if (saveErr != null) {
      _handleSaveError('Save failed: ${saveErr.message}');
      return;
    }

    final theBackup = json.decode(backup.file);
    final backupId = theBackup['id'] as String?;
    final backupSalt = theBackup['salt'] as String?;
    if (backupId == null || backupSalt == null) {
      _handleSaveError('Failed to extract backup metadata');
      return;
    }

    _emitSafe(
      state.copyWith(
        backupId: backupId,
        backupKey: backup.key,
        backupFolderPath: filePath ?? '',
        backupSalt: backupSalt,
        savingBackups: false,
        lastBackupAttempt: DateTime.now(),
      ),
    );
  }

  Future<void> saveGoogleDriveBackup() async {
    if (!_canStartBackup()) {
      _handleSaveError('Please wait before attempting another backup');
      return;
    }

    _emitSafe(state.copyWith(savingBackups: true, errorSavingBackups: ''));

    if (_wallets.isEmpty) {
      _handleLoadError('No wallets available for backup');
      return;
    }

    final (api, connectErr) = await _googleDriveBackupManager.connect();
    if (connectErr != null) {
      _handleSaveError(connectErr.message);
      return;
    }

    final backups = await _createBackupsForAllWallets();
    if (backups.isEmpty) {
      _handleSaveError('Failed to create backups');
      return;
    }

    final (backup, encryptErr) = await _createBackup(backups);
    if (encryptErr != null || backup == null) {
      _handleSaveError(encryptErr?.message ?? 'Encryption failed');
      return;
    }

    final (filePath, saveErr) = await _googleDriveBackupManager
        .saveEncryptedBackup(backup: backup.file);

    if (saveErr != null) {
      _handleSaveError('Failed to save to Google Drive: ${saveErr.message}');
      return;
    }

    final theBackup = json.decode(backup.file);
    final backupId = theBackup['id'] as String?;
    final backupSalt = theBackup['salt'] as String?;
    final filename = filePath?.split('/').last;
    if (backupId == null || filename == null || backupSalt == null) {
      _handleSaveError('Failed to extract backup information');
      return;
    }

    _emitSafe(
      state.copyWith(
        backupId: backupId,
        backupKey: backup.key,
        backupFolderPath: filename,
        backupSalt: backupSalt,
        savingBackups: false,
        lastBackupAttempt: DateTime.now(),
      ),
    );
  }

  Future<void> testBackupClicked() async {
    emit(state.copyWith(testingBackup: true, errTestingBackup: ''));

    final words = state.testMneString();
    final password = state.testBackupPassword;
    final (seed, error) = await _loadWalletSeed(_currentWallet!);
    if (error != null) {
      debugPrint('Failed to read wallet ${_currentWallet!.name}: $error');
      return;
    }
    if (seed == null) {
      emit(
        state.copyWith(
          errTestingBackup: 'Unable to load wallet data',
          testingBackup: false,
        ),
      );
      return;
    }

    if (!_verifyWords(seed.mnemonic, words)) {
      emit(
        state.copyWith(
          errTestingBackup: 'Invalid seed words',
          testingBackup: false,
        ),
      );
      return;
    }

    if (!_verifyPassphrase(seed, password)) {
      emit(
        state.copyWith(
          errTestingBackup: 'Invalid passphrase',
          testingBackup: false,
        ),
      );
      return;
    }

    await _updateWalletBackupStatus(
      _currentWallet!.copyWith(
        physicalBackupTested: true,
        lastPhysicalBackupTested: DateTime.now(),
      ),
    );
    _emitBackupTestSuccessState();
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

  Future<(Wallet?, Err?)> _addOrUpdateWallet(
    BBNetwork network,
    BaseWalletType layer,
    ScriptType script,
    BBWalletType type,
    String mnemonic,
    String passphrase,
    String publicDescriptors,
  ) async {
    final (seed, error) =
        await _walletSensitiveCreate.mnemonicSeed(mnemonic, network);
    if (seed == null) {
      return (null, Err('Failed to create seed: $error'));
    }

    try {
      final error = await _walletSensRepository.newSeed(seed: seed);

      if (error != null && !error.message.toLowerCase().contains('exists')) {
        return (null, Err(error.toString()));
      }
      final wallet = await _createWalletFromSeed(
        layer,
        seed,
        passphrase,
        script,
        network,
        type,
        publicDescriptors,
      );

      if (wallet == null) {
        return (null, Err('Failed to create wallet'));
      }

      final walletRepoErr = await _walletsStorageRepository
          .newWallet(wallet.copyWith(vaultBackupTested: true));
      if (walletRepoErr != null &&
          !walletRepoErr.message.toLowerCase().contains('exists')) {
        return (null, Err(walletRepoErr.toString()));
      }
      return (wallet, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  bool _canStartBackup() {
    final lastAttempt = state.lastBackupAttempt;
    if (lastAttempt != null) {
      final timeSinceLastBackup = DateTime.now().difference(lastAttempt);
      if (timeSinceLastBackup < _kMinBackupInterval) {
        return false;
      }
    }
    return true;
  }

  Future<Wallet?> _createWalletFromSeed(
    BaseWalletType layer,
    Seed seed,
    String passphrase,
    ScriptType script,
    BBNetwork network,
    BBWalletType type,
    String publicDescriptors,
  ) async {
    switch (layer) {
      case BaseWalletType.Bitcoin:
        final (wallet, error) = await _bdkSensitiveCreate.oneFromBIP39(
          seed: seed,
          passphrase: passphrase,
          scriptType: script,
          network: network,
          walletType: type,
          walletCreate: _walletCreate,
          publicDescriptors: publicDescriptors,
        );
        return wallet;
      case BaseWalletType.Liquid:
        final (wallet, error) = await _lwkSensitiveCreate.oneLiquidFromBIP39(
          seed: seed,
          passphrase: passphrase,
          scriptType: script,
          network: network,
          walletType: type,
          walletCreate: _walletCreate,
        );
        return wallet;
    }
  }

  Future<List<WalletSensitiveData>> _createBackupsForAllWallets() async {
    final backups = <WalletSensitiveData>[];

    try {
      for (final wallet in _wallets) {
        final backup = await _createBackupForWallet(wallet);
        if (backup != null) backups.add(backup);
      }
      return backups;
    } catch (e) {
      debugPrint('Error creating backups: $e');
      _emitBackupError('Failed to create backups');
      return [];
    }
  }

  Future<WalletSensitiveData?> _createBackupForWallet(Wallet wallet) async {
    try {
      final (seed, err) = await _loadWalletSeed(wallet);
      if (err != null || seed == null) {
        debugPrint('Failed to read wallet ${wallet.name}: $err');
        _emitBackupError('Failed to read wallet ${wallet.name}');
        return null;
      }

      final backup = WalletSensitiveData(
        name: wallet.name ?? '',
        network: wallet.network.name,
        layer: wallet.baseWalletType.name,
        script: wallet.scriptType.name,
        type: wallet.type.name,
        publicDescriptors: [
          wallet.externalPublicDescriptor,
          wallet.internalPublicDescriptor,
        ].join(','),
      );

      if (!wallet.hasPassphrase()) {
        return backup.copyWith(
          mnemonic: seed.mnemonic.split(' '),
          passphrase: '',
        );
      }

      final passphrases = seed.passphrases
          .where((e) => e.sourceFingerprint == wallet.sourceFingerprint);

      if (passphrases.isEmpty) {
        _emitBackupError('No passphrase found for wallet ${wallet.name}');
        return backup;
      }

      return backup.copyWith(
        mnemonic: seed.mnemonic.split(' '),
        passphrase: passphrases.first.passphrase,
      );
    } catch (e) {
      _emitBackupError('Error creating backup for ${wallet.name}: $e');
      return null;
    }
  }

  void _emitBackupError(String message) {
    emit(state.copyWith(savingBackups: false, errorSavingBackups: message));
  }

  void _emitBackupState(Seed seed) {
    if (_currentWallet == null) {
      emit(
        state.copyWith(
          errorLoadingBackups: 'No active wallet selected',
          loadingBackups: false,
        ),
      );
      return;
    }

    final words = seed.mnemonic.split(' ');
    final shuffled = words.toList()..shuffle();

    emit(
      state.copyWith(
        testMnemonicOrder: [],
        mnemonic: words,
        errTestingBackup: '',
        password: seed
            .getPassphraseFromIndex(_currentWallet!.sourceFingerprint)
            .passphrase,
        shuffledMnemonic: shuffled,
        loadingBackups: false,
      ),
    );
  }

  void _emitBackupTestSuccessState() {
    emit(state.copyWith(backupTested: true, testingBackup: false));
    clearSensitive();
  }

  void _emitSafe(BackupSettingsState newState) {
    if (!isClosed) emit(newState);
  }

  Future<(({String key, String file})?, Err?)> _createBackup(
    List<WalletSensitiveData> wallets,
  ) async {
    try {
      final (mainSeed, fetchMainMnemonicErr) = await _fetchMainSeed();
      if (fetchMainMnemonicErr != null || mainSeed == null) {
        return (null, fetchMainMnemonicErr);
      }
      final (backup, err) =
          await _fileSystemBackupManager.createEncryptedBackup(
        wallets: wallets,
        mnemonic: mainSeed.mnemonic.split(' '),
        network: mainSeed.network.toString().toLowerCase(),
      );

      if (err != null || backup == null) {
        return (null, err);
      }

      return (backup, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(Seed?, Err?)> _fetchMainSeed() async {
    final mainWallet = _wallets.firstWhere(
      (wallet) =>
          wallet.mainWallet &&
          wallet.type == BBWalletType.main &&
          wallet.baseWalletType == BaseWalletType.Bitcoin &&
          wallet.network == BBNetwork.Mainnet,
      orElse: () => _wallets.firstWhere(
        (wallet) =>
            wallet.mainWallet &&
            wallet.type == BBWalletType.main &&
            wallet.baseWalletType == BaseWalletType.Bitcoin &&
            wallet.network == BBNetwork.Testnet,
        orElse: () => _wallets.first,
      ),
    );

    return await _loadWalletSeed(mainWallet);
  }

  BaseWalletType? _getLayer(String layer) => switch (layer.toLowerCase()) {
        'bitcoin' => BaseWalletType.Bitcoin,
        'liquid' => BaseWalletType.Liquid,
        _ => null
      };

  ScriptType? _getScript(String script) => switch (script.toLowerCase()) {
        'bip44' => ScriptType.bip44,
        'bip49' => ScriptType.bip49,
        'bip84' => ScriptType.bip84,
        _ => null
      };

  BBWalletType? _getWalletType(String type) => switch (type.toLowerCase()) {
        'main' => BBWalletType.main,
        'xpub' => BBWalletType.xpub,
        'words' => BBWalletType.words,
        'descriptors' => BBWalletType.descriptors,
        'coldcard' => BBWalletType.coldcard,
        _ => null
      };

  void _handleLoadError(String message, {bool loading = false}) {
    _emitSafe(
      state.copyWith(
        errorLoadingBackups: message,
        loadingBackups: loading,
      ),
    );
  }

  void _handleSaveError(String message, {bool saving = false}) {
    _emitSafe(
      state.copyWith(
        errorSavingBackups: message,
        savingBackups: saving,
      ),
    );
  }

  Future<void> invalidTestOrderClicked() async {
    emit(
      state.copyWith(
        testMnemonicOrder: [],
        errTestingBackup: 'Invalid mnemonic order',
      ),
    );
    await Future.delayed(_kShuffleDelay);
    final shuffled = state.mnemonic.toList()..shuffle();
    emit(
      state.copyWith(
        shuffledMnemonic: shuffled,
        errTestingBackup: '',
      ),
    );
  }

  Future<(Seed?, Err?)> _loadWalletSeed(Wallet wallet) async {
    final (seed, err) = await _walletSensRepository.readSeed(
      fingerprintIndex: wallet.getRelatedSeedStorageString(),
    );
    return (seed, err);
  }

  Future<Err?> _processBackupRecovery(WalletSensitiveData backup) async {
    final network = BBNetwork.fromString(backup.network);
    final layer = _getLayer(backup.layer);
    final script = _getScript(backup.script);
    final type = _getWalletType(backup.type);

    if (layer == null || script == null || type == null) {
      return Err('Invalid backup configuration for ${backup.network}');
    }

    final (savedWallet, err) = await _addOrUpdateWallet(
      network,
      layer,
      script,
      type,
      backup.mnemonic.join(' '),
      backup.passphrase,
      backup.publicDescriptors,
    );
    if (savedWallet != null) {
      await _updateWalletBackupStatus(
        savedWallet.copyWith(
          vaultBackupTested: true,
          lastVaultBackupTested: DateTime.now(),
        ),
      );
    }
    return err;
  }

  Future<void> _updateWalletBackupStatus(Wallet updatedWallet) async {
    final service =
        _appWalletsRepository.getWalletServiceById(updatedWallet.id);
    if (service != null) {
      await service.updateWallet(
        updatedWallet,
        updateTypes: [UpdateWalletTypes.settings],
      );
      _currentWallet = updatedWallet;
    }
  }

  bool _verifyPassphrase(Seed seed, String password) {
    final storedPassphrase = seed
        .getPassphraseFromIndex(_currentWallet!.sourceFingerprint)
        .passphrase;
    return storedPassphrase == password;
  }

  bool _verifyWords(String seedMnemonic, String testWords) =>
      seedMnemonic == testWords;
}
