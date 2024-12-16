import 'package:boltz_dart/boltz_dart.dart';
import 'package:flutter/material.dart';
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
      debugPrint(e.toString());
      if (e is BoltzError) {
        debugPrint(e.kind);
        debugPrint(e.message);
      }
    }
  });
}
