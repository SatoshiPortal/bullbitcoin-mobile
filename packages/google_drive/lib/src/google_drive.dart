import 'dart:async';

import 'package:bull_logger/bull_logger.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'google_drive_failure.dart';
import 'google_drive_file_metadata.dart';

class GoogleDrive {
  static const _metadataFields =
      'nextPageToken,files(id, name, createdTime, modifiedTime)';
  static const _metadataPageSize = 1000;
  static const _scopes = ['https://www.googleapis.com/auth/drive.appdata'];
  static final _sharedGoogle = GoogleSignIn(scopes: _scopes);
  final GoogleSignIn _google;

  drive.DriveApi? _driveApi;
  http.Client? _client;
  String? _authenticatedAccount;
  final Future<http.Client?> Function()? _authenticatedClient;
  GoogleSignInAccount? _currentAccount;
  int _authenticationEpoch = 0;
  late final StreamSubscription<GoogleSignInAccount?> _authentication;
  bool _disposed = false;

  GoogleDrive.open() : this._(_sharedGoogle);

  GoogleDrive._(this._google, {this._authenticatedClient}) {
    _currentAccount = _google.currentUser;
    _authentication = _google.onCurrentUserChanged.listen(
      (account) {
        if (account == null || _currentAccount?.email != account.email) {
          _authenticationEpoch++;
        }
        _currentAccount = account;
        if (account == null ||
            (_authenticatedAccount != null &&
                _authenticatedAccount != account.email)) {
          _clearClient();
        }
      },
      onError: (Object error, StackTrace stack) {
        log.warning('google_drive.authentication.unavailable');
      },
    );
  }

  /// Prompts for sign-in if necessary and opens the account's app folder.
  @useResult
  Future<Result<void, GoogleDriveFailure>> connect() => _run(_connect);

  /// Returns the authenticated account, or null when silent sign-in is
  /// unavailable. Silent sign-in avoids sign-in and token recovery prompts.
  @useResult
  Future<Result<String?, GoogleDriveFailure>> connectSilently() =>
      _run(_connectSilently);

  /// Revokes the user's grant. Use [dispose] to only release local resources.
  @useResult
  Future<Result<void, GoogleDriveFailure>> revokeAccess() =>
      _run(_revokeAccess);

  @useResult
  Future<Result<List<GoogleDriveFileMetadata>, GoogleDriveFailure>> listFiles({
    String? mimeType,
  }) => _run(() => _fetchAllMetadata(mimeType));

  @useResult
  Future<Result<GoogleDriveMetadataPage, GoogleDriveFailure>> listPage({
    String? pageToken,
    String? mimeType,
  }) => _run(() => _listPageFromApi(pageToken, mimeType));

  @useResult
  Future<Result<List<int>, GoogleDriveFailure>> readFile({
    required String fileId,
    required int maxBytes,
  }) => _run(() => _read(fileId, maxBytes));

  @useResult
  Future<Result<void, GoogleDriveFailure>> writeFile({
    required String filename,
    required List<int> bytes,
    required String mimeType,
  }) => _run(() => _write(filename, bytes, mimeType));

  @useResult
  Future<Result<void, GoogleDriveFailure>> deleteFile(String fileId) =>
      _run(() => _delete(fileId));

  Future<Result<T, GoogleDriveFailure>> _run<T>(
    Future<T> Function() action,
  ) async {
    if (_disposed) {
      return const Err(GoogleDriveDisposedFailure());
    }
    try {
      return Ok(await action());
    } on _DriveFileTooLargeException {
      return const Err(GoogleDriveTooLargeFailure());
    } on FormatException {
      return const Err(GoogleDriveInvalidResponseFailure());
    } on Exception {
      return Err(
        _disposed
            ? const GoogleDriveDisposedFailure()
            : const GoogleDriveUnavailableFailure(),
      );
    }
  }

  static String _escapeQueryValue(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

  Future<http.Client?> _clientFor(
    GoogleSignInAccount account, {
    required bool interactive,
    required int epoch,
  }) async {
    final authenticate = _authenticatedClient;
    if (authenticate != null) return await authenticate();
    // The v6 account.authentication getter always enables interactive recovery.
    // Request tokens directly so discovery cannot launch a recovery prompt.
    final tokens = await GoogleSignInPlatform.instance.getTokens(
      email: account.email,
      shouldRecoverAuth: interactive,
    );
    _checkAccount(account.email, epoch);
    final accessToken = tokens.accessToken;
    if (accessToken == null) return null;
    // Match the previous v2 bridge: platform tokens expose no expiry or refresh
    // token. Each connection requests its token from the platform.
    final credentials = auth.AccessCredentials(
      auth.AccessToken(
        'Bearer',
        accessToken,
        DateTime.now().toUtc().add(const Duration(days: 365)),
      ),
      null,
      _scopes,
    );
    return auth.authenticatedClient(
      http.Client(),
      credentials,
      closeUnderlyingClient: true,
    );
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

  ({drive.DriveApi api, String account, int epoch}) _connection() {
    final api = _driveApi;
    final account = _authenticatedAccount;
    if (_disposed || api == null || account == null) {
      throw const _DriveAuthenticationCancelledException();
    }
    return (api: api, account: account, epoch: _authenticationEpoch);
  }

  Future<void> _connect() async {
    if (_disposed) throw const _DriveAuthenticationCancelledException();
    try {
      final beforeAuthentication = _authenticationEpoch;
      final account = await _google.signIn();
      if (account == null) throw Exception('Drive sign-in unavailable');
      _acceptAccount(account, beforeAuthentication);
      final epoch = _authenticationEpoch;

      final client = await _clientFor(account, interactive: true, epoch: epoch);
      if (client == null) {
        throw Exception('Drive authenticated client unavailable');
      }

      _replaceClient(client, account.email, epoch);
    } on Exception {
      log.warning('google_drive.operation.failed');
      // Only forget the cached client: disconnecting would revoke the user's
      // Drive grant over what may be a transient network or Play Services
      // failure.
      _clearClient();
      rethrow;
    }
  }

  Future<String?> _connectSilently() async {
    if (_disposed) throw const _DriveAuthenticationCancelledException();
    try {
      final beforeAuthentication = _authenticationEpoch;
      final account = await _google.signInSilently(suppressErrors: false);
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
      log.warning('google_drive.discovery.unavailable');
      final currentAccount = _currentAccount;
      if (currentAccount == null ||
          currentAccount.email != _authenticatedAccount) {
        _clearClient();
      }
      // Discovery failed to authenticate. Preserve any foreground client for
      // the same account; the discovery session still receives no capability.
      rethrow;
    }
  }

  Future<void> _revokeAccess() async {
    try {
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
      log.warning('google_drive.client.close_failed');
    }
  }

  /// Releases transport resources without revoking the user's Drive grant.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_authentication.cancel());
    _clearClient();
  }

  Future<List<GoogleDriveFileMetadata>> _fetchAllMetadata(
    String? mimeType,
  ) async {
    final connection = _connection();
    final result = <GoogleDriveFileMetadata>[];
    final seenTokens = <String>{};
    String? token;
    while (true) {
      final page = await _listPageFromApi(token, mimeType);
      _checkAccount(connection.account, connection.epoch);
      result.addAll(page.files);
      final next = page.nextPageToken;
      if (next == null || next.isEmpty) return result;
      if (!seenTokens.add(next)) {
        throw const FormatException('Drive pagination repeated a page token');
      }
      token = next;
    }
  }

  Future<GoogleDriveMetadataPage> _listPageFromApi(
    String? pageToken,
    String? mimeType,
  ) async {
    final filter = mimeType == null
        ? 'trashed=false'
        : "mimeType='${_escapeQueryValue(mimeType)}' and trashed=false";
    final connection = _connection();
    final response = await connection.api.files.list(
      spaces: 'appDataFolder',
      q: filter,
      $fields: _metadataFields,
      orderBy: 'createdTime desc',
      pageToken: pageToken,
      pageSize: _metadataPageSize,
    );
    _checkAccount(connection.account, connection.epoch);
    return GoogleDriveMetadataPage(
      files: response.files?.map(decodeDriveFile).toList() ?? const [],
      nextPageToken: response.nextPageToken,
    );
  }

  Future<List<int>> _read(String fileId, int maxBytes) async {
    final connection = _connection();
    final response = await connection.api.files.get(
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
      if (previous.length + element.length > maxBytes) {
        throw const _DriveFileTooLargeException();
      }
      return previous..addAll(element);
    });
    _checkAccount(connection.account, connection.epoch);
    return bytes;
  }

  Future<void> _delete(String fileId) async {
    await _connection().api.files.delete(fileId);
  }

  Future<void> _write(String filename, List<int> bytes, String mimeType) async {
    final file = drive.File()
      ..name = filename
      ..mimeType = mimeType
      ..parents = ['appDataFolder'];

    await _connection().api.files.create(
      file,
      uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
    );
  }
}

final class GoogleDriveMetadataPage {
  final List<GoogleDriveFileMetadata> files;
  final String? nextPageToken;

  const GoogleDriveMetadataPage({required this.files, this.nextPageToken});
}

final class _DriveAuthenticationCancelledException implements Exception {
  const _DriveAuthenticationCancelledException();
}

final class _DriveFileTooLargeException implements Exception {
  const _DriveFileTooLargeException();
}

/// Opens a Drive transport with substitutes for platform authentication and HTTP.
@visibleForTesting
GoogleDrive openGoogleDriveForTesting({
  required GoogleSignIn googleSignIn,
  Future<http.Client?> Function()? authenticatedClient,
}) => GoogleDrive._(googleSignIn, authenticatedClient: authenticatedClient);
