import 'dart:async';
import 'dart:convert';

import 'package:bb_mobile/_pkg/backup/_interface.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart';

class GoogleDriveBackupManager extends IBackupManager {
  static final _google = GoogleSignIn(scopes: [DriveApi.driveFileScope]);
  static const _errorMessages = {
    'connection': 'Google Sign-In was cancelled or failed. Please try again.',
    'auth': 'Failed to authenticate with Google.',
    'notConnected': 'Not connected to Google Drive',
    'noBackups': 'No backups found',
  };

  DriveApi? _api;
  GoogleSignInAccount? _account;

  Future<(String?, Err?)> connect() async {
    try {
      final account = await _google.signIn();
      if (account == null) return (null, Err(_errorMessages['connection']!));

      final client = await _google.authenticatedClient();
      if (client == null) return (null, Err(_errorMessages['auth']!));

      _api = DriveApi(client);
      _account = account;

      return await _setupBackupFolder();
    } catch (e) {
      await disconnect();
      return (null, Err('Connection error: $e'));
    }
  }

  Future<void> disconnect() async {
    await _google.disconnect();
    _api = null;
    _account = null;
  }

  Future<void> dispose() async {
    await disconnect();
  }

  // Helper method to ensure connection
  Future<(T?, Err?)> _withConnection<T>(
    Future<(T?, Err?)> Function(DriveApi api) operation,
  ) async {
    if (_api == null) return (null, Err('Not connected'));

    try {
      return await operation(_api!);
    } catch (e) {
      await disconnect();
      return (null, Err('Operation failed: $e'));
    }
  }

  @override
  Future<(String?, Err?)> saveEncryptedBackup({
    required String encrypted,
    String backupFolder = defaultBackupPath,
  }) async {
    return _withConnection((api) async {
      try {
        final data = jsonDecode(encrypted) as Map<String, dynamic>;
        final backupId = data['id']?.toString();
        if (backupId == null) return (null, Err('Invalid backup data'));

        final filename =
            '${DateTime.now().millisecondsSinceEpoch}_$backupId.json';
        final file = File()
          ..name = filename
          ..parents = [backupFolder];

        await api.files.create(
          file,
          uploadMedia:
              Media(Stream.value(utf8.encode(encrypted)), encrypted.length),
        );

        return (filename, null);
      } catch (e) {
        return (null, Err('Save failed: $e'));
      }
    });
  }

  Future<(String?, Err?)> _setupBackupFolder() async {
    try {
      const folderName = '.$defaultBackupPath';
      final existing = await _api!.files.list(
        q: "name = '$folderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
        spaces: 'drive',
        $fields: 'files(id)',
      );
      if (existing.files?.isNotEmpty == true) {
        final backupFolderId = existing.files!.first.id;
        return (backupFolderId, null);
      }

      final folderMetadata = File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder'
        ..appProperties = {'created': DateTime.now().toIso8601String()};
      final folder = await _api!.files.create(folderMetadata);

      final (success, err) = await _applyFolderPermissions(folder.id!);
      if (!success) {
        return (null, err);
      }

      return (folder.id, null);
    } catch (e) {
      return (null, Err('Failed to initialize backup folder: $e'));
    }
  }

  Future<(bool, Err?)> _applyFolderPermissions(String folderId) async {
    try {
      await _api!.permissions.create(
        Permission()
          ..role = 'owner'
          ..type = 'user'
          ..emailAddress = _account!.email,
        folderId,
        transferOwnership: true,
      );
      return (true, null);
    } catch (e) {
      return (false, Err('Failed to set folder permissions: $e'));
    }
  }

  @override
  Future<(Map<String, dynamic>?, Err?)> loadEncryptedBackup({
    required String encrypted,
  }) async {
    try {
      final decodeEncryptedFile = jsonDecode(encrypted) as Map<String, dynamic>;
      return (decodeEncryptedFile, null);
    } catch (e) {
      debugPrint('Failed to decode backup: $e');
      return (null, Err('Failed to decode backup'));
    }
  }

  Future<(List<File>?, Err?)> loadAllEncryptedBackupFiles({
    required String backupFolder,
  }) async {
    return _withConnection((api) async {
      try {
        final response = await api.files.list(
          q: "'$backupFolder' in parents and trashed = false",
          spaces: 'drive',
          $fields: 'files(id, name, createdTime)',
          orderBy: 'createdTime desc',
        );

        final files = response.files;
        if (files == null || files.isEmpty) {
          return (null, Err(_errorMessages['noBackups']!));
        }

        return (files, null);
      } catch (e) {
        return (null, Err('Failed to load backups: $e'));
      }
    });
  }

  @override
  Future<(String?, Err?)> removeEncryptedBackup({
    required String backupName,
    String backupFolder = defaultBackupPath,
  }) async {
    return _withConnection((api) async {
      try {
        final files = await api.files.list(
          q: "'$backupFolder' in parents and name = '$backupName' and trashed = false",
          spaces: 'drive',
          $fields: 'files(id)',
        );

        final firstFile = files.files?.firstOrNull;
        if (firstFile == null) {
          return (null, Err('Backup not found'));
        }

        await api.files.delete(firstFile.id!);
        return (backupName, null);
      } catch (e) {
        return (null, Err('Failed to remove backup: $e'));
      }
    });
  }

  Future<(List<int>?, Err?)> fetchMediaStream({required File file}) async {
    if (_api == null) return (null, Err(_errorMessages['notConnected']!));

    try {
      final media = await _api!.files.get(
        file.id!,
        downloadOptions: DownloadOptions.fullMedia,
      ) as Media;

      final bytes = await media.stream.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );

      return (bytes, null);
    } catch (e) {
      return (null, Err('Failed to fetch backup data: $e'));
    }
  }
}
