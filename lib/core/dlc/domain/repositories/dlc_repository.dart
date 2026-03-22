import 'package:bb_mobile/core/dlc/domain/entities/dlc_connection_status.dart';
import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:bb_mobile/core/dlc/domain/entities/dlc_instrument.dart';
import 'package:bb_mobile/core/dlc/domain/entities/dlc_order.dart';

/// Abstract repository that the DLC feature depends on.
/// The concrete implementation calls the DLC coordinator API.
abstract class DlcRepository {
  // ─── Connection ─────────────────────────────────────────────────────────────

  /// Check system readiness of the DLC coordinator and return its health status.
  Future<DlcConnectionStatus> checkConnectionStatus();

  // ─── Instruments ─────────────────────────────────────────────────────────────

  /// Fetch all non-expired trading instruments.
  Future<List<DlcInstrument>> getInstruments();

  // ─── Orderbook ──────────────────────────────────────────────────────────────

  /// Fetch the current orderbook for a specific instrument.
  Future<List<DlcOrder>> getOrderbook({required String instrumentId});

  // ─── My Orders ──────────────────────────────────────────────────────────────

  /// Return the authenticated user's orders.
  Future<List<DlcOrder>> getMyOrders();

  /// Place a new order on the DLC coordinator (maker flow).
  Future<Map<String, dynamic>> placeOrder({
    required String instrumentId,
    required DlcOrderSide side,
    required int quantity,
    required int price,
    /// Funding public key hex from the user's wallet
    required String fundingPubkeyHex,
    String? idempotencyKey,
  });

  /// Cancel an open order.
  Future<void> cancelOrder({required String orderId});

  // ─── Taker flow ──────────────────────────────────────────────────────────────

  /// Get signing context for accepting an order as taker.
  Future<Map<String, dynamic>> getAcceptContext({
    required String orderId,
    required String fundingPubkeyHex,
  });

  /// Submit signed CETs to accept a matched order as taker.
  Future<Map<String, dynamic>> submitAcceptMatch({
    required String orderId,
    required String fundingPubkeyHex,
    required String cetAdaptorSignaturesHex,
    required String refundSignatureHex,
  });

  // ─── Maker sign flow ─────────────────────────────────────────────────────────

  /// Get signing context for the maker once an order is matched.
  Future<Map<String, dynamic>> getSignContext({required String dlcId});

  /// Submit maker signatures to finalize the DLC.
  Future<DlcContract> submitSign({
    required String dlcId,
    required String cetAdaptorSignaturesHex,
    required String refundSignatureHex,
    required String fundingSignaturesHex,
  });

  // ─── DLC Contracts ────────────────────────────────────────────────────────────

  /// Fetch all DLC contracts for the authenticated user.
  Future<List<DlcContract>> getMyDlcs();

  /// Fetch a single DLC contract by ID.
  Future<DlcContract> getDlc({required String dlcId});
}
