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
  final Future<GoogleDriveMetadataPage> Function(String? pageToken)? pageLister;
  static const _scopes = ['https://www.googleapis.com/auth/drive.appdata'];
  static final _sharedGoogle = GoogleSignIn.instance;
  static final Future<void> _sharedInitialization = _sharedGoogle.initialize();
  final GoogleSignIn _google;

  drive.DriveApi? _driveApi;
  http.Client? _client;
  String? _authenticatedAccount;
  final Future<http.Client?> Function()? _authenticatedClient;
  Future<void>? _initialization;
  GoogleSignInAccount? _currentAccount;
  int _authenticationEpoch = 0;
  late final StreamSubscription<GoogleSignInAuthenticationEvent>
  _authentication;
  bool _disposed = false;

  GoogleDriveAppDatasource({
    this.pageLister,
    GoogleSignIn? googleSignIn,
    this._authenticatedClient,
  }) : _google = googleSignIn ?? _sharedGoogle {
    _authentication = _google.authenticationEvents.listen(
      (event) {
        switch (event) {
          case GoogleSignInAuthenticationEventSignIn(:final user):
            if (_currentAccount?.email != user.email) _authenticationEpoch++;
            _currentAccount = user;
            if (_authenticatedAccount != null &&
                _authenticatedAccount != user.email) {
              _clearClient();
            }
          case GoogleSignInAuthenticationEventSignOut():
            _authenticationEpoch++;
            _currentAccount = null;
            _clearClient();
        }
      },
      onError: (Object error, StackTrace stack) {
        log.warning('recoverbull.drive.authentication.unavailable');
      },
    );
  }

  Future<void> _initialize() =>
      _initialization ??= identical(_google, _sharedGoogle)
      ? _sharedInitialization
      : _google.initialize();

  Future<http.Client?> _clientFor(
    GoogleSignInAccount account, {
    required bool interactive,
    required int epoch,
  }) async {
    final authenticate = _authenticatedClient;
    if (authenticate != null) return await authenticate();
    final authorization = await account.authorizationClient
        .authorizationForScopes(_scopes);
    _checkAccount(account.email, epoch);
    if (authorization != null) return authorization.authClient(scopes: _scopes);
    if (!interactive) return null;
    return (await account.authorizationClient.authorizeScopes(_scopes))
        .authClient(scopes: _scopes);
  }

  void _acceptAccount(GoogleSignInAccount? account, int epoch) {
    if (_disposed) throw const _DriveAuthenticationCancelledException();
    if (_authenticationEpoch == epoch) {
      _currentAccount = account;
    } else if (_authenticationEpoch != epoch + 1 ||
        _currentAccount?.email != account?.email) {
      throw const _DriveAuthenticationCancelledException();
    }
  }

  void _checkAccount(String account, int epoch) {
    if (_disposed ||
        _authenticationEpoch != epoch ||
        _currentAccount?.email != account) {
      throw const _DriveAuthenticationCancelledException();
    }
  }

  drive.DriveApi get _connectedApi {
    _checkConnection();
    final api = _driveApi;
    if (api == null) {
      throw const FormatException('Drive connection unavailable');
    }
    return api;
  }

  void _checkConnection() {
    if (_disposed) throw StateError('Drive datasource is disposed');
    if (_driveApi == null) throw Exception('Drive authentication unavailable');
  }

  Future<void> connect() async {
    if (_disposed) throw StateError('Drive datasource is disposed');
    try {
      await _initialize();
      if (_disposed) throw const _DriveAuthenticationCancelledException();
      final beforeAuthentication = _authenticationEpoch;
      final account = await _google.authenticate(scopeHint: _scopes);
      _acceptAccount(account, beforeAuthentication);
      final epoch = _authenticationEpoch;

      final client = await _clientFor(account, interactive: true, epoch: epoch);
      if (client == null) {
        throw Exception('Drive authenticated client unavailable');
      }

      _replaceClient(client, account.email, epoch);
    } on Exception {
      log.warning('recoverbull.drive.operation.failed');
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
      await _initialize();
      if (_disposed) throw const _DriveAuthenticationCancelledException();
      final beforeAuthentication = _authenticationEpoch;
      final attempt = _google.attemptLightweightAuthentication(
        reportAllExceptions: true,
      );
      // Event-only platforms cannot grant a discovery capability synchronously.
      // A pending attempt is not evidence that the user signed out.
      if (attempt == null) return null;
      final account = await attempt;
      _acceptAccount(account, beforeAuthentication);
      final epoch = _authenticationEpoch;
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
      final client = await _clientFor(
        account,
        interactive: false,
        epoch: epoch,
      );
      if (client == null) return null;
      _replaceClient(client, account.email, epoch);
      return account.email;
    } on Exception {
      log.warning('recoverbull.drive.discovery.unavailable');
      final currentAccount = _currentAccount;
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
      await _initialize();
      await _google.disconnect();
      _currentAccount = null;
    } finally {
      _clearClient();
    }
  }

  void _replaceClient(http.Client client, String account, int epoch) {
    if (_disposed ||
        _authenticationEpoch != epoch ||
        _currentAccount?.email != account) {
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
    unawaited(_authentication.cancel());
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
    final lister = pageLister;
    if (lister != null) return lister(pageToken);
    _checkConnection();
    return _listPageFromApi(pageToken);
  }

  Future<GoogleDriveMetadataPage> _listPageFromApi(String? pageToken) async {
    final response = await _connectedApi.files.list(
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
    final response = await _connectedApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );
    if (response is! drive.Media) {
      throw const FormatException('Invalid Drive media');
    }
    final media = response;

    final bytes = await media.stream.fold<List<int>>(<int>[], (
      previous,
      element,
    ) {
      if (previous.length + element.length > 2 * 1024 * 1024) {
        throw const FormatException('Drive vault exceeds size limit');
      }
      return previous..addAll(element);
    });
    return bytes;
  }

  Future<void> trash(String fileId) async {
    _checkConnection();
    await _connectedApi.files.delete(fileId);
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

    await _connectedApi.files.create(
      file,
      uploadMedia: drive.Media(
        Stream.value(utf8.encode(jsonVault)),
        utf8.encode(jsonVault).length,
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
