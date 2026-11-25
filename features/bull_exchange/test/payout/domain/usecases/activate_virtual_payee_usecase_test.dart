import 'package:bull_exchange/src/payout/domain/usecases/activate_virtual_payee_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

const _mainnet = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 's',
);

final class _Recipients extends Fake implements ExchangeRecipients {
  final Result<SepaVirtualPayeeStatus, RecipientsFailure> activation;
  final asked = <(String, bool)>[];

  _Recipients({this.activation = const Ok(SepaVirtualPayeeStatus.pending)});

  @override
  Future<Result<SepaVirtualPayeeStatus, RecipientsFailure>> activate({
    required String recipientId,
    required bool isTestnet,
  }) async {
    asked.add((recipientId, isTestnet));
    return activation;
  }
}

void main() {
  test('activates the recipient on the session network', () async {
    final recipients = _Recipients();
    final write = await ActivateVirtualPayeeUsecase(
      exchangeForTesting(recipients: recipients),
    ).execute(_mainnet, 'r-1');
    expect(
      write,
      isA<WriteDone<SepaVirtualPayeeStatus>>().having(
        (w) => w.value,
        'value',
        SepaVirtualPayeeStatus.pending,
      ),
    );
    expect(recipients.asked, [('r-1', false)]);
  });

  test('a network failure leaves the activation unknown', () async {
    final write = await ActivateVirtualPayeeUsecase(
      exchangeForTesting(
        recipients: _Recipients(
          activation: const Err(RecipientsNetworkFailure()),
        ),
      ),
    ).execute(_mainnet, 'r-1');
    expect(write, isA<WriteOutcomeUnknown<SepaVirtualPayeeStatus>>());
  });
}
