import 'package:dio/dio.dart';
import 'package:mempool/mempool.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show WalletConnectionPort;

import 'data/electrum_fee_source.dart';
import 'data/mempool_fees_datasource.dart';
import 'data/mempool_fees_mapper.dart';
import 'domain/fees_entity.dart';
import 'domain/fees_failure.dart';

enum FeeSource { electrum, mempool }

/// Provides fee estimates for the requested network.
class Fees {
  final ElectrumFeeSource _electrum;
  final Mempool _mempool;
  final FeesDatasource _http;
  final Future<String?> Function(String key) _readPreference;
  final Future<void> Function(String key, String value) _writePreference;

  static const _sourceKey = 'bitcoinFeeSource';

  Fees._(
    this._electrum,
    this._mempool,
    this._http,
    this._readPreference,
    this._writePreference,
  );

  static Fees open({
    required WalletConnectionPort connections,
    required Mempool mempool,
    required Future<String?> Function(String key) readPreference,
    required Future<void> Function(String key, String value) writePreference,
    Dio Function(String baseUrl)? mempoolHttpClient,
  }) => Fees._(
    ElectrumFeeSource(connections),
    mempool,
    FeesDatasource(dioBuilder: mempoolHttpClient),
    readPreference,
    writePreference,
  );

  @useResult
  Future<Result<FeeSource, FeesFailure>> readSource() async {
    try {
      final saved = await _readPreference(_sourceKey);
      return Ok(
        saved == FeeSource.mempool.name
            ? FeeSource.mempool
            : FeeSource.electrum,
      );
    } on Exception {
      return const Err(FeeSourceReadFailure());
    }
  }

  @useResult
  Future<Result<void, FeesFailure>> saveSource(FeeSource source) async {
    try {
      await _writePreference(_sourceKey, source.name);
      return const Ok(null);
    } on Exception {
      return const Err(FeeSourceWriteFailure());
    }
  }

  /// Liquid uses its relay floor and regtest always uses local Electrum.
  @useResult
  Future<Result<FeeOptions, FeesFailure>> estimate(
    Network network, {
    FeeSource? source,
  }) => switch (network) {
    LiquidNetwork() => Future.value(const Ok(_liquidFees)),
    BitcoinNetwork.regtest => _electrum.estimate(BitcoinNetwork.regtest),
    BitcoinNetwork.signet => Future.value(
      const Err(FeeEstimateUnavailableFailure()),
    ),
    final BitcoinNetwork bitcoin => _estimateBitcoin(bitcoin, source),
  };

  Future<Result<FeeOptions, FeesFailure>> _estimateBitcoin(
    BitcoinNetwork network,
    FeeSource? override,
  ) async {
    final Result<FeeSource, FeesFailure> source = override == null
        ? await readSource()
        : Ok(override);
    return switch (source) {
      Err(:final failure) => Err(failure),
      Ok(value: FeeSource.electrum) => _electrum.estimate(network),
      Ok(value: FeeSource.mempool) => _estimateMempool(network),
    };
  }

  Future<Result<FeeOptions, FeesFailure>> _estimateMempool(
    BitcoinNetwork network,
  ) async {
    try {
      switch (await _mempool.servers.activeBase(network: network)) {
        case Err():
          return const Err(FeeEstimateUnavailableFailure());
        case Ok(:final value):
          final fees = await _http.fetchBitcoinNetworkFees(
            baseUrl: value.toString(),
          );
          return Ok(MempoolFeesMapper.toFeeOptions(fees));
      }
    } on Exception {
      return const Err(FeeEstimateUnavailableFailure());
    }
  }

  static const _liquidFees = FeeOptions(
    fastest: NetworkFeeRelayPolicy.minRelay,
    economic: NetworkFeeRelayPolicy.minRelay,
    slow: NetworkFeeRelayPolicy.minRelay,
    minRelay: NetworkFeeRelayPolicy.minRelay,
  );
}
