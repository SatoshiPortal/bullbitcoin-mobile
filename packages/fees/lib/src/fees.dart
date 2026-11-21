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

  Fees._(this._electrum, this._mempool, this._http);

  static Fees open({
    required WalletConnectionPort connections,
    required Mempool mempool,
    Dio Function(String baseUrl)? mempoolHttpClient,
  }) => Fees._(
    ElectrumFeeSource(connections),
    mempool,
    FeesDatasource(dioBuilder: mempoolHttpClient),
  );

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
    final BitcoinNetwork bitcoin => switch (source ?? FeeSource.electrum) {
      FeeSource.electrum => _electrum.estimate(bitcoin),
      FeeSource.mempool => _estimateMempool(bitcoin),
    },
  };

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
