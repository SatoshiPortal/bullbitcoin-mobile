import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/validate_sweep_payment_request_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

final _wallet = Wallet(
  origin: 'w1',
  network: Network.bitcoinMainnet,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(1000000),
);

void main() {
  final usecase = ValidateSweepPaymentRequestUsecase();

  test('accepts a Bitcoin address on the wallet network', () {
    final result = usecase.execute(
      wallet: _wallet,
      paymentRequest: const PaymentRequest.bitcoin(
        address: 'bc1qrecipient',
        isTestnet: false,
      ),
    );

    expect(result, isA<Ok<void, SendFailure>>());
  });

  test('rejects an amount-bearing BIP21 request', () {
    final result = usecase.execute(
      wallet: _wallet,
      paymentRequest: const PaymentRequest.bip21(
        network: Network.bitcoinMainnet,
        uri: 'bitcoin:bc1qrecipient?amount=0.0005',
        address: 'bc1qrecipient',
        amountSat: 50000,
      ),
    );

    expect(result, isA<Err<void, SendFailure>>());
    expect(
      (result as Err<void, SendFailure>).failure,
      isA<SendInvalidPaymentRequestFailure>(),
    );
  });

  test('rejects a recipient on a different network', () {
    final result = usecase.execute(
      wallet: _wallet,
      paymentRequest: const PaymentRequest.bitcoin(
        address: 'tb1qrecipient',
        isTestnet: true,
      ),
    );

    expect(result, isA<Err<void, SendFailure>>());
  });

  test('rejects a BIP21 request with an explicit zero amount', () {
    final result = usecase.execute(
      wallet: _wallet,
      paymentRequest: const PaymentRequest.bip21(
        network: Network.bitcoinMainnet,
        uri: 'bitcoin:bc1qrecipient?amount=0',
        address: 'bc1qrecipient',
        amountSat: 0,
      ),
    );

    expect(result, isA<Err<void, SendFailure>>());
  });

  test('rejects Lightning, Liquid, and PSBT requests', () {
    final requests = <PaymentRequest>[
      const PaymentRequest.liquid(address: 'lq1recipient', isTestnet: false),
      const PaymentRequest.lnAddress(address: 'name@example.com'),
      const PaymentRequest.psbt(psbt: 'cHNidP8='),
    ];

    for (final request in requests) {
      expect(
        usecase.execute(wallet: _wallet, paymentRequest: request),
        isA<Err<void, SendFailure>>(),
      );
    }
  });
}
