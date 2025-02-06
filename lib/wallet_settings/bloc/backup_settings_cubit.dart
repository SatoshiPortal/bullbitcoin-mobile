import 'dart:async';
import 'dart:convert';

import 'package:bb_mobile/_model/backup.dart';
import 'package:bb_mobile/_model/seed.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/backup/google_drive.dart';
import 'package:bb_mobile/_pkg/backup/local.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/create_sensitive.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/sensitive_create.dart';
import 'package:bb_mobile/_repository/app_wallets_repository.dart';
import 'package:bb_mobile/_repository/wallet/sensitive_wallet_storage.dart';
import 'package:bb_mobile/_repository/wallet/wallet_storage.dart';
import 'package:bb_mobile/_repository/wallet_service.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/wallet_settings/bloc/backup_settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

BackupSettingsCubit createBackupSettingsCubit({String? walletId}) {
  final appWalletsRepo = locator<AppWalletsRepository>();
  final wallets = appWalletsRepo.allWallets;

  final currentWallet = walletId != null
      ? wallets.firstWhere((w) => w.id == walletId, orElse: () => wallets.first)
      : wallets.first;

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
        _manager = manager,
        _driveManager = driveManager,
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
  final FileSystemBackupManager _manager;
  final GoogleDriveBackupManager _driveManager;
  final FilePick? _filePicker;
  static const _kDelayDuration = Duration(milliseconds: 800);
  static const _kShuffleDelay = Duration(milliseconds: 500);
  static const _kMinBackupInterval = Duration(seconds: 5);
  static const _kDerivationPath = "m/1608'/0'";

  @override
  Future<void> close() async {
    await _driveManager.dispose();
    await super.close();
  }

  // Seed loading helper
  Future<(Seed?, String?)> _loadWalletSeed(Wallet wallet) async {
    final (seed, err) = await _walletSensRepository.readSeed(
      fingerprintIndex: wallet.getRelatedSeedStorageString(),
    );
    return (seed, err?.toString());
  }

  // physical backup & verification methods

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

    emit(state.copyWith(
      testMnemonicOrder: [],
      mnemonic: words,
      errTestingBackup: '',
      password: seed
          .getPassphraseFromIndex(_currentWallet!.sourceFingerprint)
          .passphrase,
      shuffledMnemonic: shuffled,
      loadingBackups: false,
    ));
  }

  void _emitBackupTestSuccessState() {
    emit(
      state.copyWith(
        backupTested: true,
        testingBackup: false,
      ),
    );
    clearSensitive();
  }

  Future<void> loadBackupForVerification() async {
    if (_currentWallet == null) {
      emit(state.copyWith(
        errorLoadingBackups: 'No wallet selected for verification',
        loadingBackups: false,
      ));
      return;
    }

    emit(state.copyWith(loadingBackups: true));
    final (seed, error) = await _loadWalletSeed(_currentWallet!);
    if (error != null || seed == null) {
      emit(state.copyWith(
        errTestingBackup: error ?? 'Seed data not found',
        loadingBackups: false,
      ));
      return;
    }

    _emitBackupState(seed);
  }

  Future<void> testBackupClicked() async {
    emit(state.copyWith(testingBackup: true, errTestingBackup: ''));

    final words = state.testMneString();
    final password = state.testBackupPassword;
    final seed = await _loadSeedData(_currentWallet!);

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

    await _updateWalletBackupStatus();
    _emitBackupTestSuccessState();
  }

  bool _verifyWords(String seedMnemonic, String testWords) =>
      seedMnemonic == testWords;

  bool _verifyPassphrase(Seed seed, String password) {
    final storedPassphrase = seed
        .getPassphraseFromIndex(_currentWallet!.sourceFingerprint)
        .passphrase;
    return storedPassphrase == password;
  }

  Future<Seed?> _loadSeedData(Wallet wallet) async {
    final (seed, err) = await _walletSensRepository.readSeed(
      fingerprintIndex: wallet.getRelatedSeedStorageString(),
    );
    if (err != null) {
      emit(state.copyWith(errTestingBackup: err.toString()));
      return null;
    }
    return seed;
  }

  Future<void> _updateWalletBackupStatus() async {
    final wallet = _currentWallet!.copyWith(
      physicalBackupTested: true,
      lastPhysicalBackupTested: DateTime.now(),
    );

    final service = _appWalletsRepository.getWalletServiceById(wallet.id);
    if (service != null) {
      await service.updateWallet(
        wallet,
        updateTypes: [UpdateWalletTypes.settings],
      );
      _currentWallet = wallet;
    }
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

  void changePassword(String password) {
    emit(
      state.copyWith(
        testBackupPassword: password,
        errTestingBackup: '',
      ),
    );
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

  Future<void> resetBackupTested() async {
    await Future.delayed(_kDelayDuration);
    emit(state.copyWith(backupTested: false));
  }

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

// encrypted vault backup methods
  void _emitBackupError(String message) {
    emit(
      state.copyWith(
        savingBackups: false,
        errorSavingBackups: message,
      ),
    );
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

  Future<void> saveEncryptedBackup() async {
    if (!_canStartBackup()) {
      emit(
        state.copyWith(
          errorSavingBackups: 'Please wait before attempting another backup',
          savingBackups: false,
          backupKey: '',
        ),
      );
      return;
    }

    emit(state.copyWith(savingBackups: true, errorSavingBackups: ''));

    final backups = await _createBackupsForAllWallets();
    if (backups.isEmpty) {
      _emitBackupError('No wallets available for backup');
      return;
    }

    final (encryptedData, err) = await _encryptBackups(backups);
    if (err != null || encryptedData == null) {
      return;
    }

    await _saveToFileSystem(encryptedData);
  }

  Future<void> saveGoogleDriveBackup() async {
    if (!_canStartBackup()) {
      _emitBackupError('Please wait before attempting another backup');
      return;
    }

    emit(state.copyWith(savingBackups: true, errorSavingBackups: ''));

    try {
      if (state.backupFolderId.isEmpty) {
        await connectToGoogleDrive();
        if (state.backupFolderId.isEmpty) return;
      }

      final backups = await _createBackupsForAllWallets();
      if (backups.isEmpty) {
        _emitBackupError('No wallets available for backup');
        return;
      }

      // Connect if needed
      if (state.backupFolderId.isEmpty) {
        final (folderId, err) = await _driveManager.connect();
        if (err != null) {
          _emitBackupError('Failed to connect to Google Drive: ${err.message}');
          return;
        }
        emit(state.copyWith(backupFolderId: folderId ?? ''));
      }

      // Ensure we have a folder ID
      if (state.backupFolderId.isEmpty) {
        _emitBackupError('Failed to initialize Google Drive backup folder');
        return;
      }

      final (encryptedData, err) = await _encryptBackups(backups);
      if (err != null || encryptedData == null) return;

      await _saveToGoogleDrive(encryptedData);
    } catch (e) {
      debugPrint('Error saving to Google Drive: $e');
      _emitBackupError('Failed to save Google Drive backup');
    }
  }

  Future<((String, String)?, Err?)> _encryptBackups(
    List<Backup> backups,
  ) async {
    try {
      final (encData, err) = await _manager.encryptBackups(
        backups: backups,
        derivationPath: _kDerivationPath,
      );

      if (err != null || encData == null) {
        return (null, err);
      }

      return (encData, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<void> _saveToFileSystem((String, String) encryptedData) async {
    final (filePath, errSave) = await _manager.saveEncryptedBackup(
      encrypted: encryptedData.$2,
    );

    if (errSave != null) {
      _emitBackupError('Save failed: ${errSave.message}');
      return;
    }

    final fileName = filePath?.split('/').last;
    final backupId = fileName?.split('_').last.split('.').first;
    if (backupId == null) {
      _emitBackupError('Failed to extract backup ID');
      return;
    }

    final backupSalt = jsonDecode(encryptedData.$2)['salt'] as String;

    emit(
      state.copyWith(
        backupId: backupId,
        backupKey: encryptedData.$1,
        backupFolderPath: filePath ?? '',
        backupSalt: backupSalt,
        savingBackups: false,
        lastBackupAttempt: DateTime.now(),
      ),
    );
  }

  Future<void> _saveToGoogleDrive((String, String) encryptedData) async {
    try {
      final backupSalt = jsonDecode(encryptedData.$2)['salt'] as String;

      final (filePath, error) = await _driveManager.saveEncryptedBackup(
        encrypted: encryptedData.$2,
        backupFolder: state.backupFolderId,
      );

      if (error != null) {
        debugPrint('Error saving to Google Drive: ${error.message}');
        _emitBackupError('Failed to save to Google Drive');
        return;
      }
      final fileName = filePath?.split('/').last;
      final backupId = fileName?.split('_').last.split('.').first;
      if (backupId == null || fileName == null) {
        debugPrint('Failed to extract backup ID');
        _emitBackupError('Failed to save to Google Drive');
        return;
      }
      emit(
        state.copyWith(
          backupId: backupId,
          backupKey: encryptedData.$1,
          backupFolderPath: fileName,
          backupSalt: backupSalt,
          savingBackups: false,
          lastBackupAttempt: DateTime.now(),
        ),
      );
    } catch (e) {
      _emitBackupError('Failed to save to Google Drive: $e');
    }
  }

  Future<void> connectToGoogleDrive() async {
    try {
      final (folderId, err) = await _driveManager.connect();
      if (err != null) {
        _emitBackupError('Failed to connect to Google Drive: ${err.message}');
        return;
      }
      emit(
        state.copyWith(
          backupFolderId: folderId ?? '',
          errorSavingBackups: '',
        ),
      );
    } catch (e) {
      _emitBackupError('Google Drive connection error: $e');
    }
  }

  Future<List<Backup>> _createBackupsForAllWallets() async {
    final backups = <Backup>[];

    try {
      for (final wallet in _wallets) {
        final backup = await _createBackupForWallet(wallet);
        if (backup != null) backups.add(backup);
      }
      return backups;
    } catch (e) {
      _emitBackupError('Failed to create backups: $e');
      return [];
    }
  }

  Future<Backup?> _createBackupForWallet(Wallet wallet) async {
    try {
      final (seed, err) = await _loadWalletSeed(wallet);
      if (err != null || seed == null) {
        _emitBackupError('Failed to read wallet ${wallet.name}: $err');
        return null;
      }

      final backup = Backup(
        name: wallet.name ?? '',
        network: wallet.network.name,
        mnemonicFingerPrint: wallet.mnemonicFingerprint,
        layer: wallet.baseWalletType.name,
        script: wallet.scriptType.name,
        type: wallet.type.name,
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
    emit(
      state.copyWith(
        savingBackups: false,
        errorSavingBackups: message,
      ),
    );
  }

  void disconnectGoogleDrive() {
    _driveManager.disconnect();
    emit(state.copyWith(backupFolderId: ''));
  }

  void clearError() => emit(
        state.copyWith(
          errTestingBackup: '',
          errorLoadingBackups: '',
          errorSavingBackups: '',
        ),
      );

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
}
