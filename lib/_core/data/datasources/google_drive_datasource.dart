import 'dart:async';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

abstract class GoogleDriveAppDatasource {
  Future<void> connect();
  Future<void> disconnect();
  Future<List<int>> fetchContent(String fileId);
  Future<List<drive.File>> fetchAll();
  Future<void> store(String content);
  Future<void> trash(String path);
}

class GoogleDriveAppDatasourceImpl implements GoogleDriveAppDatasource {
  static final _google = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/drive.appdata'],
  );

  drive.DriveApi? _driveApi;

  void _checkConnection() {
    if (_driveApi == null) throw 'unauthenticated';
  }

  @override
  Future<void> connect() async {
    try {
      GoogleSignInAccount? account = await _google.signInSilently();

      if (account == null) {
        debugPrint('Silent sign-in failed, attempting interactive sign-in...');
        account = await _google.signIn();
      }

      if (account == null) {
        throw 'Sign-in failed';
      }

      final client = await _google.authenticatedClient();
      if (client == null) throw 'Failed to get authenticated client';

      _driveApi = drive.DriveApi(client);
    } catch (e) {
      debugPrint('Google Sign-in error: $e');
      await disconnect();
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    await _google.disconnect();
    _driveApi = null;
  }

  @override
  Future<List<drive.File>> fetchAll() async {
    _checkConnection();
    final response = await _driveApi!.files.list(
      spaces: 'appDataFolder',
      q: "mimeType='application/json' and trashed=false",
      $fields: 'files(id, name, createdTime)',
      orderBy: 'createdTime desc',
    );
    return response.files ?? [];
  }

  @override
  Future<List<int>> fetchContent(String fileId) async {
    _checkConnection();
    final media = await _driveApi!.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = await media.stream.fold<List<int>>(
      <int>[],
      (previous, element) => previous..addAll(element),
    );
    return bytes;
  }

  @override
  Future<void> trash(String path) async {
    _checkConnection();
    final files = await _driveApi!.files.list(
      spaces: 'appDataFolder',
      q: "name = '$path' and trashed = false",
      $fields: 'files(id)',
    );

    final fileId = files.files?.firstOrNull?.id;
    if (fileId == null) throw "Backup file not found";

    await _driveApi!.files.update(
      drive.File()..trashed = true,
      fileId,
    );
  }

  @override
  Future<void> store(String content) async {
    // Implement if needed
    return;
  }
}
