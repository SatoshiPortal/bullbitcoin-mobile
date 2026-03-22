import 'package:bb_mobile/core/dlc/data/models/dlc_contract_model.dart';
import 'package:bb_mobile/core/dlc/data/models/dlc_instrument_model.dart';
import 'package:bb_mobile/core/dlc/data/models/dlc_order_model.dart';
import 'package:bb_mobile/core/dlc/domain/entities/dlc_connection_status.dart';
import 'package:dio/dio.dart';

/// Raw HTTP calls to the DLC coordinator REST API.
/// All authenticated endpoints use Bearer token auth.
class DlcApiDatasource {
  DlcApiDatasource({
    required Dio dio,
    required String baseUrl,
    // TODO: wire to actual wallet auth token once wallet integration is done
    String? bearerToken,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _bearerToken = bearerToken;

  final Dio _dio;
  final String _baseUrl;
  final String? _bearerToken;

  Options get _authOptions => Options(
        headers: {
          if (_bearerToken != null)
            'Authorization': 'Bearer $_bearerToken',
        },
      );

  // ─── System Health ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getSystemReadiness() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_baseUrl/auth/system-readiness',
    );
    return response.data!;
  }

  // ─── Instruments ─────────────────────────────────────────────────────────────

  Future<List<DlcInstrumentModel>> getInstruments() async {
    final response = await _dio.get<List<dynamic>>(
      '$_baseUrl/instruments/non-expired',
    );
    return response.data!
        .cast<Map<String, dynamic>>()
        .map(DlcInstrumentModel.fromJson)
        .toList();
  }

  // ─── Orderbook ──────────────────────────────────────────────────────────────

  Future<List<DlcOrderModel>> getOrderbook({required String instrumentId}) async {
    final response = await _dio.get<List<dynamic>>(
      '$_baseUrl/orderbook/$instrumentId',
    );
    return response.data!
        .cast<Map<String, dynamic>>()
        .map(DlcOrderModel.fromJson)
        .toList();
  }

  // ─── My Orders ──────────────────────────────────────────────────────────────

  Future<List<DlcOrderModel>> getMyOrders() async {
    final response = await _dio.get<List<dynamic>>(
      '$_baseUrl/orders',
      options: _authOptions,
    );
    return response.data!
        .cast<Map<String, dynamic>>()
        .map(DlcOrderModel.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> placeOrder({
    required String instrumentId,
    required String side,
    required int quantity,
    required int price,
    required String fundingPubkeyHex,
    String? idempotencyKey,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl/orders',
      data: {
        'instrument_id': instrumentId,
        'side': side,
        'quantity': quantity,
        'price': price,
        'funding_pubkey_hex': fundingPubkeyHex,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      },
      options: _authOptions,
    );
    return response.data!;
  }

  Future<void> cancelOrder({required String orderId}) async {
    await _dio.post<void>(
      '$_baseUrl/orders/$orderId/cancel',
      options: _authOptions,
    );
  }

  // ─── Taker (accept order) flow ───────────────────────────────────────────────

  Future<Map<String, dynamic>> getAcceptContext({
    required String orderId,
    required String fundingPubkeyHex,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl/orders/$orderId/accept-context',
      data: {'funding_pubkey_hex': fundingPubkeyHex},
      options: _authOptions,
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> submitAcceptMatch({
    required String orderId,
    required String fundingPubkeyHex,
    required String cetAdaptorSignaturesHex,
    required String refundSignatureHex,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl/orders/$orderId/accept-match',
      data: {
        'funding_pubkey_hex': fundingPubkeyHex,
        'cet_adaptor_signatures_hex': cetAdaptorSignaturesHex,
        'refund_signature_hex': refundSignatureHex,
      },
      options: _authOptions,
    );
    return response.data!;
  }

  // ─── Maker (sign DLC) flow ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getSignContext({required String dlcId}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_baseUrl/dlcs/$dlcId/sign-context',
      options: _authOptions,
    );
    return response.data!;
  }

  Future<DlcContractModel> submitSign({
    required String dlcId,
    required String cetAdaptorSignaturesHex,
    required String refundSignatureHex,
    required String fundingSignaturesHex,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl/dlcs/$dlcId/sign',
      data: {
        'cet_adaptor_signatures_hex': cetAdaptorSignaturesHex,
        'refund_signature_hex': refundSignatureHex,
        'funding_signatures_hex': fundingSignaturesHex,
      },
      options: _authOptions,
    );
    return DlcContractModel.fromJson(response.data!);
  }

  // ─── DLC Contracts ────────────────────────────────────────────────────────────

  Future<List<DlcContractModel>> getMyDlcs() async {
    final response = await _dio.get<List<dynamic>>(
      '$_baseUrl/dlcs',
      options: _authOptions,
    );
    return response.data!
        .cast<Map<String, dynamic>>()
        .map(DlcContractModel.fromJson)
        .toList();
  }

  Future<DlcContractModel> getDlc({required String dlcId}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_baseUrl/dlcs/$dlcId',
      options: _authOptions,
    );
    return DlcContractModel.fromJson(response.data!);
  }
}

extension DlcConnectionStatusX on Map<String, dynamic> {
  DlcConnectionStatus toDlcConnectionStatus({required int latencyMs}) {
    final status = this['status'] as String? ?? 'unknown';
    return DlcConnectionStatus(
      apiHealth: switch (status) {
        'ok' || 'ready' => DlcApiHealth.healthy,
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
