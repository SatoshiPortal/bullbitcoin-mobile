import 'dart:convert';

import 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_actions.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_blob.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_donation_page.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_error.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_fallback_supervision.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_invoice.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_invoice_quote.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_invoice_actions.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_public_names.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_recovery_address.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_recovery_address_actions.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_registration.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_config.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

const Duration bullnymConnectTimeout = Duration(seconds: 10);
const Duration bullnymReceiveTimeout = Duration(seconds: 15);

class BullnymHttpClient implements BullnymClientPort {
  BullnymHttpClient({
    String baseUrl = bullnymDefaultBaseUrl,
    String publicBaseUrl = bullnymDefaultPublicBaseUrl,
    this._nowSecs = currentBullpayTimestampSecs,
  }) : _trustedPublicOrigin = _validatePublicOrigin(publicBaseUrl),
       _dio = _newDio(baseUrl);

  BullnymHttpClient.withDio(
    Dio dio, {
    String publicBaseUrl = bullnymDefaultPublicBaseUrl,
    this._nowSecs = currentBullpayTimestampSecs,
  }) : _trustedPublicOrigin = _validatePublicOrigin(publicBaseUrl),
       _dio = dio;

  final Dio _dio;
  final Uri _trustedPublicOrigin;
  // Invoice and identity-wide recovery-address actions are signed inside the
  // client (unlike donation-page actions, which are signed in their usecases),
  // so the client owns their timestamp; injected for deterministic tests.
  final int Function() _nowSecs;

  String get baseUrl => _dio.options.baseUrl;

  static Dio _newDio(String baseUrl) {
    final normalizedBaseUrl = _validateBaseUrl(baseUrl);
    return Dio(
      BaseOptions(
        baseUrl: normalizedBaseUrl,
        connectTimeout: bullnymConnectTimeout,
        receiveTimeout: bullnymReceiveTimeout,
        validateStatus: (status) => status != null && status < 600,
      ),
    );
  }

  static String _validateBaseUrl(String baseUrl) {
    final normalized = baseUrl.trim();
    final uri = Uri.tryParse(normalized);
    if (normalized.isEmpty ||
        uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'https' && !_isLocalHttpUri(uri)) ||
        uri.host.isEmpty) {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'Invalid Bullnym base URL');
    }
    return normalized;
  }

  static Uri _validatePublicOrigin(String publicBaseUrl) {
    final normalized = publicBaseUrl.trim();
    final uri = Uri.tryParse(normalized);
    if (normalized.isEmpty ||
        uri == null ||
        (uri.scheme != 'https' && !_isLocalHttpUri(uri)) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw ArgumentError.value(
        publicBaseUrl,
        'publicBaseUrl',
        'Invalid trusted Bullnym public origin',
      );
    }
    return uri;
  }

  @override
  Future<Result<BullnymVersionInfo, BullnymFailure>> getVersion() {
    return _guard(() async {
      final response = await _getMap('/version');
      return _parseVersionResponse(response);
    });
  }

  @override
  Future<Result<BullnymRegisterResult, BullnymFailure>> register(
    BullnymRegisterRequest request,
  ) {
    return _guard(() async {
      final response = await _postMap(
        '/register',
        data: {
          'nym': request.nym,
          'ct_descriptor': request.ctDescriptor,
          'npub': request.npubHex,
          'signature': request.signatureHex,
          'timestamp': request.timestamp,
        },
      );
      return _parseRegisterResponse(response);
    });
  }

  @override
  Future<Result<void, BullnymFailure>> deleteRegistration(
    BullnymDeleteRegistrationRequest request,
  ) {
    return _guard(() async {
      await _deleteSuccess(
        '/register',
        data: {
          'nym': request.nym,
          'npub': request.npubHex,
          'signature': request.signatureHex,
          'timestamp': request.timestamp,
        },
      );
    });
  }

  @override
  Future<Result<BullnymLookupResult, BullnymFailure>> lookupRegistration({
    required String npubHex,
  }) {
    return _guard(() async {
      final response = await _getMap(
        '/register/lookup',
        queryParameters: {'npub': npubHex},
      );
      return _parseLookupResponse(response);
    });
  }

  @override
  Future<BullnymBackupHead> fetchBackup(
    BullnymBackupFetchRequest request,
  ) async {
    return _guardBackup(() async {
      final response = await _postMap(
        '/api/v1/wallet-backups/fetch',
        data: {
          'version': 1,
          'stream': request.stream.wireName,
          'npub': request.npubHex,
          'timestamp': request.timestamp,
          'signature': request.signatureHex,
        },
      );
      return _parseBackupHead(response, request);
    });
  }

  @override
  Future<BullnymBackupStoreReceipt> storeBackup(
    BullnymBackupStoreRequest request,
  ) async {
    return _guardBackup(() async {
      final response = await _putMap(
        '/api/v1/wallet-backups',
        data: {
          'version': 1,
          'stream': request.stream.wireName,
          'npub': request.npubHex,
          'generation': request.generation,
          'expected_etag': request.expectedEtag,
          'ciphertext': request.ciphertext.value,
          'ciphertext_sha256': request.ciphertextSha256,
          'ciphertext_bytes': request.ciphertext.byteLength,
          'timestamp': request.timestamp,
          'signature': request.signatureHex,
        },
      );
      _requireBackupResponseVersion(response);
      return BullnymBackupStoreReceipt(
        generation: _requiredInt(response, 'generation'),
        etag: _requiredString(response, 'etag'),
      );
    });
  }

  @override
  Future<BullnymBackupDeleteReceipt> deleteBackup(
    BullnymBackupDeleteRequest request,
  ) async {
    return _guardBackup(() async {
      final response = await _deleteMap(
        '/api/v1/wallet-backups',
        data: {
          'version': 1,
          'stream': request.stream.wireName,
          'npub': request.npubHex,
          'generation': request.generation,
          'expected_etag': request.expectedEtag,
          'timestamp': request.timestamp,
          'signature': request.signatureHex,
        },
      );
      _requireBackupResponseVersion(response);
      return BullnymBackupDeleteReceipt(
        generation: _requiredInt(response, 'generation'),
        etag: _requiredString(response, 'etag'),
      );
    });
  }

  @override
  Future<Result<BullnymDonationPage, BullnymFailure>> getDonationPage({
    required String nym,
    required String kind,
  }) {
    return _guard(() async {
      final response = await _getMap(
        '/donation-page/${Uri.encodeComponent(nym)}',
        queryParameters: {'kind': kind},
      );
      return _parseDonationPageResponse(response);
    });
  }

  @override
  Future<Result<BullnymDonationPage, BullnymFailure>> saveDonationPage(
    BullnymSaveDonationPageRequest request,
  ) {
    return _guard(() async {
      final data = <String, dynamic>{
        'nym': request.nym,
        'npub': request.npubHex,
        'ct_descriptor': request.ctDescriptor,
        'header': request.header,
        'description': request.description,
        'display_currency': request.displayCurrency,
        'website': request.website,
        'twitter': request.twitter,
        'instagram': request.instagram,
        'enabled': request.enabled,
        'kind': request.kind,
        'timestamp': request.timestamp,
        'signature': request.signatureHex,
      };
      switch (request.aliasIntent) {
        case BullnymAliasPreserve():
          break;
        case BullnymAliasClaim(:final alias):
          data['alias'] = alias.value;
      }
      final response = await _putMap('/donation-page', data: data);
      return _parseDonationPageResponse(response);
    });
  }

  @override
  Future<Result<BullnymDonationPage, BullnymFailure>> archiveDonationPage(
    BullnymArchiveDonationPageRequest request,
  ) {
    return _guard(() async {
      final response = await _deleteMap(
        '/donation-page',
        data: {
          'nym': request.nym,
          'npub': request.npubHex,
          'kind': request.kind,
          'timestamp': request.timestamp,
          'signature': request.signatureHex,
        },
      );
      return _parseDonationPageResponse(response);
    });
  }

  @override
  Future<Result<BullnymSupportedCurrencies, BullnymFailure>>
  getSupportedCurrencies() {
    return _guard(() async {
      final response = await _getMap('/api/v1/supported-currencies');
      return _parseSupportedCurrenciesResponse(response);
    });
  }

  @override
  Future<Result<BullnymRecoveryAddressLookupResult, BullnymFailure>>
  lookupRecoveryAddress({required BullnymAuthSigner signer}) {
    return _guard(() async {
      final timestamp = _nowSecs();
      final signatureHex = await _signAction(
        signer: signer,
        action: bullpayActionRecoveryAddressGet,
        nymOrEmpty: '',
        payloadFields: buildRecoveryAddressLookupPayloadFields(),
        timestampSecs: timestamp,
      );
      final response = await _getMap(
        '/api/v1/recovery-address',
        queryParameters: {
          'npub': signer.npubHex,
          'timestamp': timestamp,
          'signature': signatureHex,
        },
      );
      return _parseRecoveryAddressLookupResponse(response);
    });
  }

  @override
  Future<Result<BullnymRecoveryAddressRegistrationResult, BullnymFailure>>
  registerRecoveryAddress({
    required BullnymAuthSigner signer,
    required String btcAddress,
  }) {
    return _guard(() async {
      _validateRecoveryAddressInput(btcAddress);
      final timestamp = _nowSecs();
      final signatureHex = await _signAction(
        signer: signer,
        action: bullpayActionRecoveryAddressSet,
        nymOrEmpty: '',
        payloadFields: buildRecoveryAddressRegistrationPayloadFields(
          btcAddress,
        ),
        timestampSecs: timestamp,
      );
      final response = await _putMap(
        '/api/v1/recovery-address',
        data: {
          'version': bullnymRecoveryAddressContractVersion,
          'npub': signer.npubHex,
          'btc_address': btcAddress,
          'timestamp': timestamp,
          'signature': signatureHex,
        },
      );
      return _parseRecoveryAddressRegistrationResponse(
        response,
        expectedSignedAtUnix: timestamp,
      );
    });
  }

  @override
  Future<Result<BullnymCreateInvoiceResponse, BullnymFailure>> createInvoice({
    required BullnymAuthSigner signer,
    String? nym,
    required BullnymCreateInvoiceFields fields,
  }) {
    return _guard(() async {
      final timestamp = _nowSecs();
      final signatureHex = await _signAction(
        signer: signer,
        action: bullpayActionInvoiceCreate,
        nymOrEmpty: nym ?? '',
        payloadFields: buildInvoiceCreatePayloadFields(fields),
        timestampSecs: timestamp,
      );
      final response = await _postMap(
        _invoicesPath(nym),
        data: {
          'npub': signer.npubHex,
          'amount_sat': fields.amountSat,
          'fiat_amount_minor': fields.fiatAmountMinor,
          'fiat_currency': fields.fiatCurrency,
          'client_request_id': fields.clientRequestId,
          'presentation_envelope': fields.presentationEnvelope,
          'accept_btc': fields.acceptBtc,
          'accept_ln': fields.acceptLn,
          'accept_liquid': fields.acceptLiquid,
          'bitcoin_address': fields.bitcoinAddress,
          'liquid_address': fields.liquidAddress,
          'liquid_blinding_key_hex': fields.liquidBlindingKeyHex,
          'expires_at_unix': fields.expiresAtUnix,
          'timestamp': timestamp,
          'signature': signatureHex,
        },
      );
      return BullnymCreateInvoiceResponse(
        invoiceId: _requiredString(response, 'invoice_id'),
        invoiceUrl: _requiredString(response, 'invoice_url'),
      );
    });
  }

  @override
  Future<Result<BullnymCancelInvoiceResponse, BullnymFailure>> cancelInvoice({
    required BullnymAuthSigner signer,
    String? nym,
    required String invoiceId,
  }) {
    return _guard(() async {
      final timestamp = _nowSecs();
      final signatureHex = await _signAction(
        signer: signer,
        action: bullpayActionInvoiceCancel,
        nymOrEmpty: nym ?? '',
        payloadFields: buildInvoiceCancelPayloadFields(invoiceId),
        timestampSecs: timestamp,
      );
      final response = await _deleteMap(
        '${_invoicesPath(nym)}/${Uri.encodeComponent(invoiceId)}',
        data: {
          'npub': signer.npubHex,
          'timestamp': timestamp,
          'signature': signatureHex,
        },
      );
      return BullnymCancelInvoiceResponse(
        invoiceId: _requiredString(response, 'invoice_id'),
        status: _requiredString(response, 'status'),
      );
    });
  }

  @override
  Future<Result<BullnymListInvoicesResponse, BullnymFailure>> listInvoices({
    required BullnymAuthSigner signer,
    required int page,
    required int pageSize,
    String? status,
  }) {
    return _guard(() async {
      final timestamp = _nowSecs();
      // The list is npub-wide: the signed nym slot is ALWAYS empty.
      final signatureHex = await _signAction(
        signer: signer,
        action: bullpayActionInvoiceList,
        nymOrEmpty: '',
        payloadFields: buildInvoiceListPayloadFields(
          page: page,
          pageSize: pageSize,
          status: status,
        ),
        timestampSecs: timestamp,
      );
      final response = await _getMap(
        '/api/v1/invoices',
        queryParameters: {
          'npub': signer.npubHex,
          'timestamp': timestamp,
          'signature': signatureHex,
          'page': page,
          'pageSize': pageSize,
          if (status != null && status.isNotEmpty) 'status': status,
        },
      );
      return _parseListInvoicesResponse(response);
    });
  }

  @override
  Future<Result<BullnymFallbackSupervisionResponse, BullnymFailure>>
  listFallbackSupervision({required BullnymAuthSigner signer}) {
    return _guard(() async {
      final timestamp = _nowSecs();
      final signatureHex = await _signAction(
        signer: signer,
        action: bullpayActionInvoiceRecoveryList,
        nymOrEmpty: '',
        payloadFields: buildInvoiceRecoveryListPayloadFields(),
        timestampSecs: timestamp,
      );
      final response = await _getMap(
        '/api/v1/invoices/recoverable',
        queryParameters: {
          'npub': signer.npubHex,
          'timestamp': timestamp,
          'signature': signatureHex,
        },
      );
      return _parseFallbackSupervisionResponse(response);
    });
  }

  @override
  Future<Result<BullnymInvoiceStatus, BullnymFailure>> getInvoiceStatus({
    required String invoiceId,
  }) {
    return _guard(() async {
      // Public, UNSIGNED: no signer, no signature — by id only.
      final response = await _getMap(
        '/api/v1/invoices/${Uri.encodeComponent(invoiceId)}/status',
      );
      return _parseInvoiceStatusResponse(response);
    });
  }

  @override
  Future<Result<BullnymPayerDemandQuoteResponse, BullnymFailure>>
  getInvoiceQuote({
    required String invoiceId,
    required BullnymPayerQuoteRail rail,
  }) {
    return _guard(() async {
      final response = await _postMap(
        '/api/v1/invoices/${Uri.encodeComponent(invoiceId)}/quote',
        data: {'rail': rail.wire},
      );
      return _parsePayerDemandQuoteResponse(
        response,
        expectedInvoiceId: invoiceId,
        expectedRail: rail,
      );
    });
  }

  // `nym == null` → the unlinked collection; a nym → the linked collection.
  String _invoicesPath(String? nym) {
    if (nym == null) return '/api/v1/invoices';
    return '/api/v1/${Uri.encodeComponent(nym)}/invoices';
  }

  Future<String> _signAction({
    required BullnymAuthSigner signer,
    required String action,
    required String nymOrEmpty,
    required List<String> payloadFields,
    required int timestampSecs,
  }) async {
    final result = await signBullpayAction(
      signer: signer,
      action: action,
      nymOrEmpty: nymOrEmpty,
      payloadFields: payloadFields,
      timestampSecs: timestampSecs,
    );
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw _BullnymClientException(failure),
    };
  }

  Future<Result<T, BullnymFailure>> _guard<T>(
    Future<T> Function() operation,
  ) async {
    try {
      return Ok(await operation());
    } on _BullnymClientException catch (e, stack) {
      log.warning(
        'Bullnym request failed',
        error: e.failure.logMessage ?? e.failure.code,
        trace: stack,
      );
      return Err(e.failure);
    } on Exception catch (e, stack) {
      // Foreign library exceptions stop at this data boundary. Dart [Error]s
      // intentionally remain uncaught because they signal programmer bugs.
      log.warning(
        'Bullnym request failed unexpectedly',
        error: e,
        trace: stack,
      );
      return const Err(BullnymFailure.unexpected());
    }
  }

  Future<T> _guardBackup<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on _BullnymClientException catch (e) {
      throw _backupExceptionFromFailure(e.failure);
    }
  }

  BullnymException _backupExceptionFromFailure(BullnymFailure failure) {
    return switch (failure.kind) {
      BullnymFailureKind.invalidInput => BullnymException.invalidInput(
        failure.logMessage ?? 'Invalid backup request',
      ),
      BullnymFailureKind.network => BullnymException.network(
        diagnosticReason: failure.logMessage ?? 'Network request failed',
      ),
      BullnymFailureKind.timeout => BullnymException.timeout(
        diagnosticReason: failure.logMessage ?? 'Network request timed out',
      ),
      BullnymFailureKind.serverRejectedRequest =>
        BullnymException.serverRejectedRequest(
          code: failure.code,
          diagnosticReason: failure.logMessage ?? failure.code,
          statusCode: failure.statusCode,
          retryable: failure.retryable,
        ),
      BullnymFailureKind.unexpectedHttpStatus =>
        BullnymException.unexpectedHttpStatus(statusCode: failure.statusCode),
      BullnymFailureKind.emptyResponse => BullnymException.emptyResponse(
        statusCode: failure.statusCode,
      ),
      BullnymFailureKind.invalidServerResponse =>
        BullnymException.invalidServerResponse(
          diagnosticReason:
              failure.logMessage ?? 'Invalid Bullnym backup response',
          statusCode: failure.statusCode,
        ),
      BullnymFailureKind.signingFailed =>
        const BullnymException.signingFailed(),
      BullnymFailureKind.unexpected => BullnymException.invalidServerResponse(
        diagnosticReason: failure.logMessage ?? 'Unexpected backup failure',
      ),
    };
  }

  Future<Map<String, dynamic>> _getMap(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _requestMap(
      () => _dio.get<dynamic>(path, queryParameters: queryParameters),
    );
  }

  Future<Map<String, dynamic>> _postMap(String path, {Object? data}) async {
    return _requestMap(() => _dio.post<dynamic>(path, data: data));
  }

  Future<Map<String, dynamic>> _putMap(String path, {Object? data}) async {
    return _requestMap(() => _dio.put<dynamic>(path, data: data));
  }

  Future<Map<String, dynamic>> _deleteMap(String path, {Object? data}) async {
    return _requestMap(() => _dio.delete<dynamic>(path, data: data));
  }

  Future<void> _deleteSuccess(String path, {Object? data}) async {
    final response = await _requestResponse(
      () => _dio.delete<dynamic>(path, data: data),
    );
    _throwIfBullnymError(response);
    final statusCode = response.statusCode;
    if (statusCode == null || statusCode < 200 || statusCode >= 300) {
      throw _BullnymClientException(_httpFailureFromResponse(response));
    }
  }

  Future<Map<String, dynamic>> _requestMap(
    Future<Response<dynamic>> Function() request,
  ) async {
    return _decodeMap(await _requestResponse(request));
  }

  Future<Response<dynamic>> _requestResponse(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (e) {
      final response = e.response;
      if (response != null) return response;
      throw _BullnymClientException(_networkFailure(e));
    }
  }

  BullnymFailure _networkFailure(DioException e) {
    final isTimeout =
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout;
    final diagnosticReason = e.message ?? 'Network request failed';
    if (isTimeout) {
      return BullnymFailure.timeout(logMessage: diagnosticReason);
    }
    return BullnymFailure.network(logMessage: diagnosticReason);
  }

  Map<String, dynamic> _decodeMap(Response<dynamic> response) {
    _throwIfBullnymError(response);
    final statusCode = response.statusCode;
    if (statusCode == null || statusCode < 200 || statusCode >= 300) {
      throw _BullnymClientException(_httpFailureFromResponse(response));
    }
    final data = _requireJson(response);
    if (data is Map<String, dynamic>) return data;
    throw _BullnymClientException(
      BullnymFailure.invalidServerResponse(
        logMessage: 'Server returned an unexpected response shape',
        statusCode: response.statusCode,
      ),
    );
  }

  dynamic _requireJson(Response<dynamic> response) {
    final data = response.data;
    if (data == null) {
      throw _BullnymClientException(
        BullnymFailure.emptyResponse(statusCode: response.statusCode),
      );
    }
    return data;
  }

  void _throwIfBullnymError(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic> && data['status'] == 'ERROR') {
      throw _BullnymClientException(_serverFailureFromResponse(response));
    }
  }

  BullnymFailure _serverFailureFromResponse(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic> && data['status'] == 'ERROR') {
      final code = data['code'];
      final reason = data['reason'];
      if (reason is! String) {
        return BullnymFailure.invalidServerResponse(
          logMessage: 'Server error response is missing reason',
          statusCode: response.statusCode,
        );
      }
      final normalizedCode = code == 'NymTaken'
          ? 'NameTaken'
          : code is String
          ? code
          : 'ServerRejectedRequest';
      return BullnymFailure.serverRejectedRequest(
        code: normalizedCode,
        logMessage: reason,
        statusCode: response.statusCode,
        retryable: _isRetryableStatus(response.statusCode),
        ownedNameDetails: _parseOwnedNameDetails(
          normalizedCode,
          data['details'],
          response.statusCode,
        ),
      );
    }
    return BullnymFailure.unexpectedHttpStatus(statusCode: response.statusCode);
  }

  bool _isRetryableStatus(int? statusCode) {
    if (statusCode == null) return true;
    return statusCode == 408 || statusCode == 429 || statusCode >= 500;
  }

  static bool _isLocalHttpUri(Uri uri) {
    if (uri.scheme != 'http') return false;
    return uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.host == '::1';
  }

  BullnymFailure _httpFailureFromResponse(Response<dynamic> response) {
    if (response.data is Map<String, dynamic>) {
      return _serverFailureFromResponse(response);
    }
    return BullnymFailure.unexpectedHttpStatus(statusCode: response.statusCode);
  }

  void _validateRecoveryAddressInput(String btcAddress) {
    if (btcAddress.isEmpty ||
        btcAddress != btcAddress.trim() ||
        btcAddress.contains('\u0000')) {
      throw const _BullnymClientException(
        BullnymFailure.invalidInput(
          'Recovery address must be a non-empty canonical Bitcoin address',
        ),
      );
    }
  }

  BullnymRecoveryAddressLookupResult _parseRecoveryAddressLookupResponse(
    Map<String, dynamic> json,
  ) {
    final version = _requiredRecoveryAddressVersion(json);
    final isRegistered = _requiredBool(json, 'recovery_address_registered');
    final btcAddress = _optionalString(json, 'btc_address');
    final commitmentVersion = _optionalInt(json, 'commitment_version');
    final signedAtUnix = _optionalInt(json, 'signed_at_unix');

    final isCompleteRegisteredValue =
        btcAddress != null &&
        btcAddress.isNotEmpty &&
        btcAddress == btcAddress.trim() &&
        !btcAddress.contains('\u0000') &&
        commitmentVersion != null &&
        commitmentVersion > 0 &&
        signedAtUnix != null &&
        signedAtUnix >= 0;
    final isCompleteUnregisteredValue =
        btcAddress == null && commitmentVersion == null && signedAtUnix == null;
    if ((isRegistered && !isCompleteRegisteredValue) ||
        (!isRegistered && !isCompleteUnregisteredValue)) {
      throw const _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage: 'Recovery-address lookup fields are inconsistent',
        ),
      );
    }

    return BullnymRecoveryAddressLookupResult(
      version: version,
      isRegistered: isRegistered,
      btcAddress: btcAddress,
      commitmentVersion: commitmentVersion,
      signedAtUnix: signedAtUnix,
    );
  }

  BullnymRecoveryAddressRegistrationResult
  _parseRecoveryAddressRegistrationResponse(
    Map<String, dynamic> json, {
    required int expectedSignedAtUnix,
  }) {
    final version = _requiredRecoveryAddressVersion(json);
    final isRegistered = _requiredBool(json, 'recovery_address_registered');
    final signedAtUnix = _requiredInt(json, 'signed_at_unix');
    if (!isRegistered || signedAtUnix != expectedSignedAtUnix) {
      throw const _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage: 'Recovery-address acknowledgement is inconsistent',
        ),
      );
    }
    return BullnymRecoveryAddressRegistrationResult(
      version: version,
      isRegistered: true,
      signedAtUnix: signedAtUnix,
    );
  }

  int _requiredRecoveryAddressVersion(Map<String, dynamic> json) {
    final version = _requiredInt(json, 'version');
    if (version != bullnymRecoveryAddressContractVersion) {
      throw const _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage: 'Unsupported recovery-address contract version',
        ),
      );
    }
    return version;
  }

  BullnymRegisterResult _parseRegisterResponse(Map<String, dynamic> json) {
    return BullnymRegisterResult(
      nym: _requiredString(json, 'nym'),
      lightningAddress: _requiredString(json, 'lightning_address'),
      quota: json.containsKey('quota') ? _parseQuota(json['quota']) : null,
    );
  }

  BullnymVersionInfo _parseVersionResponse(Map<String, dynamic> json) {
    return BullnymVersionInfo(
      publicNamePolicy: _optionalString(json, 'public_name_policy'),
    );
  }

  BullnymLookupResult _parseLookupResponse(Map<String, dynamic> json) {
    final nym = _requiredString(json, 'nym');
    final policy = _optionalString(json, 'public_name_policy');
    BullnymPublicNameStatus? publicNameStatus;
    final bool active;
    if (policy == bullnymPermanentNamesV1Policy) {
      if (!json.containsKey('alias')) {
        throw const _BullnymClientException(
          BullnymFailure.invalidServerResponse(
            logMessage: 'Permanent-name lookup is missing alias',
          ),
        );
      }
      // Under permanent_names_v1 the server reports liveness via
      // `lightning_address_online` and no longer emits the legacy `active`
      // bool; derive `active` from it. When `active` is still present (older
      // servers), it must agree with liveness.
      final lightningAddressOnline = _requiredBool(
        json,
        'lightning_address_online',
      );
      if (json.containsKey('active') &&
          _requiredBool(json, 'active') != lightningAddressOnline) {
        throw const _BullnymClientException(
          BullnymFailure.invalidServerResponse(
            logMessage: 'Lookup status fields are inconsistent',
          ),
        );
      }
      active = lightningAddressOnline;
      publicNameStatus = BullnymPublicNameStatus(
        nym: _parsePublicName(nym, field: 'nym'),
        alias: _parseOptionalPublicName(json['alias'], field: 'alias'),
        lightningAddressOnline: lightningAddressOnline,
        publicNamePolicy: bullnymPermanentNamesV1Policy,
        quota: _parseQuota(json['quota']),
      );
    } else {
      active = _requiredBool(json, 'active');
    }
    return BullnymLookupResult(
      nym: nym,
      active: active,
      lightningAddress: _optionalString(json, 'lightning_address'),
      publicNameStatus: publicNameStatus,
    );
  }

  BullnymQuota _parseQuota(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage: 'Server response is missing quota object',
        ),
      );
    }
    try {
      return BullnymQuota(
        used: _requiredInt(value, 'used'),
        cap: _requiredInt(value, 'cap'),
        remaining: _requiredInt(value, 'remaining'),
      );
    } on ArgumentError {
      throw const _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage: 'Server quota is internally inconsistent',
        ),
      );
    }
  }

  BullnymPublicName _parsePublicName(String value, {required String field}) {
    try {
      return BullnymPublicName(value);
    } on ArgumentError {
      throw _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage: 'Server response has invalid $field',
        ),
      );
    }
  }

  BullnymPublicName? _parseOptionalPublicName(
    Object? value, {
    required String field,
  }) {
    if (value == null) return null;
    if (value is! String) {
      throw _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage: 'Server response field $field is not a string',
        ),
      );
    }
    return _parsePublicName(value, field: field);
  }

  BullnymOwnedNameDetails? _parseOwnedNameDetails(
    String code,
    Object? value,
    int? statusCode,
  ) {
    if (code != 'NymAlreadyAssigned' && code != 'AliasAlreadyAssigned') {
      return null;
    }
    if (value == null) return null;
    if (value is! Map<String, dynamic>) {
      throw _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage: 'Server conflict details have an unexpected shape',
          statusCode: statusCode,
        ),
      );
    }
    switch (code) {
      case 'NymAlreadyAssigned':
        final nym = _parsePublicName(
          _requiredString(value, 'nym'),
          field: 'details.nym',
        );
        final domain = _optionalString(value, 'domain');
        if (domain != null && domain.isEmpty) {
          throw _BullnymClientException(
            BullnymFailure.invalidServerResponse(
              logMessage: 'Server conflict domain is empty',
              statusCode: statusCode,
            ),
          );
        }
        return BullnymOwnedNymDetails(nym: nym, domain: domain);
      case 'AliasAlreadyAssigned':
        return BullnymOwnedAliasDetails(
          alias: _parsePublicName(
            _requiredString(value, 'alias'),
            field: 'details.alias',
          ),
        );
      default:
        return null;
    }
  }

  String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String) return value;
    throw _BullnymClientException(
      BullnymFailure.invalidServerResponse(
        logMessage: 'Server response is missing string field $key',
      ),
    );
  }

  String _requiredNonEmptyString(Map<String, dynamic> json, String key) {
    final value = _requiredString(json, key);
    if (value.trim().isNotEmpty) return value;
    throw _BullnymClientException(
      BullnymFailure.invalidServerResponse(
        logMessage: 'Server response field $key is empty',
      ),
    );
  }

  bool _requiredBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is bool) return value;
    throw _BullnymClientException(
      BullnymFailure.invalidServerResponse(
        logMessage: 'Server response is missing bool field $key',
      ),
    );
  }

  String? _optionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is String) return value;
    throw _BullnymClientException(
      BullnymFailure.invalidServerResponse(
        logMessage: 'Server response field $key is not a string',
      ),
    );
  }

  int _requiredInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) return value;
    throw _BullnymClientException(
      BullnymFailure.invalidServerResponse(
        logMessage: 'Server response is missing int field $key',
      ),
    );
  }

  BullnymBackupHead _parseBackupHead(
    Map<String, dynamic> json,
    BullnymBackupFetchRequest request,
  ) {
    _requireBackupResponseVersion(json);
    final found = _requiredBool(json, 'found');
    final generation = _requiredInt(json, 'generation');
    final etag = _optionalString(json, 'etag');
    if (!found) {
      if (json['ciphertext'] != null ||
          json['ciphertext_sha256'] != null ||
          json['ciphertext_bytes'] != null) {
        throw const BullnymException.invalidServerResponse(
          diagnosticReason: 'Absent backup response contains ciphertext',
        );
      }
      final expectedEtag = generation == 0
          ? null
          : computeWalletBackupEtag(
              stream: request.stream,
              npubHex: request.npubHex,
              generation: generation,
              ciphertextSha256: '',
            );
      if (etag != expectedEtag) {
        throw const BullnymException.invalidServerResponse(
          diagnosticReason: 'Absent backup response ETag does not match',
        );
      }
      return BullnymBackupHead.absent(generation: generation, etag: etag);
    }
    final ciphertext = AuthenticatedBackupCiphertext(
      _requiredString(json, 'ciphertext'),
    );
    final declaredBytes = _requiredInt(json, 'ciphertext_bytes');
    final declaredHash = _requiredString(json, 'ciphertext_sha256');
    final actualHash = sha256
        .convert(base64.decode(ciphertext.value))
        .toString();
    if (declaredBytes != ciphertext.byteLength || declaredHash != actualHash) {
      throw const BullnymException.invalidServerResponse(
        diagnosticReason: 'Backup ciphertext integrity fields do not match',
      );
    }
    final expectedEtag = computeWalletBackupEtag(
      stream: request.stream,
      npubHex: request.npubHex,
      generation: generation,
      ciphertextSha256: declaredHash,
    );
    if (etag != expectedEtag) {
      throw const BullnymException.invalidServerResponse(
        diagnosticReason: 'Backup response ETag does not match',
      );
    }
    return BullnymBackupHead.present(
      generation: generation,
      etag:
          etag ??
          (throw const BullnymException.invalidServerResponse(
            diagnosticReason: 'Found backup response is missing ETag',
          )),
      ciphertext: ciphertext,
      ciphertextSha256: declaredHash,
      updatedAtSecs: _requiredInt(json, 'updated_at'),
    );
  }

  void _requireBackupResponseVersion(Map<String, dynamic> json) {
    if (_requiredInt(json, 'version') != 1) {
      throw const BullnymException.invalidServerResponse(
        diagnosticReason: 'Unsupported backup response version',
      );
    }
  }

  int _requiredNonNegativeInt(Map<String, dynamic> json, String key) {
    final value = _requiredInt(json, key);
    if (value >= 0) return value;
    throw _BullnymClientException(
      BullnymFailure.invalidServerResponse(
        logMessage: 'Server response field $key is negative',
      ),
    );
  }

  int _requiredPositiveInt(Map<String, dynamic> json, String key) {
    final value = _requiredInt(json, key);
    if (value > 0) return value;
    throw _BullnymClientException(
      BullnymFailure.invalidServerResponse(
        logMessage: 'Server response field $key is not positive',
      ),
    );
  }

  Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is Map<String, dynamic>) return value;
    throw _BullnymClientException(
      BullnymFailure.invalidServerResponse(
        logMessage: 'Server response is missing object field $key',
      ),
    );
  }

  int? _optionalInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is int) return value;
    throw _BullnymClientException(
      BullnymFailure.invalidServerResponse(
        logMessage: 'Server response field $key is not an int',
      ),
    );
  }

  int? _optionalPositiveInt(Map<String, dynamic> json, String key) {
    final value = _optionalInt(json, key);
    if (value == null || value > 0) return value;
    throw _BullnymClientException(
      BullnymFailure.invalidServerResponse(
        logMessage: 'Server response field $key is not positive',
      ),
    );
  }

  void _validatePayerInstructionPair({
    required String name,
    required String? payload,
    required int? amountSat,
  }) {
    if (payload != null && payload.trim().isEmpty) {
      throw _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage: 'Server response has an empty $name instruction',
        ),
      );
    }
    final hasPayload = payload != null && payload.trim().isNotEmpty;
    if (hasPayload != (amountSat != null)) {
      throw _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage: 'Server response has an incomplete $name instruction',
        ),
      );
    }
  }

  // Tolerant reader: parse the KNOWN keys with type checks; unknown keys are
  // ignored so a future server field cannot crash an older binary.
  BullnymDonationPage _parseDonationPageResponse(Map<String, dynamic> json) {
    final nym = _parsePublicName(_requiredString(json, 'nym'), field: 'nym');
    final alias = _parseOptionalPublicName(json['alias'], field: 'alias');
    final kind = _requiredString(json, 'kind');
    final publicUrl = _requiredString(json, 'public_url');
    final trustedPublicUrl = _validatePublicUrl(
      publicUrl,
      nym: nym,
      alias: alias,
      kind: kind,
    );
    return BullnymDonationPage(
      nym: nym.value,
      header: _requiredString(json, 'header'),
      description: _requiredString(json, 'description'),
      displayCurrency: _requiredString(json, 'display_currency'),
      website: _optionalString(json, 'website'),
      twitter: _optionalString(json, 'twitter'),
      instagram: _optionalString(json, 'instagram'),
      kind: kind,
      posMode: _requiredBool(json, 'pos_mode'),
      enabled: _requiredBool(json, 'enabled'),
      isArchived: _requiredBool(json, 'is_archived'),
      avatarSha256: _optionalString(json, 'avatar_sha256'),
      ogSha256: _optionalString(json, 'og_sha256'),
      alias: alias?.value,
      publicUrl: trustedPublicUrl.value,
    );
  }

  BullnymPublicUrl _validatePublicUrl(
    String value, {
    required BullnymPublicName nym,
    required BullnymPublicName? alias,
    required String kind,
  }) {
    try {
      return BullnymPublicUrl.validated(
        value: value,
        trustedPublicOrigin: _trustedPublicOrigin,
        nym: nym,
        alias: alias,
        kind: kind,
      );
    } on ArgumentError {
      throw const _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage: 'Server returned an untrusted public URL',
        ),
      );
    }
  }

  BullnymSupportedCurrencies _parseSupportedCurrenciesResponse(
    Map<String, dynamic> json,
  ) {
    final rawCurrencies = json['currencies'];
    if (rawCurrencies is! List) {
      throw const _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage: 'Server response is missing currencies list',
        ),
      );
    }
    final currencies = <BullnymSupportedCurrency>[];
    for (final raw in rawCurrencies) {
      if (raw is! Map<String, dynamic>) {
        throw const _BullnymClientException(
          BullnymFailure.invalidServerResponse(
            logMessage: 'Server currency entry has an unexpected shape',
          ),
        );
      }
      currencies.add(
        BullnymSupportedCurrency(
          code: _requiredString(raw, 'code'),
          precision: _requiredInt(raw, 'precision'),
        ),
      );
    }
    return BullnymSupportedCurrencies(currencies: currencies);
  }

  // Tolerant reader: parse the KNOWN keys with type checks; unknown keys are
  // ignored so a future server field cannot crash an older binary.
  BullnymListInvoicesResponse _parseListInvoicesResponse(
    Map<String, dynamic> json,
  ) {
    final rawInvoices = json['invoices'];
    if (rawInvoices is! List) {
      throw const _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage: 'Server response is missing invoices list',
        ),
      );
    }
    final invoices = <BullnymInvoiceListItem>[];
    for (final raw in rawInvoices) {
      if (raw is! Map<String, dynamic>) {
        throw const _BullnymClientException(
          BullnymFailure.invalidServerResponse(
            logMessage: 'Server invoice entry has an unexpected shape',
          ),
        );
      }
      invoices.add(_parseInvoiceListItem(raw));
    }
    return BullnymListInvoicesResponse(
      invoices: invoices,
      page: _requiredInt(json, 'page'),
      pageSize: _requiredInt(json, 'pageSize'),
      hasMore: _requiredBool(json, 'has_more'),
    );
  }

  BullnymInvoiceListItem _parseInvoiceListItem(Map<String, dynamic> json) {
    return BullnymInvoiceListItem(
      id: _requiredString(json, 'id'),
      nymOwner: _optionalString(json, 'nym_owner'),
      origin: _requiredString(json, 'origin'),
      status: _requiredString(json, 'status'),
      presentationStatus: _optionalString(json, 'presentation_status'),
      pricingMode: _requiredString(json, 'pricing_mode'),
      settlementStatus: _requiredString(json, 'settlement_status'),
      amountSat: _requiredInt(json, 'amount_sat'),
      remainingAmountSat: _requiredInt(json, 'remaining_amount_sat'),
      fiatAmountMinor: _optionalInt(json, 'fiat_amount_minor'),
      fiatCurrency: _optionalString(json, 'fiat_currency'),
      memo: _optionalString(json, 'memo'),
      acceptBtc: _requiredBool(json, 'accept_btc'),
      acceptLn: _requiredBool(json, 'accept_ln'),
      acceptLiquid: _requiredBool(json, 'accept_liquid'),
      bitcoinAddress: _optionalString(json, 'bitcoin_address'),
      liquidAddress: _optionalString(json, 'liquid_address'),
      createdAtUnix: _requiredInt(json, 'created_at_unix'),
      expiresAtUnix: _requiredInt(json, 'expires_at_unix'),
      paidVia: _optionalString(json, 'paid_via'),
      paidAtUnix: _optionalInt(json, 'paid_at_unix'),
      paidAmountSat: _optionalInt(json, 'paid_amount_sat'),
    );
  }

  BullnymFallbackSupervisionResponse _parseFallbackSupervisionResponse(
    Map<String, dynamic> json,
  ) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage: 'Server response is missing fallback supervision list',
        ),
      );
    }
    final items = <BullnymFallbackSupervisionItem>[];
    for (final raw in rawItems) {
      if (raw is! Map<String, dynamic>) {
        throw const _BullnymClientException(
          BullnymFailure.invalidServerResponse(
            logMessage: 'Server fallback entry has an unexpected shape',
          ),
        );
      }
      final rawInvoice = raw['invoice'];
      if (rawInvoice is! Map<String, dynamic>) {
        throw const _BullnymClientException(
          BullnymFailure.invalidServerResponse(
            logMessage: 'Server fallback entry is missing invoice context',
          ),
        );
      }
      items.add(
        BullnymFallbackSupervisionItem(
          invoiceId: _requiredString(raw, 'invoice_id'),
          nym: _requiredString(raw, 'nym'),
          recoveryStatus: _requiredString(raw, 'recovery_status'),
          userLockAmountSat: _requiredNonNegativeInt(
            raw,
            'user_lock_amount_sat',
          ),
          serverLockAmountSat: _requiredNonNegativeInt(
            raw,
            'server_lock_amount_sat',
          ),
          lockupAddress: _requiredString(raw, 'lockup_address'),
          refundAddress: _optionalString(raw, 'refund_address'),
          refundTxid: _optionalString(raw, 'refund_txid'),
          swapCreatedAtUnix: _requiredNonNegativeInt(
            raw,
            'swap_created_at_unix',
          ),
          swapUpdatedAtUnix: _requiredNonNegativeInt(
            raw,
            'swap_updated_at_unix',
          ),
          invoice: BullnymFallbackInvoiceContext(
            status: _requiredString(rawInvoice, 'status'),
            amountSat: _requiredNonNegativeInt(rawInvoice, 'amount_sat'),
            fiatAmountMinor: _optionalInt(rawInvoice, 'fiat_amount_minor'),
            fiatCurrency: _optionalString(rawInvoice, 'fiat_currency'),
            publicDescription: _optionalString(
              rawInvoice,
              'public_description',
            ),
            invoiceNumber: _optionalString(rawInvoice, 'invoice_number'),
            createdAtUnix: _requiredNonNegativeInt(
              rawInvoice,
              'created_at_unix',
            ),
          ),
        ),
      );
    }
    final count = _requiredNonNegativeInt(json, 'count');
    if (count != items.length || items.length > 100) {
      throw const _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage: 'Server fallback supervision count is inconsistent',
        ),
      );
    }
    return BullnymFallbackSupervisionResponse(
      items: items,
      count: count,
      hasMore: _requiredBool(json, 'has_more'),
    );
  }

  BullnymInvoiceStatus _parseInvoiceStatusResponse(Map<String, dynamic> json) {
    final lightningPr = _optionalString(json, 'lightning_pr');
    final lightningAmountSat = _optionalPositiveInt(
      json,
      'lightning_amount_sat',
    );
    final liquidAddress = _optionalString(json, 'liquid_address');
    final liquidAmountSat = _optionalPositiveInt(json, 'liquid_amount_sat');
    final bitcoinChainAddress = _optionalString(json, 'bitcoin_chain_address');
    final bitcoinChainBip21 = _optionalString(json, 'bitcoin_chain_bip21');
    final bitcoinChainAmountSat = _optionalPositiveInt(
      json,
      'bitcoin_chain_amount_sat',
    );
    final pricingMode = _requiredString(json, 'pricing_mode');
    if (pricingMode != 'sat_fixed' && pricingMode != 'fiat_fixed') {
      throw const _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage: 'Invoice status has an unexpected pricing mode',
        ),
      );
    }
    final quoteRailAvailability = _parseQuoteRailAvailability(
      json['quote_rail_availability'],
      requiredForFiat: pricingMode == 'fiat_fixed',
    );
    _validatePayerInstructionPair(
      name: 'Lightning',
      payload: lightningPr,
      amountSat: lightningAmountSat,
    );
    _validatePayerInstructionPair(
      name: 'Liquid',
      payload: liquidAddress,
      amountSat: liquidAmountSat,
    );
    _validatePayerInstructionPair(
      name: 'Bitcoin chain',
      payload: bitcoinChainAddress,
      amountSat: bitcoinChainAmountSat,
    );
    if (bitcoinChainBip21 != null && bitcoinChainAddress == null) {
      throw const _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage:
              'Server response has a Bitcoin BIP21 without a chain address',
        ),
      );
    }
    if (bitcoinChainBip21 != null && bitcoinChainBip21.trim().isEmpty) {
      throw const _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage: 'Server response has an empty Bitcoin BIP21',
        ),
      );
    }
    return BullnymInvoiceStatus(
      status: _requiredString(json, 'status'),
      presentationStatus: _optionalString(json, 'presentation_status'),
      pricingMode: pricingMode,
      settlementStatus: _requiredString(json, 'settlement_status'),
      amountSat: _requiredInt(json, 'amount_sat'),
      fiatAmountMinor: _optionalInt(json, 'fiat_amount_minor'),
      fiatCurrency: _optionalString(json, 'fiat_currency'),
      remainingAmountSat: _requiredInt(json, 'remaining_amount_sat'),
      paymentToleranceSat: _requiredInt(json, 'payment_tolerance_sat'),
      rateMinorPerBtc: _optionalInt(json, 'rate_minor_per_btc'),
      rateLocksUntilUnix: _requiredInt(json, 'rate_locks_until_unix'),
      expiresAtUnix: _requiredInt(json, 'expires_at_unix'),
      paidVia: _optionalString(json, 'paid_via'),
      paidAtUnix: _optionalInt(json, 'paid_at_unix'),
      paidAmountSat: _optionalInt(json, 'paid_amount_sat'),
      lightningPr: lightningPr,
      lightningAmountSat: lightningAmountSat,
      liquidAddress: liquidAddress,
      liquidAmountSat: liquidAmountSat,
      bitcoinAddress: _optionalString(json, 'bitcoin_address'),
      bitcoinChainAddress: bitcoinChainAddress,
      bitcoinChainBip21: bitcoinChainBip21,
      bitcoinChainAmountSat: bitcoinChainAmountSat,
      acceptBtc: _requiredBool(json, 'accept_btc'),
      acceptLn: _requiredBool(json, 'accept_ln'),
      acceptLiquid: _requiredBool(json, 'accept_liquid'),
      bitcoinDirectObservations: _parseBitcoinDirectObservations(json),
      quoteRailAvailability: quoteRailAvailability,
    );
  }

  BullnymPayerQuoteRailAvailability? _parseQuoteRailAvailability(
    Object? raw, {
    required bool requiredForFiat,
  }) {
    if (raw == null) {
      if (!requiredForFiat) return null;
      throw const _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage: 'Fiat invoice status is missing quote rail availability',
        ),
      );
    }
    if (!requiredForFiat) {
      throw const _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage: 'Sat invoice status unexpectedly contains quote rails',
        ),
      );
    }
    if (raw is! Map<String, dynamic>) {
      throw const _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage: 'Quote rail availability has an unexpected shape',
        ),
      );
    }
    return BullnymPayerQuoteRailAvailability(
      lightning: _requiredBool(raw, 'lightning'),
      liquid: _requiredBool(raw, 'liquid'),
      bitcoin: _requiredBool(raw, 'bitcoin'),
    );
  }

  BullnymPayerDemandQuoteResponse _parsePayerDemandQuoteResponse(
    Map<String, dynamic> json, {
    required String expectedInvoiceId,
    required BullnymPayerQuoteRail expectedRail,
  }) {
    if (_requiredString(json, 'pricing_mode') != 'fiat_fixed') {
      throw const _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage: 'Payer quote has an unexpected pricing mode',
        ),
      );
    }
    final invoiceId = _requiredNonEmptyString(json, 'invoice_id');
    final selectedRail = BullnymPayerQuoteRail.fromWire(
      _requiredString(json, 'selected_rail'),
    );
    if (invoiceId != expectedInvoiceId || selectedRail != expectedRail) {
      throw const _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage: 'Payer quote identity does not match the request',
        ),
      );
    }
    final rawQuote = _requiredMap(json, 'quote');
    final createdAtUnix = _requiredNonNegativeInt(rawQuote, 'created_at_unix');
    final expiresAtUnix = _requiredNonNegativeInt(rawQuote, 'expires_at_unix');
    final rateObservedAtUnix = _requiredNonNegativeInt(
      rawQuote,
      'rate_observed_at_unix',
    );
    final rateFetchedAtUnix = _requiredNonNegativeInt(
      rawQuote,
      'rate_fetched_at_unix',
    );
    final rateFreshUntilUnix = _requiredNonNegativeInt(
      rawQuote,
      'rate_fresh_until_unix',
    );
    final fiatFaceAmountMinor = _requiredPositiveInt(
      rawQuote,
      'fiat_face_amount_minor',
    );
    final fiatTargetAmountMinor = _requiredPositiveInt(
      rawQuote,
      'fiat_target_amount_minor',
    );
    if (fiatTargetAmountMinor > fiatFaceAmountMinor ||
        expiresAtUnix - createdAtUnix != 300 ||
        rateObservedAtUnix >= rateFreshUntilUnix ||
        rateFetchedAtUnix >= rateFreshUntilUnix) {
      throw const _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage: 'Payer quote contains inconsistent version evidence',
        ),
      );
    }
    final quote = BullnymFiatQuote(
      quoteVersionId: _requiredNonEmptyString(rawQuote, 'quote_version_id'),
      versionNumber: _requiredPositiveInt(rawQuote, 'version_number'),
      fiatFaceAmountMinor: fiatFaceAmountMinor,
      fiatTargetAmountMinor: fiatTargetAmountMinor,
      fiatCurrency: _requiredNonEmptyString(rawQuote, 'fiat_currency'),
      rateMinorPerBtc: _requiredPositiveInt(rawQuote, 'rate_minor_per_btc'),
      rateSource: _requiredNonEmptyString(rawQuote, 'rate_source'),
      rateObservedAtUnix: rateObservedAtUnix,
      rateFetchedAtUnix: rateFetchedAtUnix,
      rateFreshUntilUnix: rateFreshUntilUnix,
      merchantAmountSat: _requiredPositiveInt(rawQuote, 'merchant_amount_sat'),
      createdAtUnix: createdAtUnix,
      expiresAtUnix: expiresAtUnix,
    );
    final instruction = _parseVersionedPayerInstruction(
      _requiredMap(json, 'instruction'),
      selectedRail: selectedRail!,
      merchantAmountSat: quote.merchantAmountSat,
    );
    return BullnymPayerDemandQuoteResponse(
      invoiceId: invoiceId,
      selectedRail: selectedRail,
      quote: quote,
      instruction: instruction,
    );
  }

  BullnymVersionedPayerInstruction _parseVersionedPayerInstruction(
    Map<String, dynamic> json, {
    required BullnymPayerQuoteRail selectedRail,
    required int merchantAmountSat,
  }) {
    final kind = _requiredString(json, 'kind');
    final payerAmountSat = _requiredPositiveInt(json, 'payer_amount_sat');
    final BullnymVersionedPayerInstruction instruction = switch (kind) {
      'lightning_boltz_reverse'
          when selectedRail == BullnymPayerQuoteRail.lightning =>
        BullnymLightningQuoteInstruction(
          quoteOfferId: _requiredNonEmptyString(json, 'quote_offer_id'),
          pr: _requiredNonEmptyString(json, 'pr'),
          payerAmountSat: payerAmountSat,
        ),
      'liquid_direct' when selectedRail == BullnymPayerQuoteRail.liquid =>
        BullnymLiquidQuoteInstruction(
          address: _requiredNonEmptyString(json, 'address'),
          payerAmountSat: payerAmountSat,
        ),
      'bitcoin_direct' when selectedRail == BullnymPayerQuoteRail.bitcoin =>
        BullnymBitcoinDirectQuoteInstruction(
          address: _requiredNonEmptyString(json, 'address'),
          bip21: _requiredNonEmptyString(json, 'bip21'),
          payerAmountSat: payerAmountSat,
        ),
      'bitcoin_boltz_chain'
          when selectedRail == BullnymPayerQuoteRail.bitcoin =>
        BullnymBitcoinBoltzQuoteInstruction(
          quoteOfferId: _requiredNonEmptyString(json, 'quote_offer_id'),
          address: _requiredNonEmptyString(json, 'address'),
          bip21: _requiredNonEmptyString(json, 'bip21'),
          payerAmountSat: payerAmountSat,
        ),
      _ => throw const _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage: 'Payer instruction does not match the selected rail',
        ),
      ),
    };
    final direct =
        instruction is BullnymLiquidQuoteInstruction ||
        instruction is BullnymBitcoinDirectQuoteInstruction;
    if ((direct && payerAmountSat != merchantAmountSat) ||
        (!direct && payerAmountSat <= merchantAmountSat)) {
      throw const _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage: 'Payer amount does not match the selected rail policy',
        ),
      );
    }
    return instruction;
  }

  List<BullnymBitcoinDirectObservation> _parseBitcoinDirectObservations(
    Map<String, dynamic> json,
  ) {
    final rawObservations = json['bitcoin_direct_observations'];
    if (rawObservations is! List) {
      throw const _BullnymClientException(
        BullnymFailure.invalidServerResponse(
          logMessage:
              'Server response is missing bitcoin_direct_observations list',
        ),
      );
    }
    return [
      for (final raw in rawObservations)
        if (raw is Map<String, dynamic>)
          BullnymBitcoinDirectObservation(
            source: _requiredString(raw, 'source'),
            rail: _requiredString(raw, 'rail'),
            txid: _requiredString(raw, 'txid'),
            vout: _requiredInt(raw, 'vout'),
            address: _requiredString(raw, 'address'),
            amountSat: _requiredInt(raw, 'amount_sat'),
            confirmations: _requiredInt(raw, 'confirmations'),
            blockHeight: _optionalInt(raw, 'block_height'),
            state: _requiredString(raw, 'state'),
            firstSeenAtUnix: _requiredInt(raw, 'first_seen_at_unix'),
            lastSeenAtUnix: _requiredInt(raw, 'last_seen_at_unix'),
          )
        else
          throw const _BullnymClientException(
            BullnymFailure.invalidServerResponse(
              logMessage: 'Server bitcoin observation has an unexpected shape',
            ),
          ),
    ];
  }
}

final class _BullnymClientException implements Exception {
  final BullnymFailure failure;

  const _BullnymClientException(this.failure);
}
