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
import 'package:bb_mobile/home/bloc/home_bloc.dart';
import 'package:bb_mobile/home/bloc/home_event.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/wallet_settings/bloc/backup_settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

  @override
  Future<void> close() async {
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
          errTestingBackup: error ?? 'Seed data not found',
          loadingBackups: false,
        ),
      );
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

  Future<void> saveFileSystemBackup() async {
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

    if (_filePicker == null) {
      _emitBackupError('Failed to pick the file');
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

    try {
      final (savePath, pickErr) = await _filePicker.getDirectoryPath();
      if (pickErr != null) {
        _emitBackupError('Failed to select backup location');
        return;
      }

      if (savePath == null || savePath.isEmpty) {
        _emitBackupError('No location selected for backup');
        return;
      }

      // Use the selected path with the manager
      final (filePath, errSave) = await _manager.saveEncryptedBackup(
        encrypted: encryptedData.$2,
        backupFolder: savePath,
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
    } catch (e) {
      _emitBackupError('Failed to save backup: $e');
    }
  }

  Future<void> saveGoogleDriveBackup() async {
    if (!_canStartBackup()) {
      _emitBackupError('Please wait before attempting another backup');
      return;
    }

    emit(state.copyWith(savingBackups: true, errorSavingBackups: ''));

    try {
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
      );

      if (err != null || encData == null) {
        return (null, err);
      }

      return (encData, null);
    } catch (e) {
      return (null, Err(e.toString()));
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

  void disconnectGoogleDrive() {
    _driveManager.disconnect();
    emit(state.copyWith(backupFolderId: ''));
  }

// encrypted vault backup methods

  Future<void> fetchLatestBacup({bool forceRefresh = false}) async {
    try {
      if (!forceRefresh && state.loadedBackups.isNotEmpty) {
        emit(state.copyWith(loadingBackups: false));
        return;
      }

      emit(state.copyWith(loadingBackups: true));

      // Connect if needed
      if (state.backupFolderId.isEmpty) {
        final (folderId, err) = await _driveManager.connect();
        if (err != null) {
          emit(
            state.copyWith(
              loadingBackups: false,
              errorLoadingBackups: err.message,
            ),
          );
          return;
        }
        emit(state.copyWith(backupFolderId: folderId ?? ''));
      }

      // Ensure we have a folder ID
      if (state.backupFolderId.isEmpty) {
        emit(
          state.copyWith(
            loadingBackups: false,
            errorLoadingBackups: "Failed to initialize Google Drive folder",
          ),
        );
        return;
      }

      // Rest of the existing code...
      final (availableBackups, err) =
          await _driveManager.loadAllEncryptedBackupFiles(
        backupFolder: state.backupFolderId,
      );

      if (err != null) {
        debugPrint('Error loading backups: ${err.message}');
        emit(
          state.copyWith(
            loadingBackups: false,
            errorLoadingBackups: "Failed to get backup files",
          ),
        );
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
          emit(
            state.copyWith(
              loadingBackups: false,
              errorLoadingBackups: "Corrupted backup file",
            ),
          );
          return;
        }
        final (loadedBackupMetaData, mediaErr) =
            await _driveManager.fetchMediaStream(
          file: latestBackup,
        );

        if (mediaErr != null || loadedBackupMetaData == null) {
          emit(
            state.copyWith(
              loadingBackups: false,
              errorLoadingBackups: "Failed to load backup data",
            ),
          );
          return;
        }

        final (loadedBackup, err) = await _driveManager.loadEncryptedBackup(
          encrypted: utf8.decode(loadedBackupMetaData),
        );
        if (loadedBackup != null) {
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
      } else {
        emit(
          state.copyWith(
            loadingBackups: false,
            errorLoadingBackups: "Failed to get backup files",
          ),
        );
      }
    } catch (e) {
      debugPrint('Error loading backups: $e');
      emit(
        state.copyWith(
          loadingBackups: false,
          errorLoadingBackups: "Failed to get backup files",
        ),
      );
    }
  }

  Future<void> refreshBackups() => fetchLatestBacup(forceRefresh: true);

  void clearError() => emit(
        state.copyWith(
          errTestingBackup: '',
          errorLoadingBackups: '',
          errorSavingBackups: '',
        ),
      );

  Future<void> recoverFromFs() async {
    if (_filePicker == null) {
      return;
    }
    final (file, error) = await _filePicker.pickFile();

    if (error != null) {
      emit(state.copyWith(errorLoadingBackups: "Error picking file"));
      return;
    }

    if (file == null || file.isEmpty) {
      emit(state.copyWith(errorLoadingBackups: 'Corrupted backup file'));
      return;
    }
    final (loadedBackup, err) = await _manager.loadEncryptedBackup(
      encrypted: file,
    );
    if (loadedBackup != null) {
      final id = loadedBackup['id'] as String;

      debugPrint('Loaded backup: $id');
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

  Future<void> recoverBackup(String encrypted, String backupKey) async {
    emit(
      state.copyWith(
        loadingBackups: true,
        backupKey: backupKey,
        errorLoadingBackups: '',
      ),
    );

    if (state.backupKey.isEmpty) {
      emit(
        state.copyWith(
          loadingBackups: false,
          errorLoadingBackups: 'Backup key is missing',
        ),
      );
      return;
    }

    try {
      final decodeEncryptedFile = jsonDecode(encrypted) as Map<String, dynamic>;
      final id = decodeEncryptedFile['id']?.toString() ?? '';

      if (id.isEmpty) {
        emit(
          state.copyWith(
            loadingBackups: false,
            errorLoadingBackups: 'Invalid backup format',
          ),
        );
        return;
      }

      // Then decrypt the backup data
      final (backups, err) = await _manager.decryptBackups(
        encrypted: encrypted,
        backupKey: state.backupKey,
      );

      if (err != null || backups == null || backups.isEmpty) {
        debugPrint('Error loading backups: ${err?.message}');
        emit(
          state.copyWith(
            loadingBackups: false,
            errorLoadingBackups: err?.message ?? 'No wallets found in backup',
          ),
        );
        return;
      }

      // Process each backup
      for (final backup in backups) {
        await _processBackupRecovery(backup);
        if (state.errorLoadingBackups.isNotEmpty) {
          return;
        }
      }

      // Notify HomeBloc that wallets have been recovered
      locator<HomeBloc>().add(LoadWalletsFromStorage());
      await locator<WalletsStorageRepository>().sortWallets();
      emit(
        state.copyWith(
          loadingBackups: false,
          loadedBackups: backups,
          errorLoadingBackups: '',
        ),
      );
    } catch (e) {
      debugPrint('Recovery error: $e');
      emit(
        state.copyWith(
          loadingBackups: false,
          errorLoadingBackups: 'Recovery failed: $e',
        ),
      );
    }
  }

  Future<void> _processBackupRecovery(Backup backup) async {
    final network = BBNetwork.fromString(backup.network);
    final layer = _getLayer(backup.layer);
    final script = _getScript(backup.script);
    final type = _getWalletType(backup.type);

    if (layer == null || script == null || type == null) {
      emit(
        state.copyWith(
          errorLoadingBackups:
              'Invalid backup configuration for ${backup.network}',
          loadingBackups: false,
        ),
      );
      return;
    }

    await _addOrUpdateWallet(
      network,
      layer,
      script,
      type,
      backup.mnemonic.join(' '),
      backup.passphrase,
      backup.publicDescriptors,
    );
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

  Future<void> _addOrUpdateWallet(
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
      emit(
        state.copyWith(
          errorLoadingBackups: 'Failed to create seed',
          loadingBackups: false,
        ),
      );
      return;
    }

    try {
      await _walletSensRepository.newSeed(seed: seed);
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
        emit(
          state.copyWith(
            errorLoadingBackups: 'Failed to create wallet',
            loadingBackups: false,
          ),
        );
        return;
      }

      await _walletsStorageRepository.newWallet(wallet);
    } catch (e) {
      debugPrint('Wallet creation error: $e');
      emit(
        state.copyWith(
          errorLoadingBackups: 'Failed to save wallet: $e',
          loadingBackups: false,
        ),
      );
    }
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
}
