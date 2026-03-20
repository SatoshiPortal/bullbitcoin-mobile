import 'package:bb_mobile/core/dlc/data/datasources/dlc_api_datasource.dart';
import 'package:bb_mobile/core/dlc/domain/entities/dlc_connection_status.dart';
import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:bb_mobile/core/dlc/domain/entities/dlc_order.dart';
import 'package:bb_mobile/core/dlc/domain/repositories/dlc_repository.dart';

class DlcRepositoryImpl implements DlcRepository {
  DlcRepositoryImpl({required DlcApiDatasource datasource})
      : _datasource = datasource;

  final DlcApiDatasource _datasource;

  @override
  Future<DlcConnectionStatus> checkConnectionStatus() async {
    final stopwatch = Stopwatch()..start();
    try {
      final data = await _datasource.getHealth();
      stopwatch.stop();
      return data.toDlcConnectionStatus(latencyMs: stopwatch.elapsedMilliseconds);
    } catch (_) {
      return const DlcConnectionStatus(
        apiHealth: DlcApiHealth.unreachable,
        message: 'Could not reach DLC engine',
      );
    }
  }

  @override
  Future<List<DlcOrder>> getOrderbook({DlcOptionType? filterType}) async {
    final models = await _datasource.getOrderbook(
      filterType: filterType != null
          ? (filterType == DlcOptionType.call ? 'call' : 'put')
          : null,
    );
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<DlcOrder>> getMyOrders({required String pubkey}) async {
    final models = await _datasource.getMyOrders(pubkey: pubkey);
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<DlcOrder> placeOrder({
    required DlcOptionType optionType,
    required DlcOrderSide side,
    required int strikePriceSat,
    required int premiumSat,
    required int quantity,
    required int expiryTimestamp,
    required String makerPubkey,
    required String signedOfferHex,
  }) async {
    final model = await _datasource.placeOrder(
      optionType: optionType == DlcOptionType.call ? 'call' : 'put',
      side: side == DlcOrderSide.buy ? 'buy' : 'sell',
      strikePriceSat: strikePriceSat,
      premiumSat: premiumSat,
      quantity: quantity,
      expiryTimestamp: expiryTimestamp,
      makerPubkey: makerPubkey,
      signedOfferHex: signedOfferHex,
    );
    return model.toEntity();
  }

  @override
  Future<void> cancelOrder({
    required String orderId,
    required String makerPubkey,
    required String signatureHex,
  }) async {
    await _datasource.cancelOrder(
      orderId: orderId,
      makerPubkey: makerPubkey,
      signatureHex: signatureHex,
    );
  }

  @override
  Future<List<DlcContract>> getContracts({required String pubkey}) async {
    final models = await _datasource.getContracts(pubkey: pubkey);
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<DlcContract> acceptOffer({
    required String offerId,
    required String acceptHex,
  }) async {
    final model =
        await _datasource.acceptOffer(offerId: offerId, acceptHex: acceptHex);
    return model.toEntity();
  }

  @override
  Future<DlcContract> submitSignedCets({
    required String contractId,
    required String cetSignatureHex,
  }) async {
    final model = await _datasource.submitSignedCets(
      contractId: contractId,
      cetSignatureHex: cetSignatureHex,
    );
    return model.toEntity();
  }

  @override
  Future<DlcContract> getContract({required String contractId}) async {
    final model = await _datasource.getContract(contractId: contractId);
    return model.toEntity();
  }
}
