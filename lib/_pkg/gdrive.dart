import 'dart:async';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/rendering.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart';

class GoogleDriveApi {
  static final google = GoogleSignIn(scopes: [DriveApi.driveFileScope]);

  final DriveApi api;
  final GoogleSignInAccount account;
  String? _backupFolderId;

  GoogleDriveApi._(this.api, this.account);

  static Future<(GoogleDriveApi?, Err?)> connect() async {
    try {
      final account = await google.signIn();
      if (account == null) {
        return (
          null,
          Err('Google Sign-In was cancelled or failed. Please try again.')
        );
      }

      final client = await google.authenticatedClient();
      if (client == null) {
        return (
          null,
          Err('Failed to authenticate with Google. Please check your internet connection and try again.')
        );
      }

      final api = DriveApi(client);
      final service = GoogleDriveApi._(api, account);
      final (success, err) = await service._setupBackupFolder();
      if (err != null) {
        return (null, err);
      }
      return (service, null);
    } catch (e) {
      return (null, Err('An unexpected error occurred: $e'));
    }
  }

  static Future<void> disconnect() async => google.disconnect();

  Future<(bool, Err?)> _setupBackupFolder() async {
    try {
      const folderName = '.$defaultBackupPath';
      final existing = await api.files.list(
        q: "name = '$folderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
        spaces: 'drive',
        $fields: 'files(id)',
      );
      if (existing.files?.isNotEmpty == true) {
        _backupFolderId = existing.files!.first.id;
        return (true, null);
      }

      final folderMetadata = File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder'
        ..appProperties = {
          'created': DateTime.now().toIso8601String(),
        };
      final folder = await api.files.create(folderMetadata);
      _backupFolderId = folder.id;

      final (success, err) = await _applyFolderPermissions(folder.id!);
      if (err != null) {
        return (false, err);
      }

      debugPrint('Initialized secure backup folder: $folderName');
      return (true, null);
    } catch (e) {
      return (false, Err('Failed to initialize backup folder: $e'));
    }
  }

  Future<(bool, Err?)> _applyFolderPermissions(String folderId) async {
    try {
      await api.permissions.create(
        Permission()
          ..role = 'owner'
          ..type = 'user'
          ..emailAddress = account.email,
        folderId,
        transferOwnership: true,
      );
      return (true, null);
    } catch (e) {
      return (false, Err('Failed to set folder permissions: $e'));
    }
  }

  Future<(File?, Err?)> _uploadBackupFile(
    String fileName,
    List<int> data,
  ) async {
    try {
      final file = File()
        ..name = fileName
        ..parents = [_backupFolderId!]
        ..appProperties = {
          'timestamp': DateTime.now().toIso8601String(),
        };
      final createdFile = await api.files.create(
        file,
        uploadMedia: Media(Stream.value(data), data.length),
      );
      return (createdFile, null);
    } catch (e) {
      return (null, Err('Failed to create backup: $e'));
    }
  }

  Future<(bool, Err?)> saveBackup(List<int> data, String fileName) async {
    final (file, err) = await _uploadBackupFile(fileName, data);
    if (err != null) {
      return (false, err);
    }
    debugPrint('Successfully saved backup: $fileName');
    return (true, null);
  }

  Future<(List<int>?, Err?)> loadBackupContent(File file) async {
    try {
      final media = await api.files.get(
        file.id!,
        downloadOptions: DownloadOptions.fullMedia,
      ) as Media;

      final data = await _fetchMediaStream(media);
      return (data, null);
    } catch (e) {
      return (null, Err('Error reading backup content: $e'));
    }
  }

  Future<List<int>> _fetchMediaStream(Media media) async {
    final completer = Completer<List<int>>();
    final bytes = <int>[];

    media.stream.listen(
      bytes.addAll,
      onError: (error) => completer
          .completeError(Exception('Error streaming backup data: $error')),
      onDone: () => completer.complete(bytes),
      cancelOnError: true,
    );

    return completer.future;
  }

  Future<(List<File>, Err?)> listAllBackupFiles() async {
    if (_backupFolderId == null) {
      return (<File>[], Err('Backup folder not initialized'));
    }
    try {
      final response = await api.files.list(
        q: "'$_backupFolderId' in parents and trashed = false",
        spaces: 'drive',
        $fields: 'files(id, name, createdTime, modifiedTime, appProperties)',
        orderBy: 'modifiedTime desc',
      );

      if (response.files == null || response.files!.isEmpty) {
        debugPrint('No metadata files found');
        return (<File>[], null);
      }

      return (response.files ?? <File>[], null);
    } catch (e) {
      return (<File>[], Err('Failed to list backups: $e'));
    }
  }
}
