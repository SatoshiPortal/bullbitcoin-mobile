import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/data/bitcoin_backup_codec.dart';
import 'package:bb_mobile/features/bullvault/data/bitcoin_backup_electrum_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/bitcoin_backup_wallet_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_parser.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bitcoin_descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup_key.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bitcoin_descriptor_backup_repository.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

final class BitcoinDescriptorBackupRepositoryImpl
    implements BitcoinDescriptorBackupRepository {
  static const maxHistory = 128;
  final BitcoinBackupElectrumDatasource _electrum;
  final BitcoinBackupWalletDatasource _wallets;
  Future<void> _restoreTail = Future.value();

  BitcoinDescriptorBackupRepositoryImpl(this._electrum, this._wallets);

  @override
  @useResult
  Result<BitcoinBackupPublication, BullVaultFailure> prepare(
    String descriptor,
    BitcoinBackupNetwork network,
  ) {
    try {
      return Ok(BitcoinBackupCodec.prepare(descriptor, network));
    } on Exception {
      return const Err(BullVaultInvalidRecoveryFailure());
    }
  }

  @override
  @useResult
  Future<Result<BitcoinBackupFetch, BullVaultFailure>> fetch(
    String input,
    BitcoinBackupNetwork network,
    ElectrumConnection connection,
    DescriptorBackupSession session,
  ) async {
    final DescriptorBackupKey key;
    final ({String address, Uint8List script}) discovery;
    try {
      key = DescriptorBackupParser.inputKey(input);
      discovery = BitcoinBackupCodec.discovery(key, network);
      BitcoinBackupElectrumDatasource.validate(connection);
    } on Exception {
      return const Err(BullVaultInvalidRecoveryFailure());
    }
    final networkSession = DescriptorBackupSession();
    unawaited(session.cancelled.then((_) => networkSession.cancel()));
    final timer = Timer(const Duration(seconds: 60), networkSession.cancel);
    try {
      final hash = hex.encode(
        sha256.convert(discovery.script).bytes.reversed.toList(),
      );
      final history = await _electrum.request(
        connection,
        'blockchain.scripthash.get_history',
        [hash],
        networkSession,
      );
      if (history is! List) throw const FormatException('Invalid history');
      final candidates = <BitcoinBackupCandidate>[];
      final seen = <String>{};
      var incomplete = history.length > maxHistory;
      var rejected = 0;
      for (final row in history.take(maxHistory)) {
        if (networkSession.isCancelled) {
          incomplete = true;
          break;
        }
        if (row is! Map ||
            row['tx_hash'] is! String ||
            row['height'] is! int ||
            !RegExp(r'^[0-9a-f]{64}$').hasMatch(row['tx_hash'] as String) ||
            (row['height'] as int) < -1) {
          incomplete = true;
          rejected++;
          continue;
        }
        final txid = row['tx_hash'] as String;
        if (seen.contains(txid)) continue;
        final Object? response;
        try {
          response = await _electrum.request(
            connection,
            'blockchain.transaction.get',
            [txid, false],
            networkSession,
          );
        } on Exception {
          incomplete = true;
          rejected++;
          continue;
        }
        try {
          if (response is! String ||
              response.length > 2000000 ||
              response.length.isOdd ||
              !RegExp(r'^[0-9a-fA-F]+$').hasMatch(response)) {
            throw const FormatException('Invalid raw transaction');
          }
          final bytes = Uint8List.fromList(hex.decode(response));
          final height = row['height'] as int;
          final recovered = await _recover(bytes, txid, height, key, network);
          if (networkSession.isCancelled) {
            incomplete = true;
            break;
          }
          seen.add(txid);
          for (final candidate in recovered) {
            if (!candidates.any((c) => c.descriptor == candidate.descriptor)) {
              candidates.add(candidate);
            }
          }
        } on Exception {
          rejected++;
          incomplete = true;
        }
      }
      return Ok(
        BitcoinBackupFetch(
          discovery.address,
          candidates,
          incomplete: incomplete || networkSession.isCancelled,
          rejectedTransactions: rejected,
        ),
      );
    } on Exception {
      return const Err(BullVaultBackupStatusFailure());
    } finally {
      timer.cancel();
      networkSession.cancel();
    }
  }

  // Separate closure scope avoids sending the request's cancellation completer
  // into the crypto isolate along with these immutable values.
  static Future<List<BitcoinBackupCandidate>> _recover(
    Uint8List bytes,
    String txid,
    int height,
    DescriptorBackupKey key,
    BitcoinBackupNetwork network,
  ) => Isolate.run(
    () => BitcoinBackupCodec.recover(bytes, txid, height, key, network),
  );

  @override
  @useResult
  Future<Result<RestoredBackupWallet, BullVaultFailure>> restore(
    String descriptor,
    BitcoinBackupNetwork network,
    ElectrumConnection connection,
    DescriptorBackupSession session,
  ) async {
    // Native sync cannot be interrupted mid-call. Serialize restores even when the
    // UI cancels, so a second request cannot race the first SQLite writer.
    final previous = _restoreTail;
    final finished = Completer<void>();
    _restoreTail = finished.future;
    await previous;
    try {
      if (session.isCancelled) return const Err(BullVaultBackupStatusFailure());
      final uri = BitcoinBackupElectrumDatasource.validate(connection);
      final proxy = connection.socks5?.trim();
      final resolved = ElectrumConnection(
        url: uri.toString(),
        retry: connection.retry,
        timeout: connection.timeout,
        stopGap: connection.stopGap,
        validateDomain: connection.validateDomain,
        isCustom: connection.isCustom,
        socks5: proxy == null || proxy.isEmpty ? null : proxy,
      );
      final value = await _wallets.restore(descriptor, network, resolved);
      if (session.isCancelled) return const Err(BullVaultBackupStatusFailure());
      return Ok(
        RestoredBackupWallet(
          id: value.id,
          receiveAddress: value.receiveAddress,
          changeAddress: value.changeAddress,
          balanceSats: value.balanceSats,
          transactionCount: value.transactionCount,
        ),
      );
    } on Exception {
      return const Err(BullVaultBackupStatusFailure());
    } finally {
      finished.complete();
    }
  }
}
