import 'package:rust_bindings/boltz.dart' as native;
import 'package:swaps/src/data/models/swap_master_key_model.dart';
import 'package:test/test.dart';

void main() {
  for (final network in native.Network.values) {
    test(
      'native ${network.name} key roundtrip preserves its exact network',
      () {
        final key = native.SwapMasterKey(
          xprv: '',
          xpub: '',
          mnemonic: '',
          fingerprint: '00000001',
          network: network,
        );
        final stored = SwapMasterKeyModel.fromBoltz(key);
        expect(stored.network, network.name);
        expect(
          SwapMasterKeyModel.fromJson(stored.toJson()).toBoltz().network,
          network,
        );
      },
    );
  }

  test('stored regtest key never becomes mainnet', () {
    final stored = SwapMasterKeyModel.fromJson({
      'xprv': '',
      'xpub': '',
      'mnemonic': '',
      'fingerprint': '00000001',
      'network': 'regtest',
    });
    expect(stored.toBoltz().network, native.Network.regtest);
  });

  test('unknown stored key network is refused', () {
    expect(
      () => SwapMasterKeyModel.fromJson({
        'xprv': '',
        'xpub': '',
        'mnemonic': '',
        'fingerprint': '00000001',
        'network': 'unknown',
      }).toBoltz(),
      throwsA(isA<Exception>()),
    );
  });
}
