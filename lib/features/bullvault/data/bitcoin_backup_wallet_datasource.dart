import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/features/bullvault/data/bitcoin_backup_codec.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_parser.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bitcoin_descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup_key.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';

final class BitcoinBackupWalletModel {
  final String id;
  final String receiveAddress;
  final String changeAddress;
  final int balanceSats;
  final int transactionCount;
  const BitcoinBackupWalletModel(
    this.id,
    this.receiveAddress,
    this.changeAddress,
    this.balanceSats,
    this.transactionCount,
  );
}

/// Dedicated prototype BDK storage. Never opens the production wallet database.
final class BitcoinBackupWalletDatasource {
  final Future<String> Function() _directory;
  const BitcoinBackupWalletDatasource(this._directory);

  Future<BitcoinBackupWalletModel> restore(
    String source,
    BitcoinBackupNetwork network,
    ElectrumConnection connection,
  ) async {
    final directory = await _directory();
    return Isolate.run(() => _restore(directory, source, network, connection));
  }

  static BitcoinBackupWalletModel _restore(
    String directory,
    String source,
    BitcoinBackupNetwork network,
    ElectrumConnection connection,
  ) {
    final parsed = DescriptorBackupParser.parseDescriptor(source);
    for (final key in parsed.keys) {
      BitcoinBackupCodec.checkNetwork(
        DescriptorBackupKey.parse(key.xpub),
        network,
      );
    }
    final id = sha256
        .convert(utf8.encode('${network.name}:${parsed.descriptor}'))
        .toString();
    Directory(directory).createSync(recursive: true);
    final path = '$directory/$id.sqlite';
    final existed = File(path).existsSync();
    final kind = network == BitcoinBackupNetwork.bitcoin
        ? bdk.NetworkKind.main
        : bdk.NetworkKind.test;
    bdk.Descriptor? external;
    bdk.Descriptor? internal;
    bdk.Persister? persister;
    bdk.Wallet? wallet;
    bdk.ElectrumClient? client;
    try {
      external = bdk.Descriptor(
        descriptor: parsed.externalDescriptor,
        networkKind: kind,
      );
      internal = bdk.Descriptor(
        descriptor: parsed.internalDescriptor,
        networkKind: kind,
      );
      persister = bdk.Persister.newSqlite(path: path);
      wallet = existed
          ? bdk.Wallet.load(
              descriptor: external,
              changeDescriptor: internal,
              persister: persister,
              lookahead: 20,
            )
          : bdk.Wallet(
              descriptor: external,
              changeDescriptor: internal,
              network: BitcoinBackupCodec.nativeNetwork(network),
              persister: persister,
              lookahead: 20,
            );
      final proxy = connection.socks5?.trim();
      client = bdk.ElectrumClient(
        url: connection.url,
        socks5: proxy == null || proxy.isEmpty ? null : proxy,
        timeout: connection.effectiveTimeout,
        retry: 0,
        validateDomain: connection.validateDomain,
      );
      // block.header is supported by stock electrs versions which do not expose
      // server.features. Hash the canonical 80-byte genesis header locally.
      final header = client.blockHeader(height: 0);
      final checkpoints = wallet.checkpoints();
      try {
        final bytes = ByteData(80)..setInt32(0, header.version, Endian.little);
        final raw = bytes.buffer.asUint8List();
        raw.setRange(4, 36, header.prevBlockhash.serialize());
        raw.setRange(36, 68, header.merkleRoot.serialize());
        bytes.setUint32(68, header.time, Endian.little);
        bytes.setUint32(72, header.bits, Endian.little);
        bytes.setUint32(76, header.nonce, Endian.little);
        final hash = hex.encode(
          sha256.convert(sha256.convert(raw).bytes).bytes.reversed.toList(),
        );
        if (hash !=
            checkpoints.firstWhere((c) => c.height == 0).hash.toString()) {
          throw const FormatException('Electrum chain mismatch');
        }
      } finally {
        header.prevBlockhash.dispose();
        header.merkleRoot.dispose();
        for (final checkpoint in checkpoints) {
          checkpoint.hash.dispose();
        }
      }
      // Finite prototype scan: a hostile server cannot extend address discovery.
      for (final keychain in bdk.KeychainKind.values) {
        final revealed = wallet.revealAddressesTo(
          keychain: keychain,
          index: 199,
        );
        for (final address in revealed) {
          address.address.dispose();
        }
      }
      final builder = wallet.startSyncWithRevealedSpks();
      try {
        final request = builder.build();
        try {
          final update = client.sync_(
            request: request,
            batchSize: 20,
            fetchPrevTxouts: false,
          );
          try {
            wallet.applyUpdate(update: update);
          } finally {
            update.dispose();
          }
        } finally {
          request.dispose();
        }
      } finally {
        builder.dispose();
      }
      wallet.persist(persister: persister);
      wallet.dispose();
      wallet = null;
      // Successful reopening is part of the restore result, not only a test claim.
      wallet = bdk.Wallet.load(
        descriptor: external,
        changeDescriptor: internal,
        persister: persister,
        lookahead: 20,
      );
      final receive = wallet.peekAddress(
        keychain: bdk.KeychainKind.external_,
        index: 0,
      );
      try {
        final change = wallet.peekAddress(
          keychain: bdk.KeychainKind.internal,
          index: 0,
        );
        try {
          final balance = wallet.balance();
          try {
            final transactions = wallet.transactions();
            try {
              return BitcoinBackupWalletModel(
                id,
                receive.address.toString(),
                change.address.toString(),
                balance.total.toSat(),
                transactions.length,
              );
            } finally {
              for (final tx in transactions) {
                tx.transaction.dispose();
                if (tx.chainPosition case bdk.ConfirmedChainPosition(
                  :final confirmationBlockTime,
                  :final transitively,
                )) {
                  confirmationBlockTime.blockId.hash.dispose();
                  transitively?.dispose();
                }
              }
            }
          } finally {
            for (final amount in [
              balance.immature,
              balance.trustedPending,
              balance.untrustedPending,
              balance.confirmed,
              balance.trustedSpendable,
              balance.total,
            ]) {
              amount.dispose();
            }
          }
        } finally {
          change.address.dispose();
        }
      } finally {
        receive.address.dispose();
      }
    } finally {
      client?.dispose();
      wallet?.dispose();
      persister?.dispose();
      external?.dispose();
      internal?.dispose();
    }
  }
}
