import 'package:boltz_dart/boltz_dart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Swap Fees test', () async {
    try {
      // const amount = 100000;
      // const fees = Fees(boltzUrl: boltzUrl);
      // final submarineFees = await fees.submarine();
      // print('FEES:${submarineFees.lbtcFees}');
      // print('FEES:${fees.lbtcSubmarine.lockupFeesEstimate}');
    } catch (e) {
      print(e);
      if (e is BoltzError) {
        print(e.kind);
        print(e.message);
      }
    }
  });
}
