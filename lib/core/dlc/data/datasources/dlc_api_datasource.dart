import 'package:bb_mobile/core/dlc/data/models/dlc_contract_model.dart';
import 'package:bb_mobile/core/dlc/data/models/dlc_order_model.dart';
import 'package:bb_mobile/core/dlc/domain/entities/dlc_connection_status.dart';
import 'package:bb_mobile/core/dlc/domain/entities/dlc_order.dart';
import 'package:dio/dio.dart';

/// Raw HTTP calls to the external DLC engine REST API.
/// All methods throw [DioException] on network/HTTP errors.
class DlcApiDatasource {
  DlcApiDatasource({required Dio dio, required String baseUrl})
      : _dio = dio,
        _baseUrl = baseUrl;

  final Dio _dio;
  final String _baseUrl;

  // ─── Connection ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getHealth() async {
    final response = await _dio.get<Map<String, dynamic>>('$_baseUrl/health');
    return response.data!;
  }

  // ─── Orderbook ──────────────────────────────────────────────────────────────

  Future<List<DlcOrderModel>> getOrderbook({String? filterType}) async {
    final response = await _dio.get<List<dynamic>>(
      '$_baseUrl/orderbook',
      queryParameters: {
        if (filterType != null) 'type': filterType,
      },
    );
    return response.data!
        .cast<Map<String, dynamic>>()
        .map(DlcOrderModel.fromJson)
        .toList();
  }

  // ─── My Orders ──────────────────────────────────────────────────────────────

  Future<List<DlcOrderModel>> getMyOrders({required String pubkey}) async {
    final response = await _dio.get<List<dynamic>>(
      '$_baseUrl/orders/mine',
      queryParameters: {'pubkey': pubkey},
    );
    return response.data!
        .cast<Map<String, dynamic>>()
        .map(DlcOrderModel.fromJson)
        .toList();
  }

  Future<DlcOrderModel> placeOrder({
    required String optionType,
    required String side,
    required int strikePriceSat,
    required int premiumSat,
    required int quantity,
    required int expiryTimestamp,
    required String makerPubkey,
    required String signedOfferHex,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl/orders',
      data: {
        'option_type': optionType,
        'side': side,
        'strike_price_sat': strikePriceSat,
        'premium_sat': premiumSat,
        'quantity': quantity,
        'expiry_timestamp': expiryTimestamp,
        'maker_pubkey': makerPubkey,
        'signed_offer_hex': signedOfferHex,
      },
    );
    return DlcOrderModel.fromJson(response.data!);
  }

  Future<void> cancelOrder({
    required String orderId,
    required String makerPubkey,
    required String signatureHex,
  }) async {
    await _dio.delete<void>(
      '$_baseUrl/orders/$orderId',
      data: {'maker_pubkey': makerPubkey, 'signature_hex': signatureHex},
    );
  }

  // ─── Contracts ──────────────────────────────────────────────────────────────

  Future<List<DlcContractModel>> getContracts({required String pubkey}) async {
    final response = await _dio.get<List<dynamic>>(
      '$_baseUrl/contracts',
      queryParameters: {'pubkey': pubkey},
    );
    return response.data!
        .cast<Map<String, dynamic>>()
        .map(DlcContractModel.fromJson)
        .toList();
  }

  Future<DlcContractModel> acceptOffer({
    required String offerId,
    required String acceptHex,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl/contracts/$offerId/accept',
      data: {'accept_hex': acceptHex},
    );
    return DlcContractModel.fromJson(response.data!);
  }

  Future<DlcContractModel> submitSignedCets({
    required String contractId,
    required String cetSignatureHex,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl/contracts/$contractId/sign',
      data: {'cet_signature_hex': cetSignatureHex},
    );
    return DlcContractModel.fromJson(response.data!);
  }

  Future<DlcContractModel> getContract({required String contractId}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_baseUrl/contracts/$contractId',
    );
    return DlcContractModel.fromJson(response.data!);
  }
}

extension DlcConnectionStatusX on Map<String, dynamic> {
  DlcConnectionStatus toDlcConnectionStatus({required int latencyMs}) {
    final status = this['status'] as String? ?? 'unknown';
    return DlcConnectionStatus(
      apiHealth: switch (status) {
        'ok' => DlcApiHealth.healthy,
        'degraded' => DlcApiHealth.degraded,
        _ => DlcApiHealth.unreachable,
      },
      latencyMs: latencyMs,
      engineVersion: this['version'] as String?,
      message: this['message'] as String?,
      lastCheckedAt: DateTime.now().toIso8601String(),
    );
  }
}
