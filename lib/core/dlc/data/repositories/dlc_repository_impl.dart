import 'package:bb_mobile/core/dlc/data/datasources/dlc_api_datasource.dart';
import 'package:bb_mobile/core/dlc/domain/entities/dlc_connection_status.dart';
import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:bb_mobile/core/dlc/domain/entities/dlc_instrument.dart';
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
      final data = await _datasource.getSystemReadiness();
      stopwatch.stop();
      return data.toDlcConnectionStatus(latencyMs: stopwatch.elapsedMilliseconds);
    } catch (_) {
      return const DlcConnectionStatus(
        apiHealth: DlcApiHealth.unreachable,
        message: 'Could not reach DLC coordinator',
      );
    }
  }

  @override
  Future<List<DlcInstrument>> getInstruments() async {
    final models = await _datasource.getInstruments();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<DlcOrder>> getOrderbook({required String instrumentId}) async {
    final models = await _datasource.getOrderbook(instrumentId: instrumentId);
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<DlcOrder>> getMyOrders() async {
    final models = await _datasource.getMyOrders();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<Map<String, dynamic>> placeOrder({
    required String instrumentId,
    required DlcOrderSide side,
    required int quantity,
    required int price,
    required String fundingPubkeyHex,
    String? idempotencyKey,
  }) async {
    return _datasource.placeOrder(
      instrumentId: instrumentId,
      side: side == DlcOrderSide.buy ? 'buy' : 'sell',
      quantity: quantity,
      price: price,
      fundingPubkeyHex: fundingPubkeyHex,
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<void> cancelOrder({required String orderId}) async {
    await _datasource.cancelOrder(orderId: orderId);
  }

  @override
  Future<Map<String, dynamic>> getAcceptContext({
    required String orderId,
    required String fundingPubkeyHex,
  }) async {
    return _datasource.getAcceptContext(
      orderId: orderId,
      fundingPubkeyHex: fundingPubkeyHex,
    );
  }

  @override
  Future<Map<String, dynamic>> submitAcceptMatch({
    required String orderId,
    required String fundingPubkeyHex,
    required String cetAdaptorSignaturesHex,
    required String refundSignatureHex,
  }) async {
    return _datasource.submitAcceptMatch(
      orderId: orderId,
      fundingPubkeyHex: fundingPubkeyHex,
      cetAdaptorSignaturesHex: cetAdaptorSignaturesHex,
      refundSignatureHex: refundSignatureHex,
    );
  }

  @override
  Future<Map<String, dynamic>> getSignContext({required String dlcId}) async {
    return _datasource.getSignContext(dlcId: dlcId);
  }

  @override
  Future<DlcContract> submitSign({
    required String dlcId,
    required String cetAdaptorSignaturesHex,
    required String refundSignatureHex,
    required String fundingSignaturesHex,
  }) async {
    final model = await _datasource.submitSign(
      dlcId: dlcId,
      cetAdaptorSignaturesHex: cetAdaptorSignaturesHex,
      refundSignatureHex: refundSignatureHex,
      fundingSignaturesHex: fundingSignaturesHex,
    );
    return model.toEntity();
  }

  @override
  Future<List<DlcContract>> getMyDlcs() async {
    final models = await _datasource.getMyDlcs();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<DlcContract> getDlc({required String dlcId}) async {
    final model = await _datasource.getDlc(dlcId: dlcId);
    return model.toEntity();
  }
}
