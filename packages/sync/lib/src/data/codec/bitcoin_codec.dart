import 'dart:typed_data';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:primitives/primitives.dart';

import '../bitcoin_transaction_decoder.dart';
import '../../domain/sync_failure.dart';
import '../../domain/wallet_values.dart' show Keychain;
import 'native_bitcoin_transaction.dart';

/// The PSBT re-serialized by the parser: a check that [psbtBase64] is a PSBT.
Result<String, SyncFailure> canonicalBitcoinPsbt(String psbtBase64) =>
    _withPsbt(psbtBase64, (psbt) => Ok(psbt.serialize()));

/// Combines a signer's [signedBase64] with the [unsignedBase64] it was given
/// (a signer may drop the input data) and finalizes the result.
Result<DecodedBitcoinTransaction, SyncFailure> finalizeBitcoinPsbts({
  required String unsignedBase64,
  required String signedBase64,
}) => _withPsbt(
  unsignedBase64,
  (unsigned) => _withPsbt(signedBase64, (signed) {
    final bdk.Psbt combined;
    try {
      combined = unsigned.combine(other: signed);
    } on Exception {
      return const Err(SyncNotFinalizableFailure());
    }
    try {
      final finalized = combined.finalize();
      try {
        if (!finalized.couldFinalize) {
          return const Err(SyncNotFinalizableFailure());
        }
        return Ok(decodeNativePsbt(finalized.psbt));
      } finally {
        finalized.psbt.dispose();
      }
    } finally {
      combined.dispose();
    }
  }),
);

/// The fee a PSBT pays: its inputs' amounts less its outputs'. Refused when
/// an input amount is missing.
Result<int, SyncFailure> bitcoinPsbtFee(String psbtBase64) =>
    _withPsbt(psbtBase64, (psbt) => Ok(psbt.fee()));

/// The public output descriptor of [keychain] for the account key [xpub],
/// with its key origin: BIP84, BIP49 or BIP44 by [scriptType]. Library
/// function: no wallet is opened.
Result<String, SyncFailure> bitcoinPublicDescriptor({
  required String xpub,
  required String fingerprint,
  required ScriptType scriptType,
  required Keychain keychain,
  required BitcoinNetwork network,
}) {
  final kind = network == BitcoinNetwork.mainnet
      ? bdk.NetworkKind.main
      : bdk.NetworkKind.test;
  final nativeKeychain = keychain == Keychain.internal
      ? bdk.KeychainKind.internal
      : bdk.KeychainKind.external_;
  final bdk.DescriptorPublicKey key;
  try {
    key = bdk.DescriptorPublicKey.fromString(publicKey: xpub);
  } on Exception {
    return const Err(SyncInvalidCatalogFailure());
  }
  try {
    final descriptor = switch (scriptType) {
      ScriptType.bip84 => bdk.Descriptor.newBip84Public(
        publicKey: key,
        fingerprint: fingerprint,
        keychainKind: nativeKeychain,
        networkKind: kind,
      ),
      ScriptType.bip49 => bdk.Descriptor.newBip49Public(
        publicKey: key,
        fingerprint: fingerprint,
        keychainKind: nativeKeychain,
        networkKind: kind,
      ),
      ScriptType.bip44 => bdk.Descriptor.newBip44Public(
        publicKey: key,
        fingerprint: fingerprint,
        keychainKind: nativeKeychain,
        networkKind: kind,
      ),
    };
    try {
      return Ok(descriptor.toString());
    } finally {
      descriptor.dispose();
    }
  } on Exception {
    return const Err(SyncInvalidCatalogFailure());
  } finally {
    key.dispose();
  }
}

/// The address an output [script] pays to on [network], for display. A
/// non-standard script has none.
Result<String, SyncFailure> bitcoinScriptAddress(
  List<int> script,
  BitcoinNetwork network,
) {
  final native = _nativeNetwork(network);
  if (native == null) return const Err(SyncUnsupportedNetworkFailure());
  try {
    final nativeScript = bdk.Script(
      rawOutputScript: Uint8List.fromList(script),
    );
    try {
      final address = bdk.Address.fromScript(
        script: nativeScript,
        network: native,
      );
      try {
        return Ok(address.toString());
      } finally {
        address.dispose();
      }
    } finally {
      nativeScript.dispose();
    }
  } on Exception {
    return const Err(SyncInvalidAddressFailure());
  }
}

/// [address] in its canonical form when it is valid on [network]. Testnet
/// also accepts the historical Base58 encodings it shares with regtest.
Result<String, SyncFailure> parseBitcoinAddress(
  String address,
  BitcoinNetwork network,
) {
  final native = _nativeNetwork(network);
  if (native == null) return const Err(SyncUnsupportedNetworkFailure());
  try {
    final parsed = bdk.Address(address: address, network: native);
    try {
      return Ok(parsed.toString());
    } finally {
      parsed.dispose();
    }
  } on Exception {
    return const Err(SyncInvalidAddressFailure());
  }
}

bdk.Network? _nativeNetwork(BitcoinNetwork network) => switch (network) {
  BitcoinNetwork.mainnet => bdk.Network.bitcoin,
  BitcoinNetwork.testnet => bdk.Network.testnet,
  BitcoinNetwork.regtest => bdk.Network.regtest,
  BitcoinNetwork.signet => null,
};

Result<T, SyncFailure> _withPsbt<T>(
  String psbtBase64,
  Result<T, SyncFailure> Function(bdk.Psbt) read,
) {
  if (psbtBase64.isEmpty || psbtBase64.length > maxEncodedBitcoinPsbtLength) {
    return const Err(SyncInvalidTransactionFailure());
  }
  final bdk.Psbt psbt;
  try {
    psbt = bdk.Psbt(psbtBase64: psbtBase64);
  } on Exception {
    return const Err(SyncInvalidTransactionFailure());
  }
  try {
    return read(psbt);
  } on Exception {
    return const Err(SyncInvalidTransactionFailure());
  } finally {
    psbt.dispose();
  }
}
