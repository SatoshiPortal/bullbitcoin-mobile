import 'package:http/http.dart' as http;
import '../mappers/encrypted_vault_mapper.dart';
import 'dart:async';
import 'dart:convert';
import 'package:bull_logger/bull_logger.dart';
import '../models/drive_file_metadata_model.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class GoogleDriveAppDatasource {
  static const metadataFields =
      'nextPageToken,files(id, name, createdTime, modifiedTime)';
  static const metadataPageSize = 1000;
  final LogSink log;
  final Future<GoogleDriveMetadataPage> Function(String? pageToken)? pageLister;
  static final _sharedGoogle = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/drive.appdata'],
  );
  final GoogleSignIn _google;

  drive.DriveApi? _driveApi;
  http.Client? _client;
  String? _authenticatedAccount;
  final Future<http.Client?> Function() _authenticatedClient;
  bool _disposed = false;

  GoogleDriveAppDatasource({
    required this.log,
    this.pageLister,
    GoogleSignIn? googleSignIn,
    Future<http.Client?> Function()? authenticatedClient,
  }) : _google = googleSignIn ?? _sharedGoogle,
       _authenticatedClient =
           authenticatedClient ??
           (() => (googleSignIn ?? _sharedGoogle).authenticatedClient());

  void _checkConnection() {
    if (_disposed) throw StateError('Drive datasource is disposed');
    if (_driveApi == null) throw Exception('Drive authentication unavailable');
  }

  Future<void> connect() async {
    if (_disposed) throw StateError('Drive datasource is disposed');
    try {
      final account = await _google.signIn();
      if (account == null) throw Exception('Drive sign-in unavailable');

      final client = await _authenticatedClient();
      if (client == null) {
        throw Exception('Drive authenticated client unavailable');
      }

      _replaceClient(client, account.email);
    } on Exception catch (e) {
      log.error(
        'recoverbull.drive.sign_in.unexpected error_type=${e.runtimeType}',
        trace: StackTrace.current,
      );
      // Only forget the cached client: disconnecting would revoke the user's
      // Drive grant over what may be a transient network or Play Services
      // failure.
      _clearClient();
      rethrow;
    }
  }

  Future<String?> connectSilently() async {
    if (_disposed) throw StateError('Drive datasource is disposed');
    try {
      final account = await _google.signInSilently(suppressErrors: false);
      if (account == null) {
        // A real sign-out is different from a transient probe failure.
        _clearClient();
        return null;
      }
      if (_authenticatedAccount != null &&
          _authenticatedAccount != account.email) {
        // Never let an authenticated operation reuse the previous account.
        _clearClient();
      }
      final client = await _authenticatedClient();
      if (client == null) return null;
      _replaceClient(client, account.email);
      return account.email;
    } on Exception catch (error) {
      log.warning(
        'recoverbull.drive.silent_sign_in.unavailable '
        'error_type=${error.runtimeType}',
      );
      final currentAccount = _google.currentUser;
      if (currentAccount == null ||
          currentAccount.email != _authenticatedAccount) {
        _clearClient();
      }
      // Discovery failed to authenticate. Preserve any foreground client for
      // the same account; the discovery session still receives no capability.
      return null;
    }
  }

  Future<void> disconnect() async {
    try {
      await _google.disconnect();
    } finally {
      _clearClient();
    }
  }

  void _replaceClient(http.Client client, String account) {
    if (_disposed || _google.currentUser?.email != account) {
      if (!identical(_client, client)) _closeClient(client);
      _clearClient();
      throw const _DriveAuthenticationCancelledException();
    }
    final previous = _client;
    _client = client;
    _authenticatedAccount = account;
    _driveApi = drive.DriveApi(client);
    if (previous != null && !identical(previous, client)) {
      _closeClient(previous);
    }
  }

  void _clearClient() {
    final previous = _client;
    _client = null;
    _driveApi = null;
    _authenticatedAccount = null;
    if (previous != null) _closeClient(previous);
  }

  void _closeClient(http.Client client) {
    try {
      client.close();
    } on Exception {
      log.warning('recoverbull.drive.client.close_failed');
    }
  }

  /// Releases transport resources without revoking the user's Drive grant.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _clearClient();
  }

  Future<List<DriveFileMetadataModel>> fetchAllMetadata() async {
    if (pageLister == null) _checkConnection();
    final result = <DriveFileMetadataModel>[];
    final seenTokens = <String>{};
    String? token;
    while (true) {
      final page = await fetchMetadataPage(token);
      result.addAll(page.files);
      final next = page.nextPageToken;
      if (next == null || next.isEmpty) return result;
      if (!seenTokens.add(next)) {
        throw const FormatException('Drive pagination repeated a page token');
      }
      token = next;
    }
  }

  Future<GoogleDriveMetadataPage> fetchMetadataPage(String? pageToken) {
    if (pageLister != null) return pageLister!(pageToken);
    _checkConnection();
    return _listPageFromApi(pageToken);
  }

  Future<GoogleDriveMetadataPage> _listPageFromApi(String? pageToken) async {
    final response = await _driveApi!.files.list(
      spaces: 'appDataFolder',
      q: "mimeType='application/json' and trashed=false",
      $fields: metadataFields,
      orderBy: 'createdTime desc',
      pageToken: pageToken,
      pageSize: metadataPageSize,
    );
    return GoogleDriveMetadataPage(
      files:
          response.files?.map(DriveFileMetadataModel.fromDriveFile).toList() ??
          const [],
      nextPageToken: response.nextPageToken,
    );
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
    final vault = EncryptedVaultMapper.parse(content);
    final filename = vault.filename;
    final jsonVault = EncryptedVaultMapper.fromEntity(vault).toFile();

    final file = drive.File()
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

final class GoogleDriveMetadataPage {
  final List<DriveFileMetadataModel> files;
  final String? nextPageToken;

  const GoogleDriveMetadataPage({required this.files, this.nextPageToken});
}

final class _DriveAuthenticationCancelledException implements Exception {
  const _DriveAuthenticationCancelledException();
}
