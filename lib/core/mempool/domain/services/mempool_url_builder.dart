import 'package:bb_mobile/core/mempool/application/usecases/get_active_mempool_server_usecase.dart';
import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/utils/result.dart';

class MempoolUrlBuilder {
  final GetActiveMempoolServerUsecase _getActiveMempoolServerUsecase;

  const MempoolUrlBuilder({
    required this._getActiveMempoolServerUsecase,
  });

  Future<String> bitcoinTxid(String txid, {required bool isTestnet}) async {
    final server = await _activeServer(isTestnet: isTestnet, isLiquid: false);
    return '${server.fullUrl}/tx/$txid';
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
    final result = await _getActiveMempoolServerUsecase.execute(
      isTestnet: isTestnet,
      isLiquid: isLiquid,
    );
    return switch (result) {
      Ok(:final value) => value,
      Err() => throw Exception('Failed to fetch active mempool server'),
    };
  }
}
