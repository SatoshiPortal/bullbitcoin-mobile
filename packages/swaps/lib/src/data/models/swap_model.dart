import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:swaps/src/domain/entities/swap.dart';

part 'swap_model.freezed.dart';
part 'swap_model.g.dart';

@freezed
sealed class SwapModel with _$SwapModel {
  // Lightning Receive Swap (reverse swap)
  const factory SwapModel.lnReceive({
    required String id,
    required String type,
    required String status,
    @Default(false) bool isTestnet,
    required int keyIndex,
    required int creationTime,
    required String receiveWalletId,
    required String invoice,
    String? receiveAddress,
    String? receiveTxid,
    @Default(false) bool wasDirectPayment,
    int? completionTime,
    int? boltzFees,
    int? lockupFees,
    int? claimFees,
    @Default(false) bool recovered,
  }) = LnReceiveSwapModel;

  // Lightning Send Swap (submarine swap)
  const factory SwapModel.lnSend({
    required String id,
    required String type,
    required String status,
    @Default(false) bool isTestnet,
    required int keyIndex,
    required int creationTime,
    required String sendWalletId,
    required String invoice,
    required String paymentAddress,
    required int paymentAmount,
    String? sendTxid,
    String? preimage,
    String? refundAddress,
    String? refundTxid,
    int? completionTime,
    int? boltzFees,
    int? lockupFees,
    int? claimFees,
    int? refundFees,
    @Default(false) bool recovered,
  }) = LnSendSwapModel;

  // Chain Swap (between BTC and L-BTC)
  const factory SwapModel.chain({
    required String id,
    required String type,
    required String status,
    @Default(false) bool isTestnet,
    required int keyIndex,
    required int creationTime,
    required String sendWalletId,
    required String paymentAddress,
    required int paymentAmount,
    String? sendTxid,
    String? receiveWalletId,
    String? receiveAddress,
    String? receiveTxid,
    String? refundAddress,
    String? refundTxid,
    int? completionTime,
    int? boltzFees,
    int? lockupFees,
    int? claimFees,
    int? refundFees,
    int? serverNetworkFees,
    @Default(false) bool recovered,
  }) = ChainSwapModel;

  const SwapModel._();

  factory SwapModel.fromEntity(Swap swap) {
    return switch (swap) {
      LnReceiveSwap(
        id: final id,
        keyIndex: final keyIndex,
        type: final type,
        status: final status,
        environment: final environment,
        creationTime: final creationTime,
        receiveWalletId: final receiveWalletId,
        invoice: final invoice,
        receiveAddress: final receiveAddress,
        receiveTxid: final receiveTxid,
        wasDirectPayment: final wasDirectPayment,
        fees: final fees,
        completionTime: final completionTime,
        recovered: final recovered,
      ) =>
        SwapModel.lnReceive(
          id: id,
          type: type.name,
          status: status.name,
          isTestnet: environment == Environment.testnet,
          keyIndex: keyIndex,
          creationTime: creationTime.millisecondsSinceEpoch,
          receiveWalletId: receiveWalletId,
          invoice: invoice,
          receiveAddress: receiveAddress,
          receiveTxid: receiveTxid,
          wasDirectPayment: wasDirectPayment,
          completionTime: completionTime?.millisecondsSinceEpoch,
          boltzFees: fees?.boltzFee,
          lockupFees: fees?.lockupFee,
          claimFees: fees?.claimFee,
          recovered: recovered,
        ),
      LnSendSwap(
        id: final id,
        keyIndex: final keyIndex,
        type: final type,
        status: final status,
        environment: final environment,
        creationTime: final creationTime,
        sendWalletId: final sendWalletId,
        invoice: final invoice,
        paymentAddress: final paymentAddress,
        paymentAmount: final paymentAmount,
        sendTxid: final sendTxid,
        preimage: final preimage,
        refundAddress: final refundAddress,
        refundTxid: final refundTxid,
        fees: final fees,
        completionTime: final completionTime,
        recovered: final recovered,
      ) =>
        SwapModel.lnSend(
          id: id,
          type: type.name,
          status: status.name,
          isTestnet: environment == Environment.testnet,
          keyIndex: keyIndex,
          creationTime: creationTime.millisecondsSinceEpoch,
          sendWalletId: sendWalletId,
          invoice: invoice,
          paymentAddress: paymentAddress,
          paymentAmount: paymentAmount,
          sendTxid: sendTxid,
          preimage: preimage,
          refundAddress: refundAddress,
          refundTxid: refundTxid,
          completionTime: completionTime?.millisecondsSinceEpoch,
          boltzFees: fees?.boltzFee,
          lockupFees: fees?.lockupFee,
          claimFees: fees?.claimFee,
          refundFees: fees?.refundFee,
          recovered: recovered,
        ),
      ChainSwap(
        id: final id,
        keyIndex: final keyIndex,
        type: final type,
        status: final status,
        environment: final environment,
        creationTime: final creationTime,
        sendWalletId: final sendWalletId,
        sendTxid: final sendTxid,
        paymentAddress: final paymentAddress,
        paymentAmount: final paymentAmount,
        receiveWalletId: final receiveWalletId,
        receiveAddress: final receiveAddress,
        receiveTxid: final receiveTxid,
        refundAddress: final refundAddress,
        refundTxid: final refundTxid,
        fees: final fees,
        completionTime: final completionTime,
        recovered: final recovered,
      ) =>
        SwapModel.chain(
          id: id,
          type: type.name,
          status: status.name,
          isTestnet: environment == Environment.testnet,
          keyIndex: keyIndex,
          creationTime: creationTime.millisecondsSinceEpoch,
          sendWalletId: sendWalletId,
          sendTxid: sendTxid,
          paymentAddress: paymentAddress,
          paymentAmount: paymentAmount,
          receiveWalletId: receiveWalletId,
          receiveAddress: receiveAddress,
          receiveTxid: receiveTxid,
          refundAddress: refundAddress,
          refundTxid: refundTxid,
          completionTime: completionTime?.millisecondsSinceEpoch,
          boltzFees: fees?.boltzFee,
          lockupFees: fees?.lockupFee,
          claimFees: fees?.claimFee,
          refundFees: fees?.refundFee,
          serverNetworkFees: fees?.serverNetworkFees,
          recovered: recovered,
        ),
    };
  }

  Swap toEntity() {
    final swapType = SwapType.values.byName(type);
    final swapStatus = SwapStatus.values.byName(status);
    final environment = isTestnet ? Environment.testnet : Environment.mainnet;
    final creationDateTime = DateTime.fromMillisecondsSinceEpoch(creationTime);

    return switch (this) {
      LnReceiveSwapModel(
        :final id,
        :final keyIndex,
        :final receiveWalletId,
        :final invoice,
        :final receiveAddress,
        :final receiveTxid,
        :final wasDirectPayment,
        :final boltzFees,
        :final lockupFees,
        :final claimFees,
        :final completionTime,
        :final recovered,
      ) =>
        Swap.lnReceive(
          id: id,
          keyIndex: keyIndex,
          type: swapType,
          status: swapStatus,
          environment: environment,
          creationTime: creationDateTime,
          receiveWalletId: receiveWalletId,
          invoice: invoice,
          receiveAddress: receiveAddress,
          receiveTxid: receiveTxid,
          wasDirectPayment: wasDirectPayment,
          fees: SwapFees(
            boltzFee: boltzFees,
            lockupFee: lockupFees,
            claimFee: claimFees,
          ),
          completionTime: completionTime != null
              ? DateTime.fromMillisecondsSinceEpoch(completionTime)
              : null,
          recovered: recovered,
        ),
      LnSendSwapModel(
        :final id,
        :final keyIndex,
        :final sendWalletId,
        :final invoice,
        :final paymentAddress,
        :final paymentAmount,
        :final sendTxid,
        :final preimage,
        :final refundAddress,
        :final refundTxid,
        :final boltzFees,
        :final lockupFees,
        :final claimFees,
        :final refundFees,
        :final completionTime,
        :final recovered,
      ) =>
        Swap.lnSend(
          id: id,
          keyIndex: keyIndex,
          type: swapType,
          status: swapStatus,
          environment: environment,
          creationTime: creationDateTime,
          sendWalletId: sendWalletId,
          invoice: invoice,
          paymentAddress: paymentAddress,
          paymentAmount: paymentAmount,
          sendTxid: sendTxid,
          preimage: preimage,
          refundAddress: refundAddress,
          refundTxid: refundTxid,
          fees: SwapFees(
            boltzFee: boltzFees,
            lockupFee: lockupFees,
            claimFee: claimFees,
            refundFee: refundFees,
          ),
          completionTime: completionTime != null
              ? DateTime.fromMillisecondsSinceEpoch(completionTime)
              : null,
          recovered: recovered,
        ),
      ChainSwapModel(
        :final id,
        :final keyIndex,
        :final sendWalletId,
        :final sendTxid,
        :final receiveWalletId,
        :final receiveAddress,
        :final receiveTxid,
        :final paymentAddress,
        :final paymentAmount,
        :final refundAddress,
        :final refundTxid,
        :final boltzFees,
        :final lockupFees,
        :final claimFees,
        :final refundFees,
        :final serverNetworkFees,
        :final completionTime,
        :final recovered,
      ) =>
        Swap.chain(
          id: id,
          keyIndex: keyIndex,
          type: swapType,
          status: swapStatus,
          environment: environment,
          creationTime: creationDateTime,
          sendWalletId: sendWalletId,
          sendTxid: sendTxid,
          paymentAddress: paymentAddress,
          paymentAmount: paymentAmount,
          receiveWalletId: receiveWalletId,
          receiveAddress: receiveAddress,
          receiveTxid: receiveTxid,
          refundAddress: refundAddress,
          refundTxid: refundTxid,
          fees: SwapFees(
            boltzFee: boltzFees,
            lockupFee: lockupFees,
            claimFee: claimFees,
            refundFee: refundFees,
            serverNetworkFees: serverNetworkFees,
          ),
          completionTime: completionTime != null
              ? DateTime.fromMillisecondsSinceEpoch(completionTime)
              : null,
          recovered: recovered,
        ),
    };
  }

  // Common helper methods
  String get swapId => switch (this) {
    LnReceiveSwapModel(:final id) => id,
    LnSendSwapModel(:final id) => id,
    ChainSwapModel(:final id) => id,
  };

  // Factory methods for JSON serialization/deserialization
  factory SwapModel.fromJson(Map<String, dynamic> json) =>
      _$SwapModelFromJson(json);
}
