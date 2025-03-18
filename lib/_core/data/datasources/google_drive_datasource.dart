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

class GoogleDriveDatasourceImpl implements GoogleDriveAppDatasource {
  static final _google = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/drive.appdata'],
  );

  drive.DriveApi? _driveApi;

  void _checkConnection() {
    if (_driveApi == null) throw 'unathenticated';
  }

  @override
  Future<void> connect() async {
    GoogleSignInAccount? account;
    try {
      account = await _google.signInSilently();
    } catch (e) {
      debugPrint('Silent sign-in failed, trying interactive sign-in: $e');
    }

    account ??= await _google.signIn();

    final client = await _google.authenticatedClient();
    if (account == null || client == null) throw 'authentication failed';
    _driveApi = drive.DriveApi(client);
  }

  @override
  Future<void> disconnect() async {
    await _google.disconnect();
    _driveApi = null;
  }

  @override
  Future<void> trash(String path) async {
    _checkConnection();
    final files = await _driveApi!.files.list(
      spaces: 'appDataFolder',
      q: "name = '$path' and trashed = false",
      $fields: 'files(id)',
    );

    final firstFile = files.files?.firstOrNull;
    if (firstFile == null) {
      throw "Backup file not found";
    }

    await _driveApi!.files.update(
      drive.File()..trashed = true, // Set trashed to true to move to trash
      firstFile.id!,
    );
    return;
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

    final files = response.files;
    if (files == null || files.isEmpty) {
      return [];
    } else {
      return files;
    }
  }

  @override
  Future<void> store(String content) async {
    return;
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
}
