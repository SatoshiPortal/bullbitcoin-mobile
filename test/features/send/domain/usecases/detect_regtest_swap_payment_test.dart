import 'package:primitives/primitives.dart' show BitcoinNetwork, LiquidNetwork;
import 'package:rust_bindings/boltz.dart' as boltz;
import 'package:satoshifier/payment_request.dart';
import 'package:bb_mobile/features/wallet/public/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust_bindings/rust_bindings.dart';
import 'package:primitives/primitives.dart' show NetworkEnv;

void main() {
  setUpAll(BullSdk.init);
  final detect = DetectBitcoinStringUsecase();
  const invoice =
      'lnbcrt1230n1pjmwkxwpp5etvpredwjpwvsrmrcs3l854tcwyz8tnfm453uyp3kcsrmnmu26xsdqqcqzzsxqyjw5qsp5jmejjyf0v6lyn3c5z6uxdslxtnu6t72perfp8ps6ldyen5as9juq9qyyssqtc8409xlyar4vmn70sszyzeu3k28jzlx0k2cjpg6pvh8mdglkn3ymxslmq8entcz56hwu3hx0d8mzjsvtkc3vu9da6j88exflp8urkqpvcgyxa';

  test('the public invoice fixture passes native regtest decoding', () async {
    final decoded = await boltz.DecodedInvoice.fromString(s: invoice);
    expect(decoded.network, 'regtest');
    expect(decoded.msats, BigInt.from(123000));
  });

  test('regtest Lightning invoice reaches the Boltz payment route', () async {
    final request = await detect.execute(
      data: invoice,
      environment: NetworkEnv.regtest,
    );
    expect(request, isA<Bolt11PaymentRequest>());
  });

  test('bcrt destination retains its concrete regtest chain', () async {
    final request = await detect.execute(
      data: 'bcrt1qzyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3lgth6c',
      environment: NetworkEnv.regtest,
    );
    expect(request, isA<Bip21PaymentRequest>());
    expect((request as Bip21PaymentRequest).network, BitcoinNetwork.regtest);
  });

  test('ert destination retains its concrete regtest chain', () async {
    final request = await detect.execute(
      data: 'ert1qzyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg38u7fyc',
      environment: NetworkEnv.regtest,
    );
    expect(request, isA<Bip21PaymentRequest>());
    expect((request as Bip21PaymentRequest).network, LiquidNetwork.regtest);
  });

  test('confidential Liquid regtest destination reaches the swap route', () async {
    const address =
        'el1qqfumuen7l8wthtz45p3ftn58pvrs9xlumvkuu2xet8egzkcklqtesg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyqsscuw9qrf4q';
    final request = await detect.execute(
      data: address,
      environment: NetworkEnv.regtest,
    );
    expect(request, isA<Bip21PaymentRequest>());
    expect((request as Bip21PaymentRequest).network, LiquidNetwork.regtest);
  });

  test('mainnet Bitcoin destination keeps its historical route', () async {
    final request = await detect.execute(
      data: 'bc1qzyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3h8ffkz',
      environment: NetworkEnv.mainnet,
    );
    expect(request, isA<BitcoinPaymentRequest>());
    expect((request as BitcoinPaymentRequest).isTestnet, false);
  });

  test('testnet Bitcoin destination keeps its historical route', () async {
    final request = await detect.execute(
      data: 'tb1qzyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3apj6d3',
      environment: NetworkEnv.testnet,
    );
    expect(request, isA<BitcoinPaymentRequest>());
    expect((request as BitcoinPaymentRequest).isTestnet, true);
  });
  for (final environment in [NetworkEnv.mainnet, NetworkEnv.testnet]) {
    for (final input in [
      invoice,
      'ert1qzyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg38u7fyc',
      'el1qqfumuen7l8wthtz45p3ftn58pvrs9xlumvkuu2xet8egzkcklqtesg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyqsscuw9qrf4q',
    ]) {
      test(
        '${environment.name} refuses regtest-only input ${input.substring(0, 3)}',
        () async {
          await expectLater(
            detect.execute(data: input, environment: environment),
            throwsA(isA<FormatException>()),
          );
        },
      );
    }
  }

  test('the Lightning scheme preserves the regtest invoice route', () async {
    expect(
      await detect.execute(
        data: 'lightning:$invoice',
        environment: NetworkEnv.regtest,
      ),
      isA<Bolt11PaymentRequest>(),
    );
  });

  for (final input in [
    'ert1invalid',
    'el1invalid',
    'bitcoin:ert1qzyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg38u7fyc?pj=https://example.test',
    'bitcoin:$invoice?pj=https://example.test',
  ]) {
    test(
      'regtest refuses malformed or wrapped raw input ${input.substring(0, 3)}',
      () async {
        await expectLater(
          detect.execute(data: input, environment: NetworkEnv.regtest),
          throwsA(isA<FormatException>()),
        );
      },
    );
  }
  test('regtest-only inputs require a captured regtest environment', () async {
    for (final environment in [null, NetworkEnv.signet]) {
      for (final input in [invoice, 'ert1invalid', 'el1invalid']) {
        await expectLater(
          detect.execute(data: input, environment: environment),
          throwsA(isA<FormatException>()),
        );
      }
    }
  });

  test('regtest still rejects a malformed Lightning invoice', () async {
    await expectLater(
      detect.execute(data: 'lnbcrt1invalid', environment: NetworkEnv.regtest),
      throwsA(
        anyOf(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Invalid regtest destination',
          ),
          equals('Invalid payment request'),
        ),
      ),
    );
  });
}
