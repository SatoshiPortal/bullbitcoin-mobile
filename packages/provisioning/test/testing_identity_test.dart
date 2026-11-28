import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:provisioning/testing.dart';

void main() {
  test('testing codec forwards historical production identities', () {
    for (final (network, script, id, code)
        in <(Network, ScriptType, String, String)>[
          (
            BitcoinNetwork.mainnet,
            ScriptType.bip84,
            'wpkh([aabbccdd/84h/0h/0h])',
            'bitcoinMainnet',
          ),
          (
            BitcoinNetwork.testnet,
            ScriptType.bip49,
            'sh(wpkh([aabbccdd/49h/1h/0h]))',
            'bitcoinTestnet',
          ),
          (
            LiquidNetwork.mainnet,
            ScriptType.bip84,
            'elwpkh([aabbccdd/84h/1776h/0h])',
            'liquidMainnet',
          ),
          (
            LiquidNetwork.testnet,
            ScriptType.bip44,
            'elpkh([aabbccdd/44h/1h/0h])',
            'liquidTestnet',
          ),
          (
            BitcoinNetwork.regtest,
            ScriptType.bip84,
            'wpkh([aabbccdd/84h/1h/0h]):regtest',
            'bitcoinRegtest',
          ),
          (
            LiquidNetwork.regtest,
            ScriptType.bip84,
            'elwpkh([aabbccdd/84h/1h/0h]):regtest',
            'liquidRegtest',
          ),
        ]) {
      expect(
        walletIdForTesting(
          fingerprint: 'aabbccdd',
          network: network,
          scriptType: script,
        ),
        id,
      );
      expect(storedWalletNetworkForTesting(network), code);
    }
    expect(
      storedWalletNetworkForTesting(BitcoinNetwork.signet),
      'bitcoinSignet',
    );
  });
}
