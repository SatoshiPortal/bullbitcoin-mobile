import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_birthday_checkpoint_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_birthday_checkpoint_response_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_genesis_block.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_birthday_checkpoint.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_birthday_checkpoint_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_birthday_checkpoint_failure.dart';

/// Resolves a requested birthday to a concrete block, backed by whichever
/// mempool server is currently active for the network (see
/// [WalletBirthdayCheckpointDatasource]).
///
/// Two paths, never both:
/// - [requestedBirthday] is at or before the network's genesis block
///   ([BitcoinGenesisBlock]): resolved locally from that protocol constant,
///   no HTTP round-trip — genesis is not something a mempool server needs
///   to be asked about, and no server has history before its own genesis
///   anyway.
/// - Otherwise: the datasource is asked for the block at or before the
///   lookup instant. A well-behaved mempool server always answers with a
///   block timestamp `<=` the instant it was asked about; if it answers
///   with a *later* block instead (a misbehaving or misconfigured
///   self-hosted instance), that response is rejected and the same
///   question is retried against an earlier instant, up to
///   [_maxLookupAttempts] times total, before giving up.
///
/// Never parses [WalletBirthdayCheckpoint.blockHash] into an SDK-specific
/// hash type (e.g. a BDK `BlockHash`) — that conversion is left to whatever
/// downstream consumer actually needs it (`CbfScanTypeResolver`'s
/// concern), keeping this data-layer class free of BDK/SDK types.
class WalletBirthdayCheckpointRepositoryImpl
    implements WalletBirthdayCheckpointRepository {
  /// How far earlier each retry re-queries the datasource, when it answers
  /// with a block later than the instant just asked about. Deliberately
  /// larger than Bitcoin's ~10 minute target block interval so a single
  /// retry has a real chance of landing before the misbehaving response,
  /// rather than nudging by a few blocks and hitting the same answer again.
  static const _retryStep = Duration(hours: 2);

  /// Total attempts against the datasource before giving up — 1 initial
  /// lookup plus 2 retries. Bounded so a persistently misbehaving server
  /// fails fast with a typed [WalletBirthdayCheckpointLookupFailure]
  /// instead of retrying forever.
  static const _maxLookupAttempts = 3;

  final WalletBirthdayCheckpointDatasource _datasource;

  WalletBirthdayCheckpointRepositoryImpl({required this._datasource});

  @override
  Future<Result<WalletBirthdayCheckpoint, WalletBirthdayCheckpointFailure>>
  resolve({
    required DateTime requestedBirthday,
    required bool isTestnet,
  }) async {
    final requested = requestedBirthday.toUtc();
    final genesis = BitcoinGenesisBlock.forNetwork(isTestnet: isTestnet);

    if (!requested.isAfter(genesis.timestamp)) {
      return Ok(
        WalletBirthdayCheckpoint(
          requestedBirthday: requested,
          blockTimestamp: genesis.timestamp,
          blockHeight: genesis.height,
          blockHash: genesis.hash,
        ),
      );
    }

    var lookupInstant = requested;
    for (var attempt = 1; attempt <= _maxLookupAttempts; attempt++) {
      final WalletBirthdayCheckpointResponseModel response;
      try {
        response = await _datasource.fetchBlockAtOrBeforeTimestamp(
          isTestnet: isTestnet,
          unixSeconds: lookupInstant.millisecondsSinceEpoch ~/ 1000,
        );
      } catch (e, st) {
        log.severe(
          message: 'WalletBirthdayCheckpointRepositoryImpl: lookup failed',
          error: e,
          trace: st,
        );
        return Err(
          WalletBirthdayCheckpointLookupFailure(e.runtimeType.toString()),
        );
      }

      // The one business rule this repository enforces itself (see the
      // domain entity's doc): a checkpoint must never be later than what
      // was actually asked about. A compliant server never triggers this;
      // a misbehaving one gets a bounded number of earlier retries instead
      // of an immediate failure, since one attempt at a slightly earlier
      // instant is often enough to clear a transient/off-by-one answer.
      if (response.timestamp.isAfter(requested)) {
        log.warning(
          'WalletBirthdayCheckpointRepositoryImpl: server returned a block '
          'later than requested (attempt $attempt/$_maxLookupAttempts) — '
          'retrying earlier',
        );
        lookupInstant = lookupInstant.subtract(_retryStep);
        continue;
      }

      try {
        return Ok(
          WalletBirthdayCheckpoint(
            requestedBirthday: requested,
            blockTimestamp: response.timestamp,
            blockHeight: response.height,
            blockHash: response.hash,
          ),
        );
      } on ArgumentError catch (e, st) {
        // Shape validation failed inside the entity (bad hash/height) —
        // not retryable, the server's answer itself is malformed.
        log.severe(
          message:
              'WalletBirthdayCheckpointRepositoryImpl: invalid block '
              'shape in response',
          error: e,
          trace: st,
        );
        return Err(
          WalletBirthdayCheckpointLookupFailure('invalid_block_shape'),
        );
      }
    }

    return const Err(
      WalletBirthdayCheckpointLookupFailure('retries_exhausted'),
    );
  }
}
