import 'package:primitives/primitives.dart' show ScriptType;
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/features/send/domain/fixed_amount_wallet_choice_policy.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = FixedAmountWalletChoicePolicy();
  const request = PaymentRequest.bip21(
    network: Network.bitcoinMainnet,
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
