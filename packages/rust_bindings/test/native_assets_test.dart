import 'dart:isolate';

import 'package:bull_sdk/bull_sdk.dart';
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:bull_sdk/onion.dart' show OnionCore;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads the hook-built SDK without a library path override', () async {
    await BullSdk.init();
    await OnionCore.init();
    final descriptor = await lwk.Descriptor.newConfidentialFromSeed(
      network: lwk.LiquidNetwork.mainnet,
      seed: List<int>.filled(64, 0),
    );
    expect(descriptor.ctDescriptor.isNotEmpty, isTrue);
    OnionCore.dispose();
    BullSdk.dispose();
  });

  test('initializes the native SDK in a background isolate', () async {
    final ready = await Isolate.run(() async {
      await BullSdk.init();
      final descriptor = await lwk.Descriptor.newConfidentialFromSeed(
        network: lwk.LiquidNetwork.mainnet,
        seed: List<int>.filled(64, 0),
      );
      final ready = descriptor.ctDescriptor.isNotEmpty;
      BullSdk.dispose();
      return ready;
    });
    expect(ready, isTrue);
  });
}
