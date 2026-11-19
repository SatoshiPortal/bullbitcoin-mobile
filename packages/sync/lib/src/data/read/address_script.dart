import 'dart:typed_data';

import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:primitives/primitives.dart';

import '../../domain/sync_failure.dart';

/// The output script a Bitcoin [address] pays to, for an ownership query.
/// Library function: no wallet is opened.
Result<Uint8List, SyncFailure> bitcoinAddressScript(
  String address,
  BitcoinNetwork network,
) {
  final native = switch (network) {
    BitcoinNetwork.mainnet => bdk.Network.bitcoin,
    BitcoinNetwork.testnet => bdk.Network.testnet,
    BitcoinNetwork.regtest => bdk.Network.regtest,
    BitcoinNetwork.signet => null,
  };
  if (native == null) return const Err(SyncUnsupportedNetworkFailure());
  try {
    final parsed = bdk.Address(address: address, network: native);
    try {
      final script = parsed.scriptPubkey();
      try {
        return Ok(script.toBytes());
      } finally {
        script.dispose();
      }
    } finally {
      parsed.dispose();
    }
  } on Exception {
    return const Err(SyncInvalidAddressFailure());
  }
}
