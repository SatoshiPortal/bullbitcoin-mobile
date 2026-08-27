import 'dart:convert';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/data/bullnym_http_datasource.dart';
import 'package:bb_mobile/features/bullnym/data/bullnym_repository_impl.dart';
import 'package:bb_mobile/features/bullnym/data/bullnym_response_decoder.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_donation_page.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_fiat_settlement.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_invoice.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_invoice_quote.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_public_names.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_registration.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_signing.dart';
import 'package:bb_mobile/features/bullnym/domain/repositories/bullnym_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const auth = BullnymAuthentication(
    npubHex: 'c071c9ae5ef050c69bb38f8ff03c35f1a89b50ef9ad951e5b4f2d1fb9e8e0e4d',
    signatureHex:
        '11a90a7242720482d42a2853d7b128eb9de7346934f1cfbdb6ce8368b5e9a262'
        '440a6f09a256247d78d4d501c291aa10349aa23609c72a9ab179ba29a59411e0',
    timestamp: 1710000000,
  );

  test('uses the frozen method and path for every endpoint', () async {
    final cases = <_EndpointCase>[
      _EndpointCase('GET', '/version', {
        'public_name_policy': null,
      }, (repo) => repo.getVersion()),
      _EndpointCase(
        'POST',
        '/register',
        {'nym': 'alice', 'lightning_address': 'alice@example.com'},
        (repo) => repo.register(
          auth: auth,
          nym: 'alice',
          ctDescriptor: 'descriptor',
          verificationNpubHex: '22' * 32,
        ),
      ),
      _EndpointCase(
        'DELETE',
        '/register',
        null,
        (repo) => repo.deleteRegistration(auth: auth, nym: 'alice'),
      ),
      _EndpointCase('GET', '/register/lookup', {
        'nym': 'alice',
        'active': true,
        'lightning_address': 'alice@example.com',
      }, (repo) => repo.lookupRegistration(auth.npubHex)),
      _EndpointCase(
        'GET',
        '/donation-page/alice',
        _page,
        (repo) => repo.getDonationPage(nym: 'alice', kind: 'payment_page'),
      ),
      _EndpointCase(
        'PUT',
        '/donation-page',
        _page,
        (repo) => repo.saveDonationPage(
          auth: auth,
          nym: 'alice',
          ctDescriptor: 'descriptor',
          header: 'Header',
          description: 'Description',
          displayCurrency: 'USD',
          website: '',
          twitter: '',
          instagram: '',
          enabled: true,
          kind: 'payment_page',
          aliasIntent: BullnymAliasIntent.claim(BullnymPublicName('shop')),
        ),
      ),
      _EndpointCase(
        'DELETE',
        '/donation-page',
        _page,
        (repo) => repo.archiveDonationPage(
          auth: auth,
          nym: 'alice',
          kind: 'payment_page',
        ),
      ),
      _EndpointCase(
        'GET',
        '/api/v1/supported-currencies',
        {
          'currencies': [
            {'code': 'USD', 'precision': 2},
          ],
        },
        (repo) => repo.getSupportedCurrencies(),
      ),
      _EndpointCase(
        'GET',
        '/api/v1/recovery-address',
        {
          'version': 1,
          'recovery_address_registered': false,
          'btc_address': null,
          'commitment_version': null,
          'signed_at_unix': null,
        },
        (repo) => repo.lookupRecoveryAddress(auth),
      ),
      _EndpointCase(
        'PUT',
        '/api/v1/recovery-address',
        {
          'version': 1,
          'recovery_address_registered': true,
          'signed_at_unix': auth.timestamp,
        },
        (repo) =>
            repo.registerRecoveryAddress(auth: auth, btcAddress: 'bc1qaddress'),
      ),
      _EndpointCase(
        'POST',
        '/api/v1/invoices',
        {'invoice_id': 'invoice-id', 'invoice_url': 'https://example.com/i'},
        (repo) =>
            repo.createInvoice(auth: auth, nym: null, fields: _invoiceFields),
      ),
      _EndpointCase(
        'DELETE',
        '/api/v1/alice/invoices/invoice-id',
        {'invoice_id': 'invoice-id', 'status': 'cancelled'},
        (repo) => repo.cancelInvoice(
          auth: auth,
          nym: 'alice',
          invoiceId: 'invoice-id',
        ),
      ),
      _EndpointCase(
        'GET',
        '/api/v1/invoices',
        {'invoices': [], 'page': 1, 'pageSize': 25, 'has_more': false},
        (repo) =>
            repo.listInvoices(auth: auth, page: 1, pageSize: 25, status: null),
      ),
      _EndpointCase(
        'GET',
        '/api/v1/invoices/recoverable',
        {'items': [], 'count': 0, 'has_more': false},
        (repo) => repo.listFallbackSupervision(auth),
      ),
      _EndpointCase(
        'GET',
        '/api/v1/get-paid/transactions',
        {'transactions': [], 'next_cursor': null},
        (repo) =>
            repo.listGetPaidTransactions(auth: auth, cursor: '', limit: 25),
      ),
      _EndpointCase(
        'GET',
        '/api/v1/invoices/invoice-id/status',
        _invoiceStatus,
        (repo) => repo.getInvoiceStatus('invoice-id'),
      ),
      _EndpointCase(
        'POST',
        '/api/v1/invoices/invoice-id/quote',
        _invoiceQuote,
        (repo) => repo.getInvoiceQuote(
          invoiceId: 'invoice-id',
          rail: BullnymPayerQuoteRail.liquid,
        ),
      ),
      _EndpointCase(
        'GET',
        '/api/v1/fiat-settlement',
        {'version': 1, 'settings': [], 'credential_status': 'absent'},
        (repo) => repo.getFiatSettlementConfiguration(auth),
      ),
      _EndpointCase(
        'PUT',
        '/api/v1/fiat-settlement/payment_page',
        {'version': 1, 'settings': [], 'credential_status': 'active'},
        (repo) => repo.setFiatSettlement(
          auth: auth,
          product: BullnymFiatSettlementProduct.paymentPage,
          fiatPercentage: 50,
          fiatCurrency: 'USD',
          apiKey: 'scoped-key',
        ),
      ),
      _EndpointCase(
        'POST',
        '/api/v1/wallet-backups/fetch',
        {
          'version': 1,
          'found': false,
          'generation': 0,
          'etag': null,
          'updated_at': null,
        },
        (repo) => repo.fetchBackup(
          auth: auth,
          stream: BullnymBackupStream.walletBackup,
        ),
      ),
      _EndpointCase(
        'PUT',
        '/api/v1/wallet-backups',
        {'version': 1, 'generation': 1, 'etag': '44' * 32},
        (repo) => repo.storeBackup(
          auth: auth,
          stream: BullnymBackupStream.walletBackup,
          generation: 1,
          expectedEtag: null,
          ciphertext: BullnymBackupCiphertext(
            base64.encode(List.filled(64, 1)),
          ),
          ciphertextSha256: '33' * 32,
        ),
      ),
      _EndpointCase(
        'DELETE',
        '/api/v1/wallet-backups',
        {'version': 1, 'generation': 2, 'etag': '55' * 32},
        (repo) => repo.deleteBackup(
          auth: auth,
          stream: BullnymBackupStream.walletBackup,
          generation: 2,
          expectedEtag: '44' * 32,
        ),
      ),
    ];

    for (final endpoint in cases) {
      final harness = _Harness(endpoint.response);
      final result = await endpoint.invoke(harness.repository);
      expect(result, isNotNull, reason: endpoint.path);
      expect(harness.request.method, endpoint.method, reason: endpoint.path);
      expect(harness.request.path, endpoint.path, reason: endpoint.path);
    }
  });

  test('keeps endpoint-specific signed fields and omission rules', () async {
    final harness = _Harness(_page);
    final result = await harness.repository.saveDonationPage(
      auth: auth,
      nym: 'alice',
      ctDescriptor: 'descriptor',
      header: 'Header',
      description: 'Description',
      displayCurrency: 'USD',
      website: '',
      twitter: '',
      instagram: '',
      enabled: true,
      kind: 'payment_page',
      aliasIntent: const BullnymAliasIntent.preserve(),
    );
    expect(result, isA<Ok<BullnymDonationPage, BullnymFailure>>());
    final body = Map<String, dynamic>.from(harness.request.data as Map);
    expect(body, isNot(contains('alias')));
    expect(body, isNot(contains('pos_mode')));
    expect(body['kind'], 'payment_page');
    expect(body['ct_descriptor'], 'descriptor');
  });

  test('registration lookup sends only the public identity', () async {
    final harness = _Harness({
      'nym': 'alice',
      'active': true,
      'lightning_address': 'alice@example.com',
    });

    final result = await harness.repository.lookupRegistration(auth.npubHex);

    expect(result, isA<Ok<BullnymLookupResult, BullnymFailure>>());
    expect(harness.request.queryParameters, {'npub': auth.npubHex});
  });

  test(
    'uses camel-case pageSize and keeps identity-wide nym out of queries',
    () async {
      final harness = _Harness({
        'invoices': [],
        'page': 2,
        'pageSize': 50,
        'has_more': false,
      });
      final result = await harness.repository.listInvoices(
        auth: auth,
        page: 2,
        pageSize: 50,
        status: 'open',
      );
      expect(result, isA<Ok<BullnymListInvoicesResponse, BullnymFailure>>());

      expect(harness.request.queryParameters, containsPair('pageSize', 50));
      expect(harness.request.queryParameters, isNot(contains('nym')));
      expect(harness.request.queryParameters, containsPair('status', 'open'));
    },
  );

  test('fiat disable omits currency and API key from the wire body', () async {
    final harness = _Harness({
      'version': 1,
      'settings': [],
      'credential_status': 'absent',
    });
    final result = await harness.repository.setFiatSettlement(
      auth: auth,
      product: BullnymFiatSettlementProduct.invoice,
      fiatPercentage: 0,
      fiatCurrency: null,
      apiKey: null,
    );
    expect(
      result,
      isA<Ok<BullnymFiatSettlementConfiguration, BullnymFailure>>(),
    );

    final body = Map<String, dynamic>.from(harness.request.data as Map);
    expect(body, isNot(contains('fiat_currency')));
    expect(body, isNot(contains('api_key')));
  });
}

typedef _Invoke = Future<Object?> Function(BullnymRepository repository);

final class _EndpointCase {
  final String method;
  final String path;
  final Object? response;
  final _Invoke invoke;

  const _EndpointCase(this.method, this.path, this.response, this.invoke);
}

final class _Harness {
  late final RequestOptions request;
  late final BullnymRepository repository;

  _Harness(Object? response) {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            request = options;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: response,
              ),
            );
          },
        ),
      );
    repository = BullnymRepositoryImpl(
      BullnymHttpDatasource.withDio(dio),
      BullnymResponseDecoder(Uri.parse('http://localhost')),
    );
  }
}

const _page = {
  'nym': 'alice',
  'header': 'Header',
  'description': 'Description',
  'display_currency': 'USD',
  'website': null,
  'twitter': null,
  'instagram': null,
  'kind': 'payment_page',
  'enabled': true,
  'is_archived': false,
  'avatar_sha256': null,
  'og_sha256': null,
  'alias': null,
  'public_url': 'http://localhost/alice',
};

const _invoiceFields = BullnymCreateInvoiceFields(
  amountSat: 1000,
  clientRequestId: 'request-id',
  presentationEnvelope: 'envelope',
  acceptBtc: true,
  acceptLn: true,
  acceptLiquid: true,
);

const _invoiceStatus = {
  'status': 'open',
  'presentation_status': null,
  'pricing_mode': 'sat_fixed',
  'settlement_status': 'pending',
  'amount_sat': 1000,
  'fiat_amount_minor': null,
  'fiat_currency': null,
  'remaining_amount_sat': 1000,
  'accepting_payments': true,
  'top_up_allowed': true,
  'payment_tolerance_sat': 10,
  'rate_minor_per_btc': null,
  'creation_rate_minor_per_btc': null,
  'rate_locks_until_unix': 0,
  'expires_at_unix': 1710000300,
  'paid_via': null,
  'paid_at_unix': null,
  'paid_amount_sat': null,
  'lightning_pr': null,
  'lightning_amount_sat': null,
  'liquid_address': null,
  'liquid_amount_sat': null,
  'bitcoin_address': null,
  'bitcoin_chain_address': null,
  'bitcoin_chain_bip21': null,
  'bitcoin_chain_amount_sat': null,
  'accept_btc': true,
  'accept_ln': true,
  'accept_liquid': true,
  'bitcoin_direct_observations': [],
  'quote_rail_availability': null,
};

const _invoiceQuote = {
  'pricing_mode': 'fiat_fixed',
  'invoice_id': 'invoice-id',
  'selected_rail': 'liquid',
  'quote': {
    'quote_version_id': 'version-id',
    'version_number': 1,
    'fiat_face_amount_minor': 1000,
    'fiat_target_amount_minor': 900,
    'fiat_currency': 'USD',
    'rate_minor_per_btc': 6000000000,
    'rate_source': 'provider',
    'rate_observed_at_unix': 1710000000,
    'rate_fetched_at_unix': 1710000001,
    'rate_fresh_until_unix': 1710000060,
    'merchant_amount_sat': 1500,
    'created_at_unix': 1710000000,
    'expires_at_unix': 1710000300,
  },
  'instruction': {
    'kind': 'liquid_direct',
    'address': 'lq1address',
    'payer_amount_sat': 1500,
  },
};
