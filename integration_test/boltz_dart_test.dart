import 'package:boltz_dart/boltz_dart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Swap Fees test', () async {
    try {
      const boltzUrl = 'https://api.testnet.boltz.exchange';
      const amount = 100000;
      final fees = await AllFees.fetch(boltzUrl: boltzUrl);
      print('FEES:${fees.lbtcSubmarine.lockupFeesEstimate}');
    } catch (e) {
      print(e);
      if (e is BoltzError) {
        print(e.kind);
        print(e.message);
      }
    }
  });
}
