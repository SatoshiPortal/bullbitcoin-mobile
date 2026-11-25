import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:primitives/primitives.dart' show ScriptType;
import 'package:primitives/primitives.dart' show SignerEntity;
import 'package:satoshifier/payment_request.dart';
import 'package:bb_mobile/features/send/domain/fixed_amount_wallet_choice_policy.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = FixedAmountWalletChoicePolicy();
  const request = PaymentRequest.bip21(
    network: BitcoinNetwork.mainnet,
    uri: 'bitcoin:recipient?amount=0.000025',
    address: 'recipient',
    amountSat: 2500,
  );
  Wallet wallet(
    String id, {
    Network network = Network.bitcoinMainnet,
    int balance = 10000,
    SignerEntity signer = SignerEntity.local,
  }) => Wallet(
    origin: id,
    network: network,
    xpubFingerprint: id,
    scriptType: ScriptType.bip84,
    xpub: '',
    externalPublicDescriptor: '',
    internalPublicDescriptor: '',
    signer: signer,
    signerDevice: null,
    balanceSat: BigInt.from(balance),
  );

  test('two direct wallets include a hardware signer', () {
    expect(
      policy.requiresChoice(
        request: request,
        wallets: [
          wallet('a'),
          wallet('b', signer: SignerEntity.remote),
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
          wallet('b', network: Network.liquidMainnet),
          wallet('c', balance: 2500),
          wallet('d', signer: SignerEntity.none),
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
            wallet('b', network: Network.liquidMainnet),
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
            wallet('a', network: Network.bitcoinRegtest),
            wallet('b', network: Network.liquidRegtest),
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
            wallet('b', signer: SignerEntity.remote),
            wallet('c', network: Network.liquidMainnet, balance: 2500),
            wallet('d', network: Network.liquidTestnet),
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
          wallet('b', network: Network.liquidMainnet),
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
