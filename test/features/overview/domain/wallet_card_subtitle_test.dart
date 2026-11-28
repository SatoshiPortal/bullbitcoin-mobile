import 'package:flutter_test/flutter_test.dart';
import 'package:overview/overview.dart';
import 'package:primitives/primitives.dart';

void main() {
  test('signer type takes precedence over chain in card subtitles', () {
    expect(
      WalletCardSubtitle.of(BitcoinNetwork.mainnet, SignerEntity.local),
      WalletCardSubtitle.bitcoin,
    );
    expect(
      WalletCardSubtitle.of(LiquidNetwork.testnet, SignerEntity.local),
      WalletCardSubtitle.liquidAndLightning,
    );
    expect(
      WalletCardSubtitle.of(LiquidNetwork.regtest, SignerEntity.none),
      WalletCardSubtitle.watchOnly,
    );
    expect(
      WalletCardSubtitle.of(BitcoinNetwork.regtest, SignerEntity.remote),
      WalletCardSubtitle.externalSigner,
    );
  });
}
