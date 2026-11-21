import 'package:electrum/electrum.dart';
import 'package:electrum/setup.dart';
import 'package:bb_mobile/features/fees/data/regtest_fees_datasource.dart';
import 'package:bb_mobile/core/fees/data/fees_datasource.dart';
import 'package:bb_mobile/core/fees/data/mappers/mempool_fees_mapper.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:mempool/mempool.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, Err, Ok;
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network, NetworkX;

class FeesRepositoryImpl implements FeesRepository {
  final ElectrumServersPort _electrumServers;
  final RegtestFeesDatasource _regtestFeesDatasource;
  final FeesDatasource _feesDatasource;
  final Mempool _mempool;

  const FeesRepositoryImpl({
    required this._feesDatasource,
    required this._electrumServers,
    this._regtestFeesDatasource = const RegtestFeesDatasource(),
    required this._mempool,
  });

  @override
  Future<FeeOptions> getNetworkFees({required Network network}) async {
    if (network == Network.bitcoinRegtest) {
      try {
        return await _electrumServers.runWithFallback(
          network: ElectrumServerNetwork.bitcoinRegtest,
          operation: _regtestFeesDatasource.fetch,
        );
      } on Exception {
        throw MempoolFeesException('Regtest fee estimates unavailable');
      }
    }
    if (network.isBitcoin) {
      final fees = await _feesDatasource.fetchBitcoinNetworkFees(
        baseUrl: await _resolveBitcoinMempoolUrl(network.bitcoin),
      );
      return MempoolFeesMapper.toFeeOptions(fees);
    }

    // Liquid blocks are typically empty, so the network's minrelayfee
    // (0.1 sat/vByte = 25 sat/kwu) is the only relevant fee tier today.
    // The three presets are kept identical for UI parity with Bitcoin.
    const minRelay = RelativeFee(NetworkFeeRelayPolicy.minRelaySatPerKwu);
    return const FeeOptions(
      fastest: minRelay,
      economic: minRelay,
      slow: minRelay,
      minRelay: minRelay,
    );
  }

  Future<String> _resolveBitcoinMempoolUrl(BitcoinNetwork network) async {
    return switch (await _mempool.servers.activeBase(network: network)) {
      Ok(:final value) => value.toString(),
      Err(failure: MempoolLoadFailure(:final serverKind)) =>
        throw MempoolFeesException(switch (serverKind) {
          MempoolServerKind.custom => 'Failed to fetch custom mempool server',
          MempoolServerKind.defaultServer =>
            'Failed to fetch default mempool server',
        }),
      Err() => throw MempoolFeesException(
        'Failed to resolve active mempool server',
      ),
    };
  }
}
