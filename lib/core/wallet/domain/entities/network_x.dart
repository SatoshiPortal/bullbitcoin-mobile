import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:primitives/primitives.dart' as primitives;

/// Bridges the app's flat [Network] to the chain-typed enums the
/// `secrets` package speaks.
///
/// The app has one enum covering both chains; `primitives` splits them,
/// which is what lets `secrets` refuse a Liquid operation on a Bitcoin
/// network at compile time rather than at runtime. The bridge is where
/// that gap is paid, once.
///
/// `primitives` also carries signet and regtest, which the app's enum
/// does not have yet. Nothing is lost in this direction — the mapping is
/// total — but adding those environments to the app later will not need
/// anything from `secrets`.
extension NetworkX on Network {
  /// The Bitcoin network this value names.
  ///
  /// Throws for a Liquid value: the caller has already branched wrong.
  primitives.BitcoinNetwork get bitcoin => switch (this) {
    Network.bitcoinMainnet => primitives.BitcoinNetwork.mainnet,
    Network.bitcoinTestnet => primitives.BitcoinNetwork.testnet,
    _ => throw ArgumentError.value(this, 'network', 'not a Bitcoin network'),
  };

  /// The Liquid network this value names.
  ///
  /// Throws for a Bitcoin value, for the same reason.
  primitives.LiquidNetwork get liquid => switch (this) {
    Network.liquidMainnet => primitives.LiquidNetwork.mainnet,
    Network.liquidTestnet => primitives.LiquidNetwork.testnet,
    _ => throw ArgumentError.value(this, 'network', 'not a Liquid network'),
  };
}

/// Bridges the app's [ScriptType] to the `primitives` one.
///
/// Same names, same meaning, two declarations — until the app adopts
/// `primitives` directly and this disappears.
extension ScriptTypeBridge on ScriptType {
  primitives.ScriptType get shared => switch (this) {
    ScriptType.bip84 => primitives.ScriptType.bip84,
    ScriptType.bip49 => primitives.ScriptType.bip49,
    ScriptType.bip44 => primitives.ScriptType.bip44,
  };
}
