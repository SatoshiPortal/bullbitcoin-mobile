import 'dart:async';
import 'dart:convert';

import 'package:bb_mobile/_pkg/backup/_interface.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:hex/hex.dart';

///TODO; Update it to select the cloud backup provider
class GoogleDriveBackupManager extends IBackupManager {
  static final _google = GoogleSignIn(scopes: [DriveApi.driveFileScope]);

  DriveApi? _api;
  GoogleSignInAccount? _account;

  Future<(String?, Err?)> connect() async {
    try {
      final account = await _google.signIn();
      if (account == null) {
        return (
          null,
          Err('Google Sign-In was cancelled or failed. Please try again.')
        );
      }

      final client = await _google.authenticatedClient();
      if (client == null) {
        return (null, Err('Failed to authenticate with Google.'));
      }

      _api = DriveApi(client);
      _account = account;

      final (folderId, err) = await _setupBackupFolder();
      if (err != null) {
        return (null, err);
      }
      return (folderId, null);
    } catch (e) {
      return (null, Err('An unexpected error occurred: $e'));
    }
  }

  Future<void> disconnect() async => _google.disconnect();

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
  Future<(String?, Err?)> saveEncryptedBackup({
    required String encrypted,
    String backupFolder = defaultBackupPath,
  }) async {
    if (_api == null) return (null, Err('Not connected to Google Drive'));

    try {
      final decodeEncryptedFile = jsonDecode(utf8.decode(HEX.decode(encrypted)))
          as Map<String, dynamic>;
      final backupId = decodeEncryptedFile['backupId']?.toString() ?? '';
      final now = DateTime.now();
      final formattedDate = now.millisecondsSinceEpoch;
      final filename = '${formattedDate}_$backupId.json';
      final file = File()
        ..name = filename
        ..parents = [backupFolder];

      final data = encrypted.codeUnits;
      await _api!.files.create(
        file,
        uploadMedia: Media(Stream.value(data), data.length),
      );

      return (filename, null);
    } catch (e) {
      return (null, Err('Failed to create backup: $e'));
    }
  }

  @override
  Future<(Map<String, dynamic>?, Err?)> loadEncryptedBackup({
    required String encrypted,
  }) async {
    try {
      final decodeEncryptedFile = jsonDecode(utf8.decode(HEX.decode(encrypted)))
          as Map<String, dynamic>;
      final id = decodeEncryptedFile['backupId'];
      if (id == null) {
        return (null, Err("Corrupted backup file"));
      }
      return (decodeEncryptedFile, null);
    } catch (e) {
      return (null, Err('Failed to read encrypted backup: $e'));
    }
  }

  Future<(Map<String, File>?, Err?)> loadAllEncryptedBackupFiles({
    required String backupFolder,
  }) async {
    if (_api == null) return (null, Err('Not connected to Google Drive'));

    try {
      final response = await _api!.files.list(
        q: "'$backupFolder' in parents and trashed = false",
        spaces: 'drive',
        $fields: 'files(id, name, createdTime)',
        orderBy: 'createdTime desc',
      );

      if (response.files == null || response.files!.isEmpty) {
        return (null, Err('No backups found'));
      }

      final backups = <String, File>{};
      for (final file in response.files!) {
        backups[file.name!] = file;
      }

      return (backups, null);
    } catch (e) {
      return (null, Err('Failed to load backups: $e'));
    }
  }

  @override
  Future<(String?, Err?)> removeEncryptedBackup({
    required String backupName,
    String backupFolder = defaultBackupPath,
  }) async {
    if (_api == null) return (null, Err('Not connected to Google Drive'));

    try {
      final response = await _api!.files.list(
        q: "'$backupFolder' in parents and name = '$backupName' and trashed = false",
        spaces: 'drive',
        $fields: 'files(id)',
      );

      if (response.files == null || response.files!.isEmpty) {
        return (null, Err('Backup not found'));
      }

      await _api!.files.delete(response.files!.first.id!);
      return (backupName, null);
    } catch (e) {
      return (null, Err('Failed to remove backup: $e'));
    }
  }

  Future<List<int>> fetchMediaStream({required File file}) async {
    final media = await _api!.files.get(
      file.id!,
      downloadOptions: DownloadOptions.fullMedia,
    ) as Media;

    final completer = Completer<List<int>>();
    final bytes = <int>[];

    media.stream.listen(
      bytes.addAll,
      onError: (error) => completer.completeError(
        Exception('Error streaming backup data: $error'),
      ),
      onDone: () => completer.complete(bytes),
      cancelOnError: true,
    );
    return completer.future;
  }
}
