import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/derivers/liquid_deriver.dart'
    show lwkLiquidNetwork;

/// Liquid descriptors and signatures reach lwk on the network the caller named, one to one.
///
/// lwk-dart expresses Liquid regtest since SatoshiPortal/lwk-dart#99: regtest goes to lwk's regtest, never refused and never folded into testnet, whose addresses belong to another chain. What lwk derives there needs the FFI: see integration_test/secrets_derivation_vectors_test.dart.
void main() {
  test('every Liquid network maps to its own lwk network', () {
    expect(lwkLiquidNetwork(LiquidNetwork.mainnet), lwk.LiquidNetwork.mainnet);
    expect(lwkLiquidNetwork(LiquidNetwork.testnet), lwk.LiquidNetwork.testnet);
    expect(lwkLiquidNetwork(LiquidNetwork.regtest), lwk.LiquidNetwork.regtest);
  });

  test('no two networks share an lwk network', () {
    final mapped = LiquidNetwork.values.map(lwkLiquidNetwork).toSet();
    expect(mapped, hasLength(LiquidNetwork.values.length));
  });
}
