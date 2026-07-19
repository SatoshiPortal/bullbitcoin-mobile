import 'dart:convert';

import 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_actions.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_blob.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_donation_page.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_error.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_invoice.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_invoice_actions.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_registration.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_config.dart';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';

const Duration bullnymConnectTimeout = Duration(seconds: 10);
const Duration bullnymReceiveTimeout = Duration(seconds: 15);

class BullnymHttpClient implements BullnymClientPort {
  BullnymHttpClient({
    String baseUrl = bullnymDefaultBaseUrl,
    this._nowSecs = currentBullpayTimestampSecs,
  }) : _dio = _newDio(baseUrl);

  BullnymHttpClient.withDio(
    Dio dio, {
    this._nowSecs = currentBullpayTimestampSecs,
  }) : _dio = dio;

  final Dio _dio;
  // Invoice actions are signed inside the client (unlike the donation-page
  // actions, which are signed in their usecases), so the client owns the
  // signing timestamp; injected for deterministic contract tests.
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

  @override
  Future<BullnymRegisterResult> register(BullnymRegisterRequest request) async {
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
  }

  @override
  Future<void> deleteRegistration(
    BullnymDeleteRegistrationRequest request,
  ) async {
    await _deleteSuccess(
      '/register',
      data: {
        'nym': request.nym,
        'npub': request.npubHex,
        'signature': request.signatureHex,
        'timestamp': request.timestamp,
      },
    );
  }

  @override
  Future<BullnymLookupResult> lookupRegistration({
    required String npubHex,
  }) async {
    final response = await _getMap(
      '/register/lookup',
      queryParameters: {'npub': npubHex},
    );
    return _parseLookupResponse(response);
  }

  @override
  Future<BullnymBackupHead> fetchBackup(
    BullnymBackupFetchRequest request,
  ) async {
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
  }

  @override
  Future<BullnymBackupStoreReceipt> storeBackup(
    BullnymBackupStoreRequest request,
  ) async {
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
  }

  @override
  Future<BullnymBackupDeleteReceipt> deleteBackup(
    BullnymBackupDeleteRequest request,
  ) async {
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
  }

  @override
  Future<BullnymDonationPage> getDonationPage({
    required String nym,
    required String kind,
  }) async {
    final response = await _getMap(
      '/donation-page/${Uri.encodeComponent(nym)}',
      queryParameters: {'kind': kind},
    );
    return _parseDonationPageResponse(response);
  }

  @override
  Future<BullnymDonationPage> saveDonationPage(
    BullnymSaveDonationPageRequest request,
  ) async {
    final response = await _putMap(
      '/donation-page',
      data: {
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
      },
    );
    return _parseDonationPageResponse(response);
  }

  @override
  Future<BullnymDonationPage> archiveDonationPage(
    BullnymArchiveDonationPageRequest request,
  ) async {
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
  }

  @override
  Future<BullnymSupportedCurrencies> getSupportedCurrencies() async {
    final response = await _getMap('/api/v1/supported-currencies');
    return _parseSupportedCurrenciesResponse(response);
  }

  @override
  Future<BullnymCreateInvoiceResponse> createInvoice({
    required BullnymAuthSigner signer,
    String? nym,
    required BullnymCreateInvoiceFields fields,
  }) async {
    final timestamp = _nowSecs();
    final signatureHex = await _signInvoiceAction(
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
  }

  @override
  Future<BullnymCancelInvoiceResponse> cancelInvoice({
    required BullnymAuthSigner signer,
    String? nym,
    required String invoiceId,
  }) async {
    final timestamp = _nowSecs();
    final signatureHex = await _signInvoiceAction(
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
  }

  @override
  Future<BullnymListInvoicesResponse> listInvoices({
    required BullnymAuthSigner signer,
    required int page,
    required int pageSize,
    String? status,
  }) async {
    final timestamp = _nowSecs();
    // The list is npub-wide: the signed nym slot is ALWAYS empty.
    final signatureHex = await _signInvoiceAction(
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
  }

  @override
  Future<BullnymInvoiceStatus> getInvoiceStatus({
    required String invoiceId,
  }) async {
    // Public, UNSIGNED: no signer, no signature — by id only.
    final response = await _getMap(
      '/api/v1/invoices/${Uri.encodeComponent(invoiceId)}/status',
    );
    return _parseInvoiceStatusResponse(response);
  }

  // `nym == null` → the unlinked collection; a nym → the linked collection.
  String _invoicesPath(String? nym) {
    if (nym == null) return '/api/v1/invoices';
    return '/api/v1/${Uri.encodeComponent(nym)}/invoices';
  }

  Future<String> _signInvoiceAction({
    required BullnymAuthSigner signer,
    required String action,
    required String nymOrEmpty,
    required List<String> payloadFields,
    required int timestampSecs,
  }) async {
    try {
      validateBullnymNpubHex(signer.npubHex);
      return await signBullpayAction(
        signer: signer,
        action: action,
        nymOrEmpty: nymOrEmpty,
        payloadFields: payloadFields,
        timestampSecs: timestampSecs,
      );
    } on BullnymException {
      rethrow;
    } catch (_) {
      throw const BullnymException.signingFailed();
    }
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
      throw _httpExceptionFromResponse(response);
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
      throw _networkException(e);
    }
  }

  BullnymException _networkException(DioException e) {
    final isTimeout =
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout;
    final diagnosticReason = e.message ?? 'Network request failed';
    if (isTimeout) {
      return BullnymException.timeout(diagnosticReason: diagnosticReason);
    }
    return BullnymException.network(diagnosticReason: diagnosticReason);
  }

  Map<String, dynamic> _decodeMap(Response<dynamic> response) {
    _throwIfBullnymError(response);
    final statusCode = response.statusCode;
    if (statusCode == null || statusCode < 200 || statusCode >= 300) {
      throw _httpExceptionFromResponse(response);
    }
    final data = _requireJson(response);
    if (data is Map<String, dynamic>) return data;
    throw BullnymException.invalidServerResponse(
      diagnosticReason: 'Server returned an unexpected response shape',
      statusCode: response.statusCode,
    );
  }

  dynamic _requireJson(Response<dynamic> response) {
    final data = response.data;
    if (data == null) {
      throw BullnymException.emptyResponse(statusCode: response.statusCode);
    }
    return data;
  }

  void _throwIfBullnymError(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic> && data['status'] == 'ERROR') {
      throw _serverErrorExceptionFromResponse(response);
    }
  }

  BullnymException _serverErrorExceptionFromResponse(
    Response<dynamic> response,
  ) {
    final data = response.data;
    if (data is Map<String, dynamic> && data['status'] == 'ERROR') {
      final code = data['code'];
      final reason = data['reason'];
      if (reason is! String) {
        return BullnymException.invalidServerResponse(
          diagnosticReason: 'Server error response is missing reason',
          statusCode: response.statusCode,
        );
      }
      return BullnymException.serverRejectedRequest(
        code: code is String ? code : 'ServerRejectedRequest',
        diagnosticReason: reason,
        statusCode: response.statusCode,
        retryable: _isRetryableStatus(response.statusCode),
      );
    }
    return BullnymException.unexpectedHttpStatus(
      statusCode: response.statusCode,
    );
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

  BullnymException _httpExceptionFromResponse(Response<dynamic> response) {
    if (response.data is Map<String, dynamic>) {
      return _serverErrorExceptionFromResponse(response);
    }
    return BullnymException.unexpectedHttpStatus(
      statusCode: response.statusCode,
    );
  }

  BullnymRegisterResult _parseRegisterResponse(Map<String, dynamic> json) {
    return BullnymRegisterResult(
      nym: _requiredString(json, 'nym'),
      lightningAddress: _requiredString(json, 'lightning_address'),
    );
  }

  BullnymLookupResult _parseLookupResponse(Map<String, dynamic> json) {
    return BullnymLookupResult(
      nym: _requiredString(json, 'nym'),
      active: _requiredBool(json, 'active'),
      lightningAddress: _optionalString(json, 'lightning_address'),
    );
  }

  String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String) return value;
    throw BullnymException.invalidServerResponse(
      diagnosticReason: 'Server response is missing string field $key',
    );
  }

  bool _requiredBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is bool) return value;
    throw BullnymException.invalidServerResponse(
      diagnosticReason: 'Server response is missing bool field $key',
    );
  }

  String? _optionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is String) return value;
    throw BullnymException.invalidServerResponse(
      diagnosticReason: 'Server response field $key is not a string',
    );
  }

  int _requiredInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int && value >= 0) return value;
    throw BullnymException.invalidServerResponse(
      diagnosticReason: 'Server response is missing integer field $key',
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

  int? _optionalInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is int) return value;
    throw BullnymException.invalidServerResponse(
      diagnosticReason: 'Server response field $key is not an int',
    );
  }

  // Tolerant reader: parse the KNOWN keys with type checks; unknown keys are
  // ignored so a future server field cannot crash an older binary.
  BullnymDonationPage _parseDonationPageResponse(Map<String, dynamic> json) {
    final kind = _requiredString(json, 'kind');
    return BullnymDonationPage(
      nym: _requiredString(json, 'nym'),
      header: _requiredString(json, 'header'),
      description: _requiredString(json, 'description'),
      displayCurrency: _requiredString(json, 'display_currency'),
      website: _optionalString(json, 'website'),
      twitter: _optionalString(json, 'twitter'),
      instagram: _optionalString(json, 'instagram'),
      kind: kind,
      posMode: kind == bullnymDonationPageKindPos,
      enabled: _requiredBool(json, 'enabled'),
      isArchived: _requiredBool(json, 'is_archived'),
      avatarSha256: _optionalString(json, 'avatar_sha256'),
      ogSha256: _optionalString(json, 'og_sha256'),
      publicUrl: _requiredString(json, 'public_url'),
    );
  }

  BullnymSupportedCurrencies _parseSupportedCurrenciesResponse(
    Map<String, dynamic> json,
  ) {
    final rawCurrencies = json['currencies'];
    if (rawCurrencies is! List) {
      throw BullnymException.invalidServerResponse(
        diagnosticReason: 'Server response is missing currencies list',
      );
    }
    final currencies = <BullnymSupportedCurrency>[];
    for (final raw in rawCurrencies) {
      if (raw is! Map<String, dynamic>) {
        throw BullnymException.invalidServerResponse(
          diagnosticReason: 'Server currency entry has an unexpected shape',
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
      throw BullnymException.invalidServerResponse(
        diagnosticReason: 'Server response is missing invoices list',
      );
    }
    final invoices = <BullnymInvoiceListItem>[];
    for (final raw in rawInvoices) {
      if (raw is! Map<String, dynamic>) {
        throw BullnymException.invalidServerResponse(
          diagnosticReason: 'Server invoice entry has an unexpected shape',
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

  BullnymInvoiceStatus _parseInvoiceStatusResponse(Map<String, dynamic> json) {
    return BullnymInvoiceStatus(
      status: _requiredString(json, 'status'),
      pricingMode: _requiredString(json, 'pricing_mode'),
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
      lightningPr: _optionalString(json, 'lightning_pr'),
      liquidAddress: _optionalString(json, 'liquid_address'),
      bitcoinAddress: _optionalString(json, 'bitcoin_address'),
      bitcoinChainAddress: _optionalString(json, 'bitcoin_chain_address'),
      bitcoinChainBip21: _optionalString(json, 'bitcoin_chain_bip21'),
      acceptBtc: _requiredBool(json, 'accept_btc'),
      acceptLn: _requiredBool(json, 'accept_ln'),
      acceptLiquid: _requiredBool(json, 'accept_liquid'),
    );
  }
}
