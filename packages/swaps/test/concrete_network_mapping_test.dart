import 'package:swaps/src/util.dart' show SwapsException;
import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:swaps/src/data/models/boltz_network.dart';
import 'package:swaps/src/data/models/swap_master_key_model.dart';
import 'package:rust_bindings/boltz.dart' as native;
import 'package:test/test.dart';

void main() {
  test('all six native chain mappings preserve the concrete environment', () {
    expect(
      [
        for (final network in BoltzNetwork.values)
          for (final liquid in [false, true])
            network.nativeChain(isLiquid: liquid),
      ],
      [
        native.Chain.bitcoin,
        native.Chain.liquid,
        native.Chain.bitcoinTestnet,
        native.Chain.liquidTestnet,
        native.Chain.bitcoinRegtest,
        native.Chain.liquidRegtest,
      ],
    );
  });
  test('a stored tag must match the requested environment', () {
    const stored = SwapMasterKeyModel(
      xprv: '',
      xpub: '',
      mnemonic: '',
      fingerprint: '00000001',
      network: 'testnet',
    );
    expect(
      () => stored.requireEnvironment(NetworkEnv.regtest),
      throwsA(isA<SwapsException>()),
    );
    expect(
      () => stored.requireEnvironment(NetworkEnv.mainnet),
      throwsA(isA<SwapsException>()),
    );
    expect(stored.requireEnvironment(NetworkEnv.testnet), same(stored));
  });
}
