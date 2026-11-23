import 'package:primitives/primitives.dart'
    show BitcoinNetwork, LiquidNetwork, Network;
import 'package:satoshifier/payment_request.dart';
import 'package:send/src/payment/domain/fixed_amount_wallet_choice_policy.dart';
import 'package:send/src/payment/domain/send_source.dart';
import 'package:secrets/testing.dart' show walletRegistrationForTesting;
import 'package:secrets/secrets.dart' show WalletSigner;
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = FixedAmountWalletChoicePolicy();
  const request = PaymentRequest.bip21(
    network: BitcoinNetwork.mainnet,
    uri: 'bitcoin:recipient?amount=0.000025',
    address: 'recipient',
    amountSat: 2500,
  );
  SendSource wallet(
    String id, {
    Network network = BitcoinNetwork.mainnet,
    int balance = 10000,
    WalletSigner signer = WalletSigner.local,
  }) => SendSource(
    walletRegistrationForTesting(id: id, network: network, signer: signer),
    BigInt.from(balance),
    null,
  );

  test('two direct wallets include a hardware signer', () {
    expect(
      policy.requiresChoice(
        request: request,
        wallets: [
          wallet('a'),
          wallet('b', signer: WalletSigner.remote),
        ],
        hasFixedSource: false,
      ),
      isTrue,
    );
  });
  test('swap, unfunded and watch-only alternatives do not force a choice', () {
    expect(
      policy.requiresChoice(
        request: request,
        wallets: [
          wallet('a'),
          wallet('b', network: LiquidNetwork.mainnet),
          wallet('c', balance: 2500),
          wallet('d', signer: WalletSigner.none),
        ],
        hasFixedSource: false,
      ),
      isFalse,
    );
  });
  test('fixed source and duplicate catalog entries do not force a choice', () {
    final first = wallet('a');
    expect(
      policy.requiresChoice(
        request: request,
        wallets: [first, wallet('b')],
        hasFixedSource: true,
      ),
      isFalse,
    );
    expect(
      policy.requiresChoice(
        request: request,
        wallets: [first, first],
        hasFixedSource: false,
      ),
      isFalse,
    );
  });
}
