import 'package:mempool/src/domain/entities/mempool_server.dart';
import 'package:mempool/src/domain/mempool_failure.dart';
import 'package:primitives/primitives.dart';

class MempoolUrlBuilder {
  final Future<Result<MempoolServer, MempoolFailure>> Function({
    required bool isTestnet,
    required bool isLiquid,
  })
  _getActiveServer;

  const MempoolUrlBuilder({required this._getActiveServer});

  Future<String> bitcoinTxid(
    String txid, {
    required bool isTestnet,
    String? fragment,
  }) async {
    final server = await _activeServer(isTestnet: isTestnet, isLiquid: false);
    return '${server.fullUrl}/tx/$txid${fragment == null ? '' : '?showDetails=true#$fragment'}';
  }

  Future<String> liquidTxid(
    String txid, {
    required bool isTestnet,
    String? unblindedUrl,
  }) async {
    final server = await _activeServer(isTestnet: isTestnet, isLiquid: true);
    final path = unblindedUrl ?? 'tx/$txid';
    return '${server.fullUrl}/$path';
  }

  Future<String> bitcoinAddress(
    String address, {
    required bool isTestnet,
  }) async {
    final server = await _activeServer(isTestnet: isTestnet, isLiquid: false);
    return '${server.fullUrl}/address/$address';
  }

  Future<String> liquidAddress(
    String address, {
    required bool isTestnet,
  }) async {
    final server = await _activeServer(isTestnet: isTestnet, isLiquid: true);
    return '${server.fullUrl}/address/$address';
  }

  Future<MempoolServer> _activeServer({
    required bool isTestnet,
    required bool isLiquid,
  }) async {
    final result = await _getActiveServer(
      isTestnet: isTestnet,
      isLiquid: isLiquid,
    );
    return switch (result) {
      Ok(:final value) => value,
      Err() => throw Exception('Failed to fetch active mempool server'),
    };
  }
}
