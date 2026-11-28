import 'package:primitives/primitives.dart'
    show BitcoinNetwork, Network, SignerEntity;

enum WalletCardSubtitle {
  externalSigner,
  watchOnly,
  bitcoin,
  liquidAndLightning;

  static WalletCardSubtitle of(Network network, SignerEntity signer) =>
      switch (signer) {
        SignerEntity.remote => externalSigner,
        SignerEntity.none => watchOnly,
        SignerEntity.local =>
          network is BitcoinNetwork ? bitcoin : liquidAndLightning,
      };
}
