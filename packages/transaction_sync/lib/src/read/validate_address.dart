import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';

import '../domain/transaction_sync_failure.dart';

/// Consumer authorization against the captured wallet network, not URI parsing.
/// Testnet and regtest Base58 encodings are ambiguous; regtest accepts only its
/// distinct witness HRP. Historical testnet Base58 behavior is unchanged.
Future<Result<void, TransactionSyncFailure>> validateAddress(
  String address,
  Network network,
) async {
  switch (network) {
    case BitcoinNetwork.signet || LiquidNetwork.regtest:
      // TODO(lwk-dart#96): Liquid regtest needs support in the pinned bull_sdk.
      return const Err(TransactionSyncUnsupportedNetworkFailure());
    case BitcoinNetwork():
      if (network == BitcoinNetwork.regtest &&
          !address.toLowerCase().startsWith('bcrt1')) {
        return const Err(TransactionSyncInvalidAddressFailure());
      }
      final expected = switch (network) {
        BitcoinNetwork.mainnet => bdk.Network.bitcoin,
        BitcoinNetwork.testnet => bdk.Network.testnet,
        BitcoinNetwork.regtest => bdk.Network.regtest,
        BitcoinNetwork.signet => throw StateError('Signet was refused'),
      };
      try {
        final parsed = bdk.Address(address: address, network: expected);
        try {
          return parsed.isValidForNetwork(network: expected)
              ? const Ok(null)
              : const Err(TransactionSyncInvalidAddressFailure());
        } finally {
          parsed.dispose();
        }
      } on Exception {
        return const Err(TransactionSyncInvalidAddressFailure());
      }
    case LiquidNetwork():
      // The legacy SDK enum cannot represent regtest. Refuse its distinct HRPs
      // before entering that adapter, including unconfidential addresses.
      final normalized = address.toLowerCase();
      if (normalized.startsWith('ert1') || normalized.startsWith('el1')) {
        return const Err(TransactionSyncInvalidAddressFailure());
      }
      final expected = switch (network) {
        LiquidNetwork.mainnet => lwk.LiquidNetwork.mainnet,
        LiquidNetwork.testnet => lwk.LiquidNetwork.testnet,
        LiquidNetwork.regtest => throw StateError('Regtest was refused'),
      };
      try {
        return await lwk.Address.validate(addressString: address) == expected
            ? const Ok(null)
            : const Err(TransactionSyncInvalidAddressFailure());
      } on Exception {
        return const Err(TransactionSyncInvalidAddressFailure());
      }
  }
}
