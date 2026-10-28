import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/data/bbx_api_sepa_virtual_payee_repository.dart';
import 'package:bb_mobile/features/recipients/domain/entities/sepa_virtual_payee_status.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter_test/flutter_test.dart';

import '../../../core/exchange/fake_bbx_api.dart';

Map<String, dynamic> _payee(String id, {String? status}) => {
  'recipientId': id,
  'userId': 'user-1',
  'userNbr': 1,
  'isArchived': false,
  'createdAt': '2026-10-01T00:00:00.000Z',
  'updatedAt': '2026-10-01T00:00:00.000Z',
  'recipientTypeFiat': 'SEPA_EUR',
  'isOwner': true,
  'iban': 'FR7630006000011234567890189',
  'isCorporate': false,
  'firstname': 'Test',
  'lastname': 'User',
  'virtualPayeeStatus': ?status,
};

final _refusal = rpcRefusal('ERR_RCP_400');

void main() {
  late FakeBbxApi mainnet;
  late FakeBbxApi testnet;
  late BbxApiSepaVirtualPayeeRepository repository;

  setUp(() {
    mainnet = FakeBbxApi();
    testnet = FakeBbxApi();
    repository = BbxApiSepaVirtualPayeeRepository(
      mainnet: mainnet.datasource(),
      testnet: testnet.datasource(),
    );
  });

  group('activate', () {
    test('asks the selected environment to activate the recipient', () async {
      testnet.answers.add(rpcElement(_payee('r-1', status: 'CREATED')));

      final result = await repository.activate(
        recipientId: 'r-1',
        isTestnet: true,
      );

      expect(
        (result as Ok<SepaVirtualPayeeStatus, RecipientsFailure>).value,
        SepaVirtualPayeeStatus.pending,
      );
      final request = testnet.payloads.single;
      expect(request['method'], 'activateSepaVirtualPayee');
      expect(request['params'], {'recipientId': 'r-1'});
      expect(mainnet.payloads, isEmpty);
    });

    test('a refusal is unexpected', () async {
      mainnet.answers.add(_refusal);

      final result = await repository.activate(
        recipientId: 'r-1',
        isTestnet: false,
      );

      expect(
        (result as Err<SepaVirtualPayeeStatus, RecipientsFailure>).failure,
        isA<RecipientsUnexpectedFailure>(),
      );
    });

    test('an unreachable API is a network failure', () async {
      mainnet.answers.add(dio.DioExceptionType.connectionTimeout);

      final result = await repository.activate(
        recipientId: 'r-1',
        isTestnet: false,
      );

      expect(
        (result as Err<SepaVirtualPayeeStatus, RecipientsFailure>).failure,
        isA<RecipientsNetworkFailure>(),
      );
    });
  });

  group('findStatus', () {
    Future<SepaVirtualPayeeStatus?> statusOf(String recipientId) async {
      final result = await repository.findStatus(
        recipientId: recipientId,
        isTestnet: false,
      );
      return (result as Ok<SepaVirtualPayeeStatus?, RecipientsFailure>).value;
    }

    test('reads the status of the recipient on the first page', () async {
      mainnet.answers.add(
        rpcPage([_payee('r-1'), _payee('r-2', status: 'ACTIVE')], 2),
      );

      expect(await statusOf('r-2'), SepaVirtualPayeeStatus.active);
    });

    test('refreshes a saved pending status from Fiat Republic', () async {
      mainnet.answers.addAll([
        rpcPage([_payee('r-1', status: 'CREATED')], 1),
        rpcElement(_payee('r-1', status: 'ACTIVE')),
      ]);

      expect(await statusOf('r-1'), SepaVirtualPayeeStatus.active);
      expect(mainnet.payloads.map((request) => request['method']), [
        'listRecipientsFiat',
        'activateSepaVirtualPayee',
      ]);
      expect(mainnet.payloads.last['params'], {'recipientId': 'r-1'});
    });

    test('keeps waiting when the refreshed payee is still pending', () async {
      mainnet.answers.addAll([
        rpcPage([_payee('r-1', status: 'CREATED')], 1),
        rpcElement(_payee('r-1', status: 'CREATED')),
      ]);

      expect(await statusOf('r-1'), SepaVirtualPayeeStatus.pending);
    });

    test('a refused pending-status refresh is a load failure', () async {
      mainnet.answers.addAll([
        rpcPage([_payee('r-1', status: 'CREATED')], 1),
        _refusal,
      ]);

      final result = await repository.findStatus(
        recipientId: 'r-1',
        isTestnet: false,
      );

      expect(
        (result as Err<SepaVirtualPayeeStatus?, RecipientsFailure>).failure,
        isA<RecipientsLoadFailure>(),
      );
    });

    test('finds an active recipient beyond the first page', () async {
      mainnet.answers.addAll([
        rpcPage(List.generate(50, (i) => _payee('other-$i')), 51),
        rpcPage([_payee('r-1', status: 'ACTIVE')], 51),
      ]);

      expect(await statusOf('r-1'), SepaVirtualPayeeStatus.active);
      expect(mainnet.payloads.map((r) => (r['params'] as Map)['paginator']), [
        {'page': 1, 'pageSize': 50},
        {'page': 2, 'pageSize': 50},
      ]);
    });

    test('a recipient that is not listed is not found', () async {
      mainnet.answers.add(rpcPage([_payee('other')], 1));

      expect(await statusOf('r-1'), isNull);
      expect(mainnet.payloads, hasLength(1));
    });

    test('stops after the last page it may read', () async {
      mainnet.answers.addAll(
        List.generate(
          21,
          (p) => rpcPage(List.generate(50, (i) => _payee('other-$p-$i')), 5000),
        ),
      );

      expect(await statusOf('r-1'), isNull);
      expect(mainnet.payloads, hasLength(20));
    });

    test('a refusal is a load failure', () async {
      mainnet.answers.add(_refusal);

      final result = await repository.findStatus(
        recipientId: 'r-1',
        isTestnet: false,
      );

      expect(
        (result as Err<SepaVirtualPayeeStatus?, RecipientsFailure>).failure,
        isA<RecipientsLoadFailure>(),
      );
    });
  });
}
