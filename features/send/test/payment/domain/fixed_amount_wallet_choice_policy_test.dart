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
  group('Lightning invoice', () {
    PaymentRequest invoice({int amountSat = 2500, bool isTestnet = false}) =>
        PaymentRequest.bolt11(
          invoice: 'lninvoice',
          amountSat: amountSat,
          paymentHash: 'hash',
          expiresAt: 0,
          isTestnet: isTestnet,
        );

    test('a Bitcoin and a Liquid wallet that can fund it force a choice', () {
      expect(
        policy.requiresChoice(
          request: invoice(),
          wallets: [
            wallet('a'),
            wallet('b', network: LiquidNetwork.mainnet),
          ],
          hasFixedSource: false,
        ),
        isTrue,
      );
    });

    test('regtest wallets are candidates for a test invoice', () {
      expect(
        policy.requiresChoice(
          request: invoice(isTestnet: true),
          wallets: [
            wallet('a', network: BitcoinNetwork.regtest),
            wallet('b', network: LiquidNetwork.regtest),
          ],
          hasFixedSource: false,
        ),
        isTrue,
      );
    });

    test('remote signers, unfunded wallets and other networks do not', () {
      expect(
        policy.requiresChoice(
          request: invoice(),
          wallets: [
            wallet('a'),
            wallet('b', signer: WalletSigner.remote),
            wallet('c', network: LiquidNetwork.mainnet, balance: 2500),
            wallet('d', network: LiquidNetwork.testnet),
          ],
          hasFixedSource: false,
        ),
        isFalse,
      );
    });

    test('an amountless invoice has no eligible wallets', () {
      expect(
        policy.eligibleWallets(invoice(amountSat: 0), [
          wallet('a'),
          wallet('b', network: LiquidNetwork.mainnet),
        ]),
        isEmpty,
      );
    });
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
