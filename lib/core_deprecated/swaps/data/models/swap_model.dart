import 'package:bb_mobile/core_deprecated/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/infra/database/sqlite_database.dart';
import 'package:bb_mobile/core/infra/database/tables/swaps_table.dart';
import 'package:bb_mobile/core_deprecated/swaps/domain/entity/swap.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

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
    int? completionTime,
    int? boltzFees,
    int? lockupFees,
    int? claimFees,
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
    int? serverNetworkFees,
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
        fees: final fees,
        completionTime: final completionTime,
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
          completionTime: completionTime?.millisecondsSinceEpoch,
          boltzFees: fees?.boltzFee,
          lockupFees: fees?.lockupFee,
          claimFees: fees?.claimFee,
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
          serverNetworkFees: fees?.serverNetworkFees,
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
        :final boltzFees,
        :final lockupFees,
        :final claimFees,
        :final completionTime,
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
          fees: SwapFees(
            boltzFee: boltzFees,
            lockupFee: lockupFees,
            claimFee: claimFees,
          ),
          completionTime: completionTime != null
              ? DateTime.fromMillisecondsSinceEpoch(completionTime)
              : null,
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
        :final completionTime,
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
          ),
          completionTime: completionTime != null
              ? DateTime.fromMillisecondsSinceEpoch(completionTime)
              : null,
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
        :final serverNetworkFees,
        :final completionTime,
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
            serverNetworkFees: serverNetworkFees,
          ),
          completionTime: completionTime != null
              ? DateTime.fromMillisecondsSinceEpoch(completionTime)
              : null,
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

  factory SwapModel.fromSqlite(SwapRow swap) {
    switch (swap.direction) {
      case SwapDirection.receive:
        return SwapModel.lnReceive(
          id: swap.id,
          type: swap.type,
          status: swap.status,
          isTestnet: swap.isTestnet,
          keyIndex: swap.keyIndex,
          creationTime: swap.creationTime,
          receiveWalletId: swap.receiveWalletId!,
          receiveAddress: swap.receiveAddress,
          receiveTxid: swap.receiveTxid,
          completionTime: swap.completionTime,
          boltzFees: swap.boltzFees,
          lockupFees: swap.lockupFees,
          claimFees: swap.claimFees,
          invoice: swap.invoice!,
        );
      case SwapDirection.send:
        return SwapModel.lnSend(
          id: swap.id,
          type: swap.type,
          status: swap.status,
          isTestnet: swap.isTestnet,
          keyIndex: swap.keyIndex,
          creationTime: swap.creationTime,
          sendWalletId: swap.sendWalletId!,
          paymentAddress: swap.paymentAddress!,
          paymentAmount: swap.paymentAmount!,
          completionTime: swap.completionTime,
          invoice: swap.invoice!,
          sendTxid: swap.sendTxid,
          preimage: swap.preimage,
          refundAddress: swap.refundAddress,
          refundTxid: swap.refundTxid,
          boltzFees: swap.boltzFees,
          lockupFees: swap.lockupFees,
          claimFees: swap.claimFees,
        );
      case SwapDirection.onchain:
        return SwapModel.chain(
          id: swap.id,
          type: swap.type,
          status: swap.status,
          isTestnet: swap.isTestnet,
          keyIndex: swap.keyIndex,
          creationTime: swap.creationTime,
          completionTime: swap.completionTime,
          receiveWalletId: swap.receiveWalletId,
          sendWalletId: swap.sendWalletId!,
          paymentAddress: swap.paymentAddress!,
          paymentAmount: swap.paymentAmount!,
          receiveAddress: swap.receiveAddress,
          receiveTxid: swap.receiveTxid,
          sendTxid: swap.sendTxid,
          refundAddress: swap.refundAddress,
          refundTxid: swap.refundTxid,
          boltzFees: swap.boltzFees,
          lockupFees: swap.lockupFees,
          claimFees: swap.claimFees,
          serverNetworkFees: swap.serverNetworkFees,
        );
    }
  }

  SwapRow toSqlite() {
    if (this is LnReceiveSwapModel) {
      final swap = this as LnReceiveSwapModel;
      return SwapRow(
        id: swap.id,
        type: swap.type,
        direction: SwapDirection.receive,
        status: swap.status,
        isTestnet: swap.isTestnet,
        keyIndex: swap.keyIndex,
        creationTime: swap.creationTime,
        receiveWalletId: swap.receiveWalletId,
        invoice: swap.invoice,
        receiveAddress: swap.receiveAddress,
        receiveTxid: swap.receiveTxid,
        completionTime: swap.completionTime,
        boltzFees: swap.boltzFees,
        lockupFees: swap.lockupFees,
        claimFees: swap.claimFees,
      );
    } else if (this is LnSendSwapModel) {
      final swap = this as LnSendSwapModel;
      return SwapRow(
        id: swap.id,
        type: swap.type,
        direction: SwapDirection.send,
        status: swap.status,
        isTestnet: swap.isTestnet,
        keyIndex: swap.keyIndex,
        creationTime: swap.creationTime,
        completionTime: swap.completionTime,
        sendWalletId: swap.sendWalletId,
        invoice: swap.invoice,
        paymentAddress: swap.paymentAddress,
        paymentAmount: swap.paymentAmount,
        sendTxid: swap.sendTxid,
        preimage: swap.preimage,
        refundAddress: swap.refundAddress,
        refundTxid: swap.refundTxid,
        boltzFees: swap.boltzFees,
        lockupFees: swap.lockupFees,
        claimFees: swap.claimFees,
      );
    } else if (this is ChainSwapModel) {
      final swap = this as ChainSwapModel;

      return SwapRow(
        id: swap.id,
        type: swap.type,
        direction: SwapDirection.onchain,
        status: swap.status,
        isTestnet: swap.isTestnet,
        keyIndex: swap.keyIndex,
        creationTime: swap.creationTime,
        completionTime: swap.completionTime,
        receiveWalletId: swap.receiveWalletId,
        sendWalletId: swap.sendWalletId,
        paymentAddress: swap.paymentAddress,
        paymentAmount: swap.paymentAmount,
        sendTxid: swap.sendTxid,
        receiveAddress: swap.receiveAddress,
        receiveTxid: swap.receiveTxid,
        refundAddress: swap.refundAddress,
        refundTxid: swap.refundTxid,
        boltzFees: swap.boltzFees,
        lockupFees: swap.lockupFees,
        claimFees: swap.claimFees,
        serverNetworkFees: swap.serverNetworkFees,
      );
    } else {
      throw UnsupportedError('$SwapModel unsupported: $runtimeType');
    }
  }
}
