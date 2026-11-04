import 'package:test/test.dart';
import 'package:wallet/wallet.dart';

Wallet wallet({
  Network network = Network.bitcoinMainnet,
  ScriptType scriptType = ScriptType.bip84,
  String descriptor = "wpkh([d34db33f/84'/0'/7']xpub/0/*)",
  SignerEntity signer = SignerEntity.local,
  SignerDeviceEntity? device,
}) => Wallet(
  origin: 'wallet-id',
  network: network,
  xpubFingerprint: 'xpub-fingerprint',
  scriptType: scriptType,
  xpub: 'public-test-key',
  externalPublicDescriptor: descriptor,
  internalPublicDescriptor: descriptor,
  signer: signer,
  signerDevice: device,
  balanceSat: BigInt.zero,
);

void main() {
  test('the descriptor account takes precedence over the default account', () {
    expect(wallet().derivationPath, "m/84'/0'/7'");
    expect(wallet().id, 'wallet-id');
  });

  test('an absent key origin retains the network and script fallback', () {
    expect(wallet(descriptor: 'wpkh(xpub/0/*)').derivationPath, "m/84'/0'/0'");
    expect(
      wallet(
        descriptor: 'wpkh(xpub/0/*)',
        network: Network.bitcoinTestnet,
        scriptType: ScriptType.bip49,
      ).derivationPath,
      "m/49'/1'/0'",
    );
  });

  test('watch-only and remote signing capabilities remain distinct', () {
    final watchOnly = wallet(signer: SignerEntity.none);
    expect(watchOnly.isWatchOnly, isTrue);
    expect(watchOnly.signsLocally, isFalse);
    expect(watchOnly.signsRemotely, isFalse);
    final hardware = wallet(
      signer: SignerEntity.remote,
      device: SignerDeviceEntity.ledgerNanoX,
    );
    expect(hardware.isWatchSigner, isTrue);
    expect(hardware.isBitcoinHardwareWallet, isTrue);
    expect(hardware.signsLocally, isFalse);
    expect(hardware.signsRemotely, isTrue);
    expect(wallet().signsLocally, isTrue);
  });

  test('Liquid network flags and hardware classification are retained', () {
    final liquid = wallet(
      network: Network.liquidTestnet,
      signer: SignerEntity.remote,
      device: SignerDeviceEntity.jade,
    );
    expect(liquid.isLiquid, isTrue);
    expect(liquid.isBitcoin, isFalse);
    expect(liquid.isTestnet, isTrue);
    expect(liquid.isHardwareWallet, isTrue);
    expect(liquid.isBitcoinHardwareWallet, isFalse);
    expect(liquid.signerDevice?.supportedQrType, QrType.urqr);
  });
}
