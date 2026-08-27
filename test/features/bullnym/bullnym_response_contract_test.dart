import 'dart:convert';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/data/bullnym_http_datasource.dart';
import 'package:bb_mobile/features/bullnym/data/bullnym_repository_impl.dart';
import 'package:bb_mobile/features/bullnym/data/bullnym_response_decoder.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_fiat_settlement.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_public_names.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_signing.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('transport failures', () {
    test('decodes coded error envelopes before HTTP status', () async {
      final repository = _repository(
        status: 409,
        data: {
          'status': 'ERROR',
          'code': 'NymTaken',
          'reason': 'diagnostic only',
        },
      );

      final result = await repository.getVersion();
      final failure = (result as Err<Object?, BullnymFailure>).failure;

      expect(
        failure,
        isA<BullnymServerFailure>()
            .having((value) => value.code, 'normalized code', 'NameTaken')
            .having((value) => value.statusCode, 'status', 409)
            .having((value) => value.retryable, 'retryable', false),
      );
    });

    test('preserves structured ownership conflict details', () async {
      final repository = _repository(
        status: 409,
        data: {
          'status': 'ERROR',
          'code': 'AliasAlreadyAssigned',
          'reason': 'diagnostic only',
          'details': {'alias': 'shop'},
        },
      );

      final result = await repository.getVersion();
      final failure = (result as Err<Object?, BullnymFailure>).failure;

      expect(
        (failure as BullnymServerFailure).ownedNameDetails,
        isA<BullnymOwnedAliasDetails>().having(
          (value) => value.alias.value,
          'alias',
          'shop',
        ),
      );
    });

    test('marks a timed-out write as uncertain', () async {
      final repository = _throwingRepository(DioExceptionType.receiveTimeout);

      final result = await repository.deleteRegistration(
        auth: _auth,
        nym: 'alice',
      );
      final failure = (result as Err<void, BullnymFailure>).failure;

      expect(
        failure,
        isA<BullnymNetworkFailure>()
            .having((value) => value.timeout, 'timeout', true)
            .having((value) => value.outcomeUncertain, 'uncertain', true)
            .having(
              (value) => value.phase,
              'phase',
              BullnymRequestPhase.delete,
            ),
      );
    });

    test('does not mark a failed read as an uncertain mutation', () async {
      final repository = _throwingRepository(DioExceptionType.connectionError);

      final result = await repository.getVersion();
      final failure = (result as Err<Object?, BullnymFailure>).failure;

      expect(
        failure,
        isA<BullnymNetworkFailure>().having(
          (value) => value.outcomeUncertain,
          'uncertain',
          false,
        ),
      );
    });

    test('rejects malformed known response fields', () async {
      final repository = _repository(
        status: 200,
        data: {'public_name_policy': 1},
      );

      final result = await repository.getVersion();

      expect(result, isA<Err<Object?, BullnymFailure>>());
      expect(
        (result as Err<Object?, BullnymFailure>).failure,
        isA<BullnymInvalidResponseFailure>(),
      );
    });

    test('treats a 404 fiat endpoint as old-server compatibility', () async {
      final repository = _repository(status: 404, data: 'not found');

      final result = await repository.getFiatSettlementConfiguration(_auth);

      expect(
        result,
        isA<Ok<BullnymFiatSettlementConfiguration, BullnymFailure>>()
            .having((value) => value.value.settings, 'settings', isEmpty)
            .having(
              (value) => value.value.credentialStatus,
              'credential',
              BullnymCredentialStatus.unknown,
            ),
      );
    });
  });

  group('strict data boundaries', () {
    final decoder = BullnymResponseDecoder(
      Uri(scheme: 'https', host: 'pay.example'),
    );

    test(
      'accepts only canonical public URLs for the returned owner and kind',
      () {
        final page = decoder.donationPage({
          ..._page,
          'alias': 'shop',
          'public_url': 'https://pay.example/a/shop',
        });
        expect(page.publicUrl, 'https://pay.example/a/shop');

        expect(
          () => decoder.donationPage({
            ..._page,
            'public_url': 'https://evil.example/alice',
          }),
          throwsA(isA<BullnymProtocolException>()),
        );
      },
    );

    test('enforces canonical ciphertext and the 2 MiB bound', () {
      final encoded = base64.encode(List.filled(64, 1));
      expect(BullnymBackupCiphertext(encoded).byteLength, 64);
      expect(() => BullnymBackupCiphertext(' $encoded'), throwsArgumentError);
      expect(
        () => BullnymBackupCiphertext(base64.encode(List.filled(63, 1))),
        throwsArgumentError,
      );
    });

    test('distinguishes absent and malformed settlement projections', () {
      expect(decodeBullnymSettlement(const {}), isNull);
      expect(
        decodeBullnymSettlement(const {'settlement_kind': 'future'}),
        same(BullnymGetPaidSettlement.unavailable),
      );
    });

    test('parses a complete mixed settlement without deriving its truth', () {
      final settlement = decodeBullnymSettlement({
        'settlement_kind': 'mixed',
        'settlement_details': {
          'kind': 'mixed',
          'fiat_percentage': 50,
          'creation_rate_minor_per_btc': 6000000000,
          'creation_rate_currency': 'USD',
          'fiat': [
            {
              'amount_minor': 500,
              'quoted_amount_minor': 500,
              'execution_rate_minor_per_btc': 6100000000,
              'currency': 'USD',
              'order_id': '11111111-1111-1111-1111-111111111111',
              'status': 'settled',
            },
          ],
          'bitcoin': [
            {'amount_sat': 1000, 'network': 'liquid', 'status': 'settled'},
          ],
        },
      });

      expect(settlement?.kind, BullnymSettlementKind.mixed);
      expect(settlement?.fiatPercentage, 50);
      expect(settlement?.fiat.single.amountMinor, 500);
      expect(settlement?.bitcoin.single.amountSat, 1000);
    });

    test('fails the entire settlement projection closed on one bad leg', () {
      final settlement = decodeBullnymSettlement({
        'settlement_kind': 'fiat',
        'settlement_details': {
          'kind': 'fiat',
          'fiat': [
            {
              'amount_minor': null,
              'quoted_amount_minor': 500,
              'execution_rate_minor_per_btc': null,
              'currency': 'DOGE',
              'order_id': '11111111-1111-1111-1111-111111111111',
              'status': 'pending',
            },
          ],
        },
      });

      expect(settlement, same(BullnymGetPaidSettlement.unavailable));
    });
  });
}

final _auth = BullnymAuthentication(
  npubHex: '11' * 32,
  signatureHex: '22' * 64,
  timestamp: 1710000000,
);

BullnymRepositoryImpl _repository({
  required int status,
  required Object? data,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: status,
            data: data,
          ),
        ),
      ),
    );
  return BullnymRepositoryImpl(
    BullnymHttpDatasource.withDio(dio),
    BullnymResponseDecoder(Uri(scheme: 'http', host: 'localhost')),
  );
}

BullnymRepositoryImpl _throwingRepository(DioExceptionType type) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) =>
            handler.reject(DioException(requestOptions: options, type: type)),
      ),
    );
  return BullnymRepositoryImpl(
    BullnymHttpDatasource.withDio(dio),
    BullnymResponseDecoder(Uri(scheme: 'http', host: 'localhost')),
  );
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
  'public_url': 'https://pay.example/alice',
};
