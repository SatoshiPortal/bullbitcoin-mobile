import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:satoshifier/payment_request.dart';
import 'package:bb_mobile/features/wallet/domain/validate_payment_destination_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/payment_destination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'retains complete BIP21 request and amount while exposing address',
    () async {
      const raw =
          'bitcoin:address?amount=0.000025&pj=https%3A%2F%2Fexample.com';
      final usecase = ValidatePaymentDestinationUsecase(
        parse: (_) async => const PaymentRequest.bip21(
          network: BitcoinNetwork.mainnet,
          uri: raw,
          address: 'address',
          amountSat: 2500,
          pj: 'https://example.com',
        ),
      );
      final result = await usecase.execute(
        raw,
        acceptedTypes: {PaymentDestinationType.bitcoin},
      );
      expect(result?.raw, raw);
      expect(result?.address, 'address');
      expect(result?.amountSat, 2500);
    },
  );

  test('Lightning address fields refuse Bitcoin and invoices', () async {
    for (final request in <PaymentRequest>[
      const PaymentRequest.bitcoin(address: 'address', isTestnet: false),
      const PaymentRequest.bolt11(
        invoice: 'invoice',
        amountSat: 2500,
        paymentHash: 'hash',
        expiresAt: 9999999999,
        isTestnet: false,
      ),
    ]) {
      final usecase = ValidatePaymentDestinationUsecase(
        parse: (_) async => request,
      );
      expect(
        await usecase.execute(
          'payload',
          acceptedTypes: {PaymentDestinationType.lightningAddress},
        ),
        isNull,
      );
    }
  });

  test('LNURL is admitted only when the consumer supports it', () async {
    final usecase = ValidatePaymentDestinationUsecase(
      parse: (_) async =>
          const PaymentRequest.lnAddress(address: 'lnurl1payload'),
    );
    expect(
      await usecase.execute(
        'lnurl1payload',
        acceptedTypes: {PaymentDestinationType.lightningAddress},
        allowLnurl: false,
      ),
      isNull,
    );
    expect(
      (await usecase.execute(
        'lnurl1payload',
        acceptedTypes: {PaymentDestinationType.lightningAddress},
      ))?.isLnurl,
      isTrue,
    );
  });

  test('invalid input remains a validation refusal', () async {
    final usecase = ValidatePaymentDestinationUsecase(
      parse: (_) async => throw const FormatException(),
    );
    expect(
      await usecase.execute(
        'invalid',
        acceptedTypes: {PaymentDestinationType.bitcoin},
      ),
      isNull,
    );
  });
}
