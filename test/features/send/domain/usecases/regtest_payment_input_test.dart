import 'dart:typed_data';

import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart' as app;
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  late String address;
  setUpAll(() {
    final script = bdk.Script(
      rawOutputScript: Uint8List.fromList([0, 20, ...List.filled(20, 1)]),
    );
    final native = bdk.Address.fromScript(
      script: script,
      network: bdk.Network.regtest,
    );
    try {
      address = native.toString();
    } finally {
      native.dispose();
      script.dispose();
    }
  });
  final detect = DetectBitcoinStringUsecase();
  test(
    'regtest plain and BIP21 carry a concrete network without binary alias',
    () async {
      for (final input in [
        address,
        'bitcoin:$address?amount=0.00000001&label=regtest',
      ]) {
        final result = await detect.execute(
          data: input,
          environment: NetworkEnv.regtest,
        );
        expect(result, isA<Bip21PaymentRequest>());
        final request = result as Bip21PaymentRequest;
        expect(request.network, app.Network.bitcoinRegtest);
        expect(request.address, address);
        if (input.startsWith('bitcoin:')) expect(request.amountSat, 1);
      }
    },
  );
  test('regtest input cannot enter either historical network', () async {
    for (final environment in [NetworkEnv.mainnet, NetworkEnv.testnet]) {
      for (final input in [address, 'bitcoin:$address?amount=1']) {
        await expectLater(
          detect.execute(data: input, environment: environment),
          throwsFormatException,
        );
      }
    }
  });
  test(
    'unsupported services, required fields and malformed amounts refuse',
    () async {
      for (final query in [
        'pj=https://example.invalid',
        'lightning=lntb',
        'pjos=0',
        'req-unknown=1',
        'amount=1&amount=2',
        'amount=-1',
        'amount=1e-8',
        'amount=0.000000001',
        'amount=21000001',
      ]) {
        await expectLater(
          detect.execute(
            data: 'bitcoin:$address?$query',
            environment: NetworkEnv.regtest,
          ),
          throwsFormatException,
        );
      }
    },
  );
}
