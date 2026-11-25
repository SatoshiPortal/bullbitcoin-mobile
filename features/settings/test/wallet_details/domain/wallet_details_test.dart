import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:settings/src/wallet_details/domain/wallet_details.dart';

WalletDetails _details({
  String id = 'wpkh([0a1b2c3d/84h/0h/0h])',
  String externalDescriptor = 'wpkh([0a1b2c3d/84h/0h/0h]xpub-marker/0/*)',
  Network network = BitcoinNetwork.mainnet,
  ScriptType scriptType = ScriptType.bip84,
}) => WalletDetails(
  id: id,
  label: null,
  isDefault: false,
  network: network,
  scriptType: scriptType,
  masterFingerprint: '0a1b2c3d',
  xpub: 'xpub-marker',
  externalDescriptor: externalDescriptor,
  signer: SignerEntity.none,
  signerDevice: null,
);

void main() {
  test('names the address type of every script type', () {
    expect(_details().addressType, 'Native Segwit');
    expect(_details(scriptType: ScriptType.bip49).addressType, 'Nested Segwit');
    expect(_details(scriptType: ScriptType.bip44).addressType, 'Legacy');
  });

  test('a Liquid wallet is always confidential segwit', () {
    final liquid = _details(
      network: LiquidNetwork.mainnet,
      scriptType: ScriptType.bip44,
    );

    expect(liquid.isLiquid, isTrue);
    expect(liquid.addressType, 'Confidential Segwit');
    expect(_details().isLiquid, isFalse);
  });

  test('names every network', () {
    expect(
      _details(network: BitcoinNetwork.mainnet).networkName,
      'Bitcoin Network',
    );
    expect(
      _details(network: BitcoinNetwork.testnet).networkName,
      'Bitcoin Testnet',
    );
    expect(
      _details(network: BitcoinNetwork.signet).networkName,
      'Bitcoin Signet',
    );
    expect(
      _details(network: BitcoinNetwork.regtest).networkName,
      'Bitcoin Regtest',
    );
    expect(
      _details(network: LiquidNetwork.mainnet).networkName,
      'Liquid Network',
    );
    expect(
      _details(network: LiquidNetwork.testnet).networkName,
      'Liquid Testnet',
    );
    expect(
      _details(network: LiquidNetwork.regtest).networkName,
      'Liquid Regtest',
    );
  });

  test('reads the derivation path from the descriptor key origin', () {
    expect(_details().derivationPath, 'm/84h/0h/0h');
    expect(
      _details(externalDescriptor: "wpkh([0a1b2c3d/49h/1h/7h]xpub-marker/0/*)")
          .derivationPath,
      'm/49h/1h/7h',
    );
  });

  test('falls back to the account path when the descriptor has no origin', () {
    expect(
      _details(externalDescriptor: 'wpkh(xpub-marker/0/*)').derivationPath,
      "m/84'/0'/0'",
    );
    expect(
      _details(
        externalDescriptor: 'wpkh(xpub-marker/0/*)',
        scriptType: ScriptType.bip49,
        network: BitcoinNetwork.testnet,
      ).derivationPath,
      "m/49'/1'/0'",
    );
  });

  test('falls back when the origin is malformed', () {
    expect(
      _details(externalDescriptor: 'wpkh(]xpub[0.1)').derivationPath,
      "m/84'/0'/0'",
    );
    expect(
      _details(externalDescriptor: 'wpkh([0a1b2c3d]xpub-marker/0/*)')
          .derivationPath,
      "m/84'/0'/0'",
    );
  });
}
