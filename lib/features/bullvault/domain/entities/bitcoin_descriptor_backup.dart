import 'dart:typed_data';

/// Account xpub prefixes distinguish mainnet from test chains, not individual
/// test chains. The recovery transport therefore always takes an explicit chain.
enum BitcoinBackupNetwork { bitcoin, testnet, testnet4, signet, regtest }

final class BitcoinBackupPublication {
  final String descriptor;
  final Uint8List payload;
  final List<String> addresses;

  BitcoinBackupPublication(
    this.descriptor,
    Uint8List payload,
    List<String> addresses,
  ) : payload = Uint8List.fromList(payload).asUnmodifiableView(),
      addresses = List.unmodifiable(addresses) {
    if (descriptor.trim().isEmpty ||
        payload.isEmpty ||
        addresses.any((a) => a.trim().isEmpty) ||
        addresses.length != 3 ||
        addresses.toSet().length != 3) {
      throw ArgumentError('A backup requires three distinct discovery outputs');
    }
  }
}

final class BitcoinBackupCandidate {
  final String descriptor;
  final String txid;
  final int outputIndex;
  final int reportedHeight;

  BitcoinBackupCandidate({
    required this.descriptor,
    required this.txid,
    required this.outputIndex,
    required this.reportedHeight,
  }) {
    if (descriptor.isEmpty ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(txid) ||
        outputIndex < 0 ||
        reportedHeight < -1) {
      throw ArgumentError('Invalid backup candidate');
    }
  }
}

final class BitcoinBackupFetch {
  final String discoveryAddress;
  final List<BitcoinBackupCandidate> candidates;
  final bool incomplete;
  final int rejectedTransactions;

  BitcoinBackupFetch(
    this.discoveryAddress,
    List<BitcoinBackupCandidate> candidates, {
    required this.incomplete,
    required this.rejectedTransactions,
  }) : candidates = List.unmodifiable(candidates) {
    if (discoveryAddress.trim().isEmpty || rejectedTransactions < 0) {
      throw ArgumentError('Invalid backup search result');
    }
  }
}

/// A synchronized, persisted and reopened prototype watch-only wallet.
final class RestoredBackupWallet {
  final String id;
  final String receiveAddress;
  final String changeAddress;
  final int balanceSats;
  final int transactionCount;

  RestoredBackupWallet({
    required this.id,
    required this.receiveAddress,
    required this.changeAddress,
    required this.balanceSats,
    required this.transactionCount,
  }) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(id) ||
        receiveAddress.trim().isEmpty ||
        changeAddress.trim().isEmpty ||
        balanceSats < 0 ||
        transactionCount < 0) {
      throw ArgumentError('Invalid restored wallet');
    }
  }
}
