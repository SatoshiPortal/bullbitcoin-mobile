import 'package:bb_mobile/core/dlc/domain/entities/dlc_connection_status.dart';
import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:bb_mobile/core/dlc/domain/entities/dlc_order.dart';

/// Abstract repository that the DLC feature depends on.
/// The concrete implementation calls the external DLC engine API.
abstract class DlcRepository {
  // ─── Connection ─────────────────────────────────────────────────────────────

  /// Ping the DLC engine and return its health status.
  Future<DlcConnectionStatus> checkConnectionStatus();

  // ─── Orderbook ──────────────────────────────────────────────────────────────

  /// Fetch the current public orderbook (calls vs puts, open orders).
  Future<List<DlcOrder>> getOrderbook({
    DlcOptionType? filterType,
  });

  // ─── My Orders ──────────────────────────────────────────────────────────────

  /// Return orders placed by the local user (identified by their pubkey).
  Future<List<DlcOrder>> getMyOrders({required String pubkey});

  /// Place a new limit order on the DLC engine.
  Future<DlcOrder> placeOrder({
    required DlcOptionType optionType,
    required DlcOrderSide side,
    required int strikePriceSat,
    required int premiumSat,
    required int quantity,
    required int expiryTimestamp,
    required String makerPubkey,
    /// Signed offer message (produced by the local signing logic)
    required String signedOfferHex,
  });

  /// Cancel an open order.
  Future<void> cancelOrder({
    required String orderId,
    required String makerPubkey,
    /// Cancellation must be authenticated via signature
    required String signatureHex,
  });

  // ─── Contracts ──────────────────────────────────────────────────────────────

  /// Fetch all DLC contracts for the local wallet (by pubkey).
  Future<List<DlcContract>> getContracts({required String pubkey});

  /// Accept a DLC offer from a counterparty.
  Future<DlcContract> acceptOffer({
    required String offerId,
    required String acceptHex,
  });

  /// Submit signed CETs (Contract Execution Transactions) to the engine.
  Future<DlcContract> submitSignedCets({
    required String contractId,
    required String cetSignatureHex,
  });

  /// Fetch a single contract by ID.
  Future<DlcContract> getContract({required String contractId});
}
