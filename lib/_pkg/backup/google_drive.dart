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
  static final _google = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/drive.appdata'],
  );
  static const _errorMessages = {
    'connection': 'Google Sign-In was cancelled or failed. Please try again.',
    'auth': 'Failed to authenticate with Google.',
    'notConnected': 'Not connected to Google Drive',
    'noBackups': 'No backups found',
  };

  DriveApi? _api;

  Future<(DriveApi?, Err?)> connect() async {
    GoogleSignInAccount? account;
    try {
      account = await _google.signInSilently();
    } catch (e) {
      debugPrint('Silent sign-in failed, trying interactive sign-in: $e');
      account = await _google.signIn();
    }
    // If we still don't have an account after both attempts
    if (account == null) {
      return (null, Err(_errorMessages['connection']!));
    }

    try {
      final client = await _google.authenticatedClient();
      if (client == null) return (null, Err(_errorMessages['auth']!));
      _api = DriveApi(client);
      return (_api, null);
    } catch (e) {
      debugPrint('Connection error: $e');
      await disconnect();
      return (null, Err('Connection error: $e'));
    }
  }

  Future<void> disconnect() async {
    await _google.disconnect();
    _api = null;
  }

  // Helper method to check connection and reconnect if needed
  Future<(DriveApi?, Err?)> _getApi() async {
    if (_api == null) {
      final (api, err) = await connect();
      if (err != null) return (null, err);
    }
    return (_api, null);
  }

  // Update _withConnection to use _getApi
  Future<(T?, Err?)> _withConnection<T>(
    Future<(T?, Err?)> Function(DriveApi api) operation,
  ) async {
    final (api, err) = await _getApi();
    if (err != null) return (null, err);
    if (api == null) return (null, Err('Not connected'));

    try {
      return await operation(api);
    } catch (e) {
      // Only disconnect on auth errors
      if (_isAuthError(e)) {
        await disconnect();
      }
      return (null, Err('Operation failed: $e'));
    }
  }

  bool _isAuthError(dynamic error) {
    // Add logic to detect auth-related errors
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('unauthorized') ||
        errorStr.contains('unauthenticated') ||
        errorStr.contains('invalid credentials');
  }

  @override
  Future<(String?, Err?)> saveEncryptedBackup({
    required String encrypted,
    String backupFolder = defaultBackupPath,
  }) async {
    return _withConnection((api) async {
      try {
        final data = jsonDecode(encrypted) as Map<String, dynamic>;
        final encryptedData = data['encrypted'] as String;
        final decodedEncrypted =
            jsonDecode(encryptedData) as Map<String, dynamic>;
        final backupId = decodedEncrypted['id']?.toString();

        if (backupId == null) return (null, Err('Invalid backup data'));

        final filename =
            '${DateTime.now().millisecondsSinceEpoch}_$backupId.json';
        final file = File()
          ..name = filename
          ..mimeType = 'application/json'
          ..parents = ['appDataFolder'];

        await api.files.create(
          file,
          uploadMedia: Media(
            Stream.value(utf8.encode(encrypted)),
            encrypted.length,
          ),
        );

        return (filename, null);
      } catch (e) {
        return (null, Err('Save failed: $e'));
      }
    });
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

  Future<(List<File>?, Err?)> loadAllEncryptedBackupFiles() async {
    return _withConnection((api) async {
      try {
        final response = await api.files.list(
          spaces: 'appDataFolder',
          q: "mimeType='application/json' and trashed=false",
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
    required String path,
  }) async {
    return _withConnection((api) async {
      try {
        // Find files in appDataFolder using spaces: 'appDataFolder' and query by name
        final files = await api.files.list(
          spaces: 'appDataFolder',
          q: "name = '$path' and trashed = false",
          $fields: 'files(id)',
        );

        final firstFile = files.files?.firstOrNull;
        if (firstFile == null) {
          return (null, Err('Backup not found'));
        }

        await api.files.update(
          File()..trashed = true, // Set trashed to true to move to trash
          firstFile.id!,
        );
        return (path, null);
      } catch (e) {
        return (null, Err('Failed to remove backup: $e'));
      }
    });
  }

  Future<(List<int>?, Err?)> fetchMediaStream({required File file}) async {
    return _withConnection((api) async {
      try {
        final media = await api.files.get(
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
    });
  }
}
