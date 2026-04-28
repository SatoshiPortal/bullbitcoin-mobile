import 'package:bb_mobile/core/mempool/application/usecases/get_active_mempool_server_usecase.dart';

class MempoolUrlBuilder {
  final GetActiveMempoolServerUsecase _getActiveMempoolServerUsecase;

  const MempoolUrlBuilder({
    required GetActiveMempoolServerUsecase getActiveMempoolServerUsecase,
  }) : _getActiveMempoolServerUsecase = getActiveMempoolServerUsecase;

  Future<String> bitcoinTxid(String txid, {required bool isTestnet}) async {
    final server = await _getActiveMempoolServerUsecase.execute(
      isTestnet: isTestnet,
      isLiquid: false,
    );
    return '${server.fullUrl}/tx/$txid';
  }

  Future<String> liquidTxid(
    String txid, {
    required bool isTestnet,
    String? unblindedUrl,
  }) async {
    final server = await _getActiveMempoolServerUsecase.execute(
      isTestnet: isTestnet,
      isLiquid: true,
    );
    final path = unblindedUrl ?? 'tx/$txid';
    return '${server.fullUrl}/$path';
  }

  Future<String> bitcoinAddress(
    String address, {
    required bool isTestnet,
  }) async {
    final server = await _getActiveMempoolServerUsecase.execute(
      isTestnet: isTestnet,
      isLiquid: false,
    );
    return '${server.fullUrl}/address/$address';
  }

  Future<String> liquidAddress(
    String address, {
    required bool isTestnet,
  }) async {
    final server = await _getActiveMempoolServerUsecase.execute(
      isTestnet: isTestnet,
      isLiquid: true,
    );
    return '${server.fullUrl}/address/$address';
  }
}
