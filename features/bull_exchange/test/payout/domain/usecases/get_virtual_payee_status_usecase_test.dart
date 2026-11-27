import 'package:bull_exchange/src/payout/domain/usecases/get_virtual_payee_status_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

const _testnet = ExchangeSession(
  environment: ExchangeEnvironment.testnet,
  epoch: 1,
  sessionId: 's',
);

final class _Recipients extends Fake implements RecipientsRepository {
  final Result<SepaVirtualPayeeStatus?, RecipientsFailure> status;
  final asked = <(String, bool)>[];

  _Recipients({this.status = const Ok(SepaVirtualPayeeStatus.pending)});

  @override
  Future<Result<SepaVirtualPayeeStatus?, RecipientsFailure>> findStatus({
    required String recipientId,
    required bool isTestnet,
  }) async {
    asked.add((recipientId, isTestnet));
    return status;
  }
}

void main() {
  test('reads the recipient status on the session network', () async {
    final recipients = _Recipients(
      status: const Ok(SepaVirtualPayeeStatus.active),
    );
    final read = await GetVirtualPayeeStatusUsecase(
      exchangeForTesting(recipients: recipients),
    ).execute(_testnet, 'r-1');
    expect(
      read,
      isA<ReadGot<SepaVirtualPayeeStatus>>().having(
        (r) => r.value,
        'value',
        SepaVirtualPayeeStatus.active,
      ),
    );
    expect(recipients.asked, [('r-1', true)]);
  });

  test('no status for the recipient is missing', () async {
    final read = await GetVirtualPayeeStatusUsecase(
      exchangeForTesting(recipients: _Recipients(status: const Ok(null))),
    ).execute(_testnet, 'r-1');
    expect(read, isA<ReadMissing<SepaVirtualPayeeStatus>>());
  });

  test('a failed read is unreachable', () async {
    final read = await GetVirtualPayeeStatusUsecase(
      exchangeForTesting(
        recipients: _Recipients(status: const Err(RecipientsNetworkFailure())),
      ),
    ).execute(_testnet, 'r-1');
    expect(
      read,
      isA<ReadUnreachable<SepaVirtualPayeeStatus>>().having(
        (r) => r.isNetwork,
        'isNetwork',
        true,
      ),
    );
  });
}
