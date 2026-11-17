import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:satoshifier/satoshifier.dart';

enum Network {
  bitcoinMainnet,
  bitcoinTestnet,
  bitcoinSignet,
  bitcoinRegtest,
  liquidMainnet,
  liquidTestnet,
  liquidRegtest;

  bool get isBitcoin =>
      this == bitcoinMainnet ||
      this == bitcoinTestnet ||
      this == bitcoinSignet ||
      this == bitcoinRegtest;
  bool get isLiquid =>
      this == liquidMainnet || this == liquidTestnet || this == liquidRegtest;

  bdk.Network get toBdk {
    switch (this) {
      case Network.bitcoinMainnet:
        return bdk.Network.bitcoin;
      case Network.bitcoinTestnet:
        return bdk.Network.testnet;
      case Network.bitcoinSignet:
        return bdk.Network.signet;
      case Network.bitcoinRegtest:
        return bdk.Network.regtest;
      default:
        throw 'Non bitcoin network: $this';
    }
  }

  static Network fromBdkNetwork(bdk.Network bdkNetwork) {
    switch (bdkNetwork) {
      case bdk.Network.bitcoin:
        return Network.bitcoinMainnet;
      case bdk.Network.testnet:
      case bdk.Network.testnet4:
        return Network.bitcoinTestnet;
      case bdk.Network.signet:
        return Network.bitcoinSignet;
      case bdk.Network.regtest:
        return Network.bitcoinRegtest;
    }
  }

  static Network fromLwkNetwork(lwk.LiquidNetwork lwkNetwork) {
    switch (lwkNetwork) {
      case lwk.LiquidNetwork.mainnet:
        return Network.liquidMainnet;
      case lwk.LiquidNetwork.testnet:
        return Network.liquidTestnet;
      case lwk.LiquidNetwork.regtest:
        return Network.liquidRegtest;
    }
  }

  /// Classifies a Bitcoin address from its own encoding, or null if no known
  /// prefix matches. Performs no checksum or length validation — that stays
  /// with bdk.
  ///
  /// Reading the encoding replaces picking the first `bdk.Network` whose
  /// constructor did not throw, which made the answer depend on the order of
  /// `bdk.Network.values`: upstream reordering that enum silently changed how
  /// addresses were classified here.
  ///
  /// One ambiguity is irreducible and this method cannot resolve it. In
  /// rust-bitcoin, testnet3, testnet4 and signet all use the `tb` bech32 HRP,
  /// and every test-kind base58 address shares one version byte across those
  /// three plus regtest. A `tb1…`, `m…`, `n…` or `2…` address therefore does
  /// not identify one chain, and is reported as [bitcoinTestnet] as the
  /// representative test network. Callers needing the exact chain must supply
  /// it from context; [isTestnet] is reliable for all of them, only the
  /// specific network is not.
  static Network? fromBitcoinAddress(String address) {
    // bech32 is case-insensitive; base58 is not, so the legacy checks below
    // must see the original string.
    final lower = address.toLowerCase();
    if (lower.startsWith('bcrt1')) return Network.bitcoinRegtest;
    if (lower.startsWith('bc1')) return Network.bitcoinMainnet;
    if (lower.startsWith('tb1')) return Network.bitcoinTestnet;
    if (_legacyMainnet.hasMatch(address)) return Network.bitcoinMainnet;
    if (_legacyTest.hasMatch(address)) return Network.bitcoinTestnet;
    return null;
  }

  /// Base58 P2PKH and P2SH, anchored on the version character. The charset
  /// excludes 0, O, I and l. Matching the whole string keeps a leading 'm' or
  /// 'n' in arbitrary text from being read as a test-network address.
  static final RegExp _legacyMainnet = RegExp(
    r'^[13][1-9A-HJ-NP-Za-km-z]{25,34}$',
  );
  static final RegExp _legacyTest = RegExp(
    r'^[mn2][1-9A-HJ-NP-Za-km-z]{25,34}$',
  );

  static Network fromXpubType(XpubType xpubType) {
    if (xpubType == XpubType.xpub ||
        xpubType == XpubType.ypub ||
        xpubType == XpubType.zpub) {
      return Network.bitcoinMainnet;
    }
    if (xpubType == XpubType.tpub ||
        xpubType == XpubType.upub ||
        xpubType == XpubType.vpub) {
      return Network.bitcoinTestnet;
    }

    throw 'Invalid xpub type: $xpubType';
  }

  /// Whether this network carries real value.
  ///
  /// The switch is exhaustive on purpose: adding a network forces a decision
  /// here rather than letting it inherit a default.
  bool get isMainnet {
    switch (this) {
      case Network.bitcoinMainnet:
      case Network.liquidMainnet:
        return true;
      case Network.bitcoinTestnet:
      case Network.bitcoinSignet:
      case Network.bitcoinRegtest:
      case Network.liquidTestnet:
      case Network.liquidRegtest:
        return false;
    }
  }

  /// Whether this network is a test network, so worthless by definition.
  ///
  /// Previously false for [bitcoinSignet] and [bitcoinRegtest], which reported
  /// those chains as production. This is the getter a wallet gates on to warn
  /// the user, pick a backend, or apply production safeguards, so a signet or
  /// regtest payment was handled as if it moved real funds. Defined as the
  /// complement of [isMainnet] so the two can never disagree — the same
  /// "anything but mainnet" rule Bolt11Parser already applies to invoices.
  bool get isTestnet => !isMainnet;
}
