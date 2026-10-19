import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/domain/bitcoin_recipient_list_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = BitcoinRecipientListPolicy();

  test('supports only amountless Bitcoin requests', () {
    expect(
      policy.supports(
        const PaymentRequest.bitcoin(
          address: 'bc1qrecipient',
          isTestnet: false,
        ),
      ),
      isTrue,
    );
    expect(
      policy.supports(
        const PaymentRequest.bip21(
          network: Network.bitcoinMainnet,
          uri: 'bitcoin:bc1qrecipient?amount=0.0005',
          address: 'bc1qrecipient',
          amountSat: 50000,
        ),
      ),
      isFalse,
    );
    expect(
      policy.supports(
        const PaymentRequest.liquid(address: 'lq1recipient', isTestnet: false),
      ),
      isFalse,
    );
  });

  test(
    'retains additional recipients for incomplete or same-network input',
    () {
      expect(
        policy.shouldRetainAdditionalRecipients(
          recipientCount: 2,
          nextRequest: null,
          currentNetworkIsTestnet: false,
        ),
        isTrue,
      );
      expect(
        policy.shouldRetainAdditionalRecipients(
          recipientCount: 2,
          nextRequest: const PaymentRequest.bitcoin(
            address: 'bc1qrecipient',
            isTestnet: false,
          ),
          currentNetworkIsTestnet: false,
        ),
        isTrue,
      );
      expect(
        policy.shouldRetainAdditionalRecipients(
          recipientCount: 2,
          nextRequest: const PaymentRequest.bitcoin(
            address: 'tb1qrecipient',
            isTestnet: true,
          ),
          currentNetworkIsTestnet: false,
        ),
        isFalse,
      );
    },
  );

  test('accepts additional addresses only on the primary network', () {
    expect(
      policy.compatibleAdditionalAddress(
        request: const PaymentRequest.bitcoin(
          address: 'bc1qrecipient',
          isTestnet: false,
        ),
        primaryNetworkIsTestnet: false,
        isSweep: false,
      ),
      'bc1qrecipient',
    );
    expect(
      policy.compatibleAdditionalAddress(
        request: const PaymentRequest.bitcoin(
          address: 'tb1qrecipient',
          isTestnet: true,
        ),
        primaryNetworkIsTestnet: false,
        isSweep: false,
      ),
      isNull,
    );
  });

  test('accepts embedded amounts outside sweeps only', () {
    const request = PaymentRequest.bip21(
      network: Network.bitcoinMainnet,
      uri: 'bitcoin:bc1qrecipient?amount=0.0005',
      address: 'bc1qrecipient',
      amountSat: 50000,
    );

    expect(
      policy.compatibleAdditionalAddress(
        request: request,
        primaryNetworkIsTestnet: false,
        isSweep: false,
      ),
      'bc1qrecipient',
    );
    expect(
      policy.compatibleAdditionalAddress(
        request: request,
        primaryNetworkIsTestnet: false,
        isSweep: true,
      ),
      isNull,
    );
  });

  test('accepts valid fixed and remainder recipients', () {
    expect(
      policy.hasValidRecipients(
        recipients: const [
          (isValid: true, receivesRemainder: false, amountSat: 10000),
          (isValid: true, receivesRemainder: true, amountSat: 0),
        ],
        isSweep: false,
      ),
      isTrue,
    );
  });

  test('rejects invalid amounts and invalid remainder configurations', () {
    expect(
      policy.hasValidRecipients(
        recipients: const [
          (isValid: true, receivesRemainder: false, amountSat: 0),
        ],
        isSweep: false,
      ),
      isFalse,
    );
    expect(
      policy.hasValidRecipients(
        recipients: const [
          (isValid: true, receivesRemainder: true, amountSat: 0),
          (isValid: true, receivesRemainder: true, amountSat: 0),
        ],
        isSweep: false,
      ),
      isFalse,
    );
    expect(
      policy.hasValidRecipients(
        recipients: const [
          (isValid: true, receivesRemainder: false, amountSat: 10000),
        ],
        isSweep: true,
      ),
      isFalse,
    );
  });
}
