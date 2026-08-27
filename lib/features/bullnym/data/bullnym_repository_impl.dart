import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/data/bullnym_http_datasource.dart';
import 'package:bb_mobile/features/bullnym/data/bullnym_response_decoder.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_donation_page.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_fiat_settlement.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_fallback_supervision.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_get_paid_transaction.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_invoice.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_invoice_quote.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_public_names.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_recovery_address.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_registration.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_signing.dart';
import 'package:bb_mobile/features/bullnym/domain/repositories/bullnym_repository.dart';
import 'package:dio/dio.dart';

final class BullnymRepositoryImpl implements BullnymRepository {
  final BullnymHttpDatasource _http;
  final BullnymResponseDecoder _decoder;

  const BullnymRepositoryImpl(this._http, this._decoder);

  @override
  Future<Result<BullnymVersionInfo, BullnymFailure>> getVersion() => _map(
    BullnymRequestPhase.read,
    () => _http.get('/version'),
    _decoder.version,
  );

  @override
  Future<Result<BullnymRegisterResult, BullnymFailure>> register({
    required BullnymAuthentication auth,
    required String nym,
    required String ctDescriptor,
    required String verificationNpubHex,
  }) => _map(
    BullnymRequestPhase.write,
    () => _http.post(
      '/register',
      data: {
        'nym': nym,
        'ct_descriptor': ctDescriptor,
        'verification_npub': verificationNpubHex,
        ..._authBody(auth),
      },
    ),
    _decoder.registration,
  );

  @override
  Future<Result<void, BullnymFailure>> deleteRegistration({
    required BullnymAuthentication auth,
    required String nym,
  }) => _empty(
    BullnymRequestPhase.delete,
    () => _http.delete('/register', data: {'nym': nym, ..._authBody(auth)}),
  );

  @override
  Future<Result<BullnymLookupResult, BullnymFailure>> lookupRegistration(
    String npubHex,
  ) => _map(
    BullnymRequestPhase.read,
    () => _http.get('/register/lookup', query: {'npub': npubHex}),
    _decoder.lookup,
  );

  @override
  Future<Result<BullnymDonationPage, BullnymFailure>> getDonationPage({
    required String nym,
    required String kind,
  }) => _map(
    BullnymRequestPhase.read,
    () => _http.get(
      '/donation-page/${Uri.encodeComponent(nym)}',
      query: {'kind': kind},
    ),
    _decoder.donationPage,
  );

  @override
  Future<Result<BullnymDonationPage, BullnymFailure>> saveDonationPage({
    required BullnymAuthentication auth,
    required String nym,
    required String ctDescriptor,
    required String header,
    required String description,
    required String displayCurrency,
    required String website,
    required String twitter,
    required String instagram,
    required bool enabled,
    required String kind,
    required BullnymAliasIntent aliasIntent,
  }) => _map(
    BullnymRequestPhase.write,
    () => _http.put(
      '/donation-page',
      data: {
        'nym': nym,
        'ct_descriptor': ctDescriptor,
        'header': header,
        'description': description,
        'display_currency': displayCurrency,
        'website': website,
        'twitter': twitter,
        'instagram': instagram,
        'enabled': enabled,
        'kind': kind,
        if (aliasIntent case BullnymAliasClaim(:final alias))
          'alias': alias.value,
        ..._authBody(auth),
      },
    ),
    _decoder.donationPage,
  );

  @override
  Future<Result<BullnymDonationPage, BullnymFailure>> archiveDonationPage({
    required BullnymAuthentication auth,
    required String nym,
    required String kind,
  }) => _map(
    BullnymRequestPhase.delete,
    () => _http.delete(
      '/donation-page',
      data: {'nym': nym, 'kind': kind, ..._authBody(auth)},
    ),
    _decoder.donationPage,
  );

  @override
  Future<Result<BullnymSupportedCurrencies, BullnymFailure>>
  getSupportedCurrencies() => _map(
    BullnymRequestPhase.read,
    () => _http.get('/api/v1/supported-currencies'),
    _decoder.currencies,
  );

  @override
  Future<Result<BullnymRecoveryAddressLookupResult, BullnymFailure>>
  lookupRecoveryAddress(BullnymAuthentication auth) => _map(
    BullnymRequestPhase.read,
    () => _http.get('/api/v1/recovery-address', query: _authQuery(auth)),
    _decoder.recoveryAddress,
  );

  @override
  Future<Result<BullnymRecoveryAddressRegistrationResult, BullnymFailure>>
  registerRecoveryAddress({
    required BullnymAuthentication auth,
    required String btcAddress,
  }) => _map(
    BullnymRequestPhase.write,
    () => _http.put(
      '/api/v1/recovery-address',
      data: {
        'version': bullnymRecoveryAddressContractVersion,
        'btc_address': btcAddress,
        ..._authBody(auth),
      },
    ),
    (json) => _decoder.recoveryAddressReceipt(json, auth.timestamp),
  );

  @override
  Future<Result<BullnymCreateInvoiceResponse, BullnymFailure>> createInvoice({
    required BullnymAuthentication auth,
    required String? nym,
    required BullnymCreateInvoiceFields fields,
  }) => _map(
    BullnymRequestPhase.write,
    () => _http.post(
      _invoicesPath(nym),
      data: {
        'npub': auth.npubHex,
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
        'timestamp': auth.timestamp,
        'signature': auth.signatureHex,
      },
    ),
    _decoder.createdInvoice,
  );

  @override
  Future<Result<BullnymCancelInvoiceResponse, BullnymFailure>> cancelInvoice({
    required BullnymAuthentication auth,
    required String? nym,
    required String invoiceId,
  }) => _map(
    BullnymRequestPhase.delete,
    () => _http.delete(
      '${_invoicesPath(nym)}/${Uri.encodeComponent(invoiceId)}',
      data: _authBody(auth),
    ),
    _decoder.cancelledInvoice,
  );

  @override
  Future<Result<BullnymListInvoicesResponse, BullnymFailure>> listInvoices({
    required BullnymAuthentication auth,
    required int page,
    required int pageSize,
    required String? status,
  }) => _map(
    BullnymRequestPhase.read,
    () => _http.get(
      '/api/v1/invoices',
      query: {
        ..._authQuery(auth),
        'page': page,
        'pageSize': pageSize,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    ),
    _decoder.invoices,
  );

  @override
  Future<Result<BullnymFallbackSupervisionResponse, BullnymFailure>>
  listFallbackSupervision(BullnymAuthentication auth) => _map(
    BullnymRequestPhase.read,
    () => _http.get('/api/v1/invoices/recoverable', query: _authQuery(auth)),
    _decoder.fallbackSupervision,
  );

  @override
  Future<Result<BullnymGetPaidTransactionPage, BullnymFailure>>
  listGetPaidTransactions({
    required BullnymAuthentication auth,
    required String cursor,
    required int limit,
  }) => _map(
    BullnymRequestPhase.read,
    () => _http.get(
      '/api/v1/get-paid/transactions',
      query: {..._authQuery(auth), 'cursor': cursor, 'limit': limit},
    ),
    (json) => _decoder.getPaidTransactions(
      json,
      requestedCursor: cursor,
      requestedLimit: limit,
    ),
  );

  @override
  Future<Result<BullnymInvoiceStatus, BullnymFailure>> getInvoiceStatus(
    String invoiceId,
  ) => _map(
    BullnymRequestPhase.read,
    () =>
        _http.get('/api/v1/invoices/${Uri.encodeComponent(invoiceId)}/status'),
    _decoder.invoiceStatus,
  );

  @override
  Future<Result<BullnymPayerDemandQuoteResponse, BullnymFailure>>
  getInvoiceQuote({
    required String invoiceId,
    required BullnymPayerQuoteRail rail,
  }) => _map(
    BullnymRequestPhase.write,
    () => _http.post(
      '/api/v1/invoices/${Uri.encodeComponent(invoiceId)}/quote',
      data: {'rail': rail.wire},
    ),
    (json) => _decoder.invoiceQuote(json, invoiceId: invoiceId, rail: rail),
  );

  @override
  Future<Result<BullnymFiatSettlementConfiguration, BullnymFailure>>
  getFiatSettlementConfiguration(BullnymAuthentication auth) async {
    return _guard(BullnymRequestPhase.read, () async {
      final response = await _http.get(
        '/api/v1/fiat-settlement',
        query: {
          'version': bullnymFiatSettlementContractVersion,
          ..._authQuery(auth),
        },
      );
      if (response.statusCode == 404) {
        return const BullnymFiatSettlementConfiguration(
          settings: [],
          credentialStatus: BullnymCredentialStatus.unknown,
        );
      }
      return _decoder.fiatSettlement(
        _responseMap(response, BullnymRequestPhase.read),
      );
    });
  }

  @override
  Future<Result<BullnymFiatSettlementConfiguration, BullnymFailure>>
  setFiatSettlement({
    required BullnymAuthentication auth,
    required BullnymFiatSettlementProduct product,
    required int fiatPercentage,
    required String? fiatCurrency,
    required String? apiKey,
  }) => _map(
    BullnymRequestPhase.write,
    () => _http.put(
      '/api/v1/fiat-settlement/${Uri.encodeComponent(product.wire)}',
      data: {
        'version': bullnymFiatSettlementContractVersion,
        'npub': auth.npubHex,
        'fiat_percentage': fiatPercentage,
        'fiat_currency': ?fiatCurrency,
        'api_key': ?apiKey,
        'timestamp': auth.timestamp,
        'signature': auth.signatureHex,
      },
    ),
    _decoder.fiatSettlement,
  );

  @override
  Future<Result<BullnymBackupHead, BullnymFailure>> fetchBackup({
    required BullnymAuthentication auth,
    required BullnymBackupStream stream,
  }) => _map(
    BullnymRequestPhase.read,
    () => _http.post(
      '/api/v1/wallet-backups/fetch',
      data: {'version': 1, 'stream': stream.wireName, ..._authBody(auth)},
    ),
    (json) => _decoder.backupHead(json, stream: stream, npubHex: auth.npubHex),
  );

  @override
  Future<Result<BullnymBackupStoreReceipt, BullnymFailure>> storeBackup({
    required BullnymAuthentication auth,
    required BullnymBackupStream stream,
    required int generation,
    required String? expectedEtag,
    required BullnymBackupCiphertext ciphertext,
    required String ciphertextSha256,
  }) => _map(
    BullnymRequestPhase.write,
    () => _http.put(
      '/api/v1/wallet-backups',
      data: {
        'version': 1,
        'stream': stream.wireName,
        'npub': auth.npubHex,
        'generation': generation,
        'expected_etag': expectedEtag,
        'ciphertext': ciphertext.value,
        'ciphertext_sha256': ciphertextSha256,
        'ciphertext_bytes': ciphertext.byteLength,
        'timestamp': auth.timestamp,
        'signature': auth.signatureHex,
      },
    ),
    (json) => _decoder.backupStoreReceipt(json, generation: generation),
  );

  @override
  Future<Result<BullnymBackupDeleteReceipt, BullnymFailure>> deleteBackup({
    required BullnymAuthentication auth,
    required BullnymBackupStream stream,
    required int generation,
    required String expectedEtag,
  }) => _map(
    BullnymRequestPhase.delete,
    () => _http.delete(
      '/api/v1/wallet-backups',
      data: {
        'version': 1,
        'stream': stream.wireName,
        'npub': auth.npubHex,
        'generation': generation,
        'expected_etag': expectedEtag,
        'timestamp': auth.timestamp,
        'signature': auth.signatureHex,
      },
    ),
    (json) => _decoder.backupDeleteReceipt(json, generation: generation),
  );

  Future<Result<T, BullnymFailure>> _map<T>(
    BullnymRequestPhase phase,
    Future<Response<dynamic>> Function() request,
    T Function(Map<String, dynamic>) decode,
  ) => _guard(phase, () async => decode(_responseMap(await request(), phase)));

  Future<Result<void, BullnymFailure>> _empty(
    BullnymRequestPhase phase,
    Future<Response<dynamic>> Function() request,
  ) => _guard(phase, () async {
    _accept(await request(), phase, allowEmpty: true);
  });

  Future<Result<T, BullnymFailure>> _guard<T>(
    BullnymRequestPhase phase,
    Future<T> Function() operation,
  ) async {
    try {
      return Ok(await operation());
    } on BullnymProtocolException catch (error, stack) {
      log.warning(
        'Bullnym protocol request failed',
        error: error.failure.runtimeType,
        trace: stack,
      );
      return Err(error.failure);
    } on DioException catch (error, stack) {
      if (error.response case final response?) {
        try {
          _accept(response, phase);
        } on BullnymProtocolException catch (protocol) {
          return Err(protocol.failure);
        }
      }
      final timeout = const {
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      }.contains(error.type);
      log.warning(
        'Bullnym network request failed',
        error: error.runtimeType,
        trace: stack,
      );
      return Err(
        BullnymNetworkFailure(
          phase: phase,
          timeout: timeout,
          outcomeUncertain:
              phase == BullnymRequestPhase.write ||
              phase == BullnymRequestPhase.delete,
        ),
      );
    } on Exception catch (error, stack) {
      log.warning(
        'Bullnym request failed unexpectedly',
        error: error.runtimeType,
        trace: stack,
      );
      return Err(BullnymUnexpectedFailure(phase: phase));
    }
  }

  Map<String, dynamic> _responseMap(
    Response<dynamic> response,
    BullnymRequestPhase phase,
  ) {
    final data = _accept(response, phase);
    if (data is Map<String, dynamic>) return data;
    throw BullnymProtocolException(
      BullnymInvalidResponseFailure(
        phase: phase,
        statusCode: response.statusCode,
        logMessage: 'Unexpected response shape',
      ),
    );
  }

  Object? _accept(
    Response<dynamic> response,
    BullnymRequestPhase phase, {
    bool allowEmpty = false,
  }) {
    final data = response.data;
    if (data is Map<String, dynamic> && data['status'] == 'ERROR') {
      final reason = data['reason'];
      if (reason is! String) {
        throw BullnymProtocolException(
          BullnymInvalidResponseFailure(
            phase: phase,
            statusCode: response.statusCode,
            logMessage: 'Malformed error envelope',
          ),
        );
      }
      final rawCode = data['code'];
      final code = rawCode == 'NymTaken'
          ? 'NameTaken'
          : rawCode is String
          ? rawCode
          : 'ServerRejectedRequest';
      throw BullnymProtocolException(
        BullnymServerFailure(
          phase: phase,
          code: code,
          statusCode: response.statusCode,
          retryable: _retryable(response.statusCode),
          ownedNameDetails: _ownedName(code, data['details'], phase),
          logMessage: reason,
        ),
      );
    }
    final status = response.statusCode;
    if (status == null || status < 200 || status >= 300) {
      throw BullnymProtocolException(
        BullnymServerFailure(
          phase: phase,
          code: 'HttpError',
          statusCode: status,
          retryable: _retryable(status),
        ),
      );
    }
    if (data == null && !allowEmpty) {
      throw BullnymProtocolException(
        BullnymInvalidResponseFailure(
          phase: phase,
          statusCode: status,
          logMessage: 'Empty response',
        ),
      );
    }
    return data;
  }

  BullnymOwnedNameDetails? _ownedName(
    String code,
    Object? value,
    BullnymRequestPhase phase,
  ) {
    if (value == null ||
        (code != 'NymAlreadyAssigned' && code != 'AliasAlreadyAssigned')) {
      return null;
    }
    if (value is! Map<String, dynamic>) {
      throw BullnymProtocolException(
        BullnymInvalidResponseFailure(
          phase: phase,
          logMessage: 'Invalid conflict details',
        ),
      );
    }
    try {
      return switch (code) {
        'NymAlreadyAssigned' => BullnymOwnedNymDetails(
          nym: BullnymPublicName(JsonReader(value).string('nym')),
          domain: JsonReader(value).optionalString('domain'),
        ),
        _ => BullnymOwnedAliasDetails(
          alias: BullnymPublicName(JsonReader(value).string('alias')),
        ),
      };
    } on ArgumentError {
      throw BullnymProtocolException(
        BullnymInvalidResponseFailure(
          phase: phase,
          logMessage: 'Invalid conflict name',
        ),
      );
    }
  }

  Map<String, dynamic> _authBody(BullnymAuthentication auth) => {
    'npub': auth.npubHex,
    'timestamp': auth.timestamp,
    'signature': auth.signatureHex,
  };

  Map<String, dynamic> _authQuery(BullnymAuthentication auth) =>
      _authBody(auth);

  String _invoicesPath(String? nym) => nym == null
      ? '/api/v1/invoices'
      : '/api/v1/${Uri.encodeComponent(nym)}/invoices';

  bool _retryable(int? status) =>
      status == null || status == 408 || status == 429 || status >= 500;
}
