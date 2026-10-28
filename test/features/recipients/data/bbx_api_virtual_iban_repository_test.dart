import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/data/bbx_api_virtual_iban_repository.dart';
import 'package:bb_mobile/features/recipients/domain/entities/virtual_iban.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter_test/flutter_test.dart';

import '../../../core/exchange/fake_bbx_api.dart';

const _activeElement = {
  'recipientId': 'viban-1',
  'recipientTypeFiat': 'SEPA_EUR_VIRTUAL_ACCOUNT',
  'iban': 'FR7630006000011234567890189',
  'bicCode': 'TESTFRP1',
  'bankAddress': '1 Test Street, Paris',
  'ibanCountry': 'FR',
};

void main() {
  late FakeBbxApi mainnet;
  late FakeBbxApi testnet;
  late BbxApiVirtualIbanRepository repository;

  setUp(() {
    mainnet = FakeBbxApi();
    testnet = FakeBbxApi();
    repository = BbxApiVirtualIbanRepository(
      mainnet: mainnet.datasource(),
      testnet: testnet.datasource(),
    );
  });

  group('find', () {
    Future<Result<VirtualIban?, RecipientsFailure>> find() =>
        repository.find(isTestnet: false);

    test('asks for the owned virtual account and reads it', () async {
      mainnet.answers.add(rpcPage([_activeElement], 1));

      final iban = (await find() as Ok<VirtualIban?, RecipientsFailure>).value;

      expect(
        iban,
        isA<ActiveVirtualIban>().having(
          (i) => i.iban,
          'iban',
          _activeElement['iban'],
        ),
      );
      final params = mainnet.payloads.single['params'] as Map;
      expect(params['filters'], {
        'recipientTypeFiat': ['SEPA_EUR_VIRTUAL_ACCOUNT'],
        'isOwner': true,
      });
      expect(testnet.payloads, isEmpty);
    });

    test('no listed account is no virtual IBAN', () async {
      mainnet.answers.add(rpcPage([], 0));

      expect((await find() as Ok<VirtualIban?, RecipientsFailure>).value, null);
    });

    test('a missing payment option means no virtual IBAN yet', () async {
      mainnet.answers.add(rpcRefusal('ERR_RCP_PO404'));

      expect((await find() as Ok<VirtualIban?, RecipientsFailure>).value, null);
    });

    test('an unreachable API is a network failure', () async {
      mainnet.answers.add(dio.DioExceptionType.connectionTimeout);

      expect(
        (await find() as Err<VirtualIban?, RecipientsFailure>).failure,
        isA<RecipientsNetworkFailure>(),
      );
    });
  });

  group('create', () {
    Future<RecipientsFailure> createFailure() async =>
        (await repository.create(isTestnet: true)
                as Err<VirtualIban, RecipientsFailure>)
            .failure;

    test('creates the virtual account in the selected environment', () async {
      testnet.answers.add(rpcElement(_activeElement));

      final result = await repository.create(isTestnet: true);

      expect(
        (result as Ok<VirtualIban, RecipientsFailure>).value,
        isA<ActiveVirtualIban>(),
      );
      expect(testnet.payloads.single['method'], 'createMyRecipient');
      expect(mainnet.payloads, isEmpty);
    });

    test('an EU residency refusal is its own failure', () async {
      testnet.answers.add(rpcRefusal('ERR_RCP_400_001'));

      expect(
        await createFailure(),
        isA<RecipientsEuResidencyRequiredFailure>(),
      );
    });

    test('a missing payment option is not available', () async {
      testnet.answers.add(rpcRefusal('ERR_RCP_PO404'));

      expect(
        await createFailure(),
        isA<RecipientsVirtualIbanNotAvailableFailure>(),
      );
    });

    test('any other refusal is unexpected', () async {
      testnet.answers.add(rpcRefusal('ERR_RCP_400'));

      expect(await createFailure(), isA<RecipientsUnexpectedFailure>());
    });
  });
}
