import 'dart:async';
import 'dart:convert';
import 'package:bb_mobile/core/recoverbull/data/models/drive_file_metadata_model.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class GoogleDriveAppDatasource {
  static final _google = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/drive.appdata'],
  );

  drive.DriveApi? _driveApi;

  void _checkConnection() {
    if (_driveApi == null) throw 'unauthenticated';
  }

  Future<void> connect() async {
    try {
      final account = await _google.signIn();
      if (account == null) throw 'Sign-in failed';

      final client = await _google.authenticatedClient();
      if (client == null) throw 'Failed to get authenticated client';

      _driveApi = drive.DriveApi(client);
    } catch (e) {
      log.severe('Google Sign-in error: $e');
      await disconnect();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await _google.disconnect();
    _driveApi = null;
  }

  Future<List<DriveFileMetadataModel>> fetchAllMetadata() async {
    _checkConnection();
    final response = await _driveApi!.files.list(
      spaces: 'appDataFolder',
      q: "mimeType='application/json' and trashed=false",
      $fields: 'files(id, name, createdTime)',
      orderBy: 'createdTime desc',
    );
    return response.files
            ?.map((file) => DriveFileMetadataModel.fromDriveFile(file))
            .toList() ??
        [];
  }

  Future<List<int>> fetchFileContent(String fileId) async {
    _checkConnection();
    final media =
        await _driveApi!.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

    final bytes = await media.stream.fold<List<int>>(
      <int>[],
      (previous, element) => previous..addAll(element),
    );
    return bytes;
  }

  Future<void> trash(String fileId) async {
    _checkConnection();
    await _driveApi!.files.delete(fileId);
  }

  Future<void> store(String content) async {
    _checkConnection();
    final vault = EncryptedVault(file: content);
    final filename = vault.filename;
    final jsonVault = vault.toFile();

    final file =
        drive.File()
          ..name = filename
          ..mimeType = 'application/json'
          ..parents = ['appDataFolder'];

    await _driveApi!.files.create(
      file,
      uploadMedia: drive.Media(
        Stream.value(utf8.encode(jsonVault)),
        jsonVault.length,
      ),
    );
  }
}
