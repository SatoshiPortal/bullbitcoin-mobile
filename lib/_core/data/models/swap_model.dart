import 'dart:convert';

import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/swap.dart';
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
  }) = ChainSwapModel;

  const SwapModel._();

  factory SwapModel.fromEntity(Swap swap) {
    return swap.when(
      lnReceive: (id,
          keyIndex,
          type,
          status,
          environment,
          creationTime,
          receiveWalletId,
          invoice,
          receiveAddress,
          receiveTxid,
          boltzFee,
          lockupFee,
          claimFee,
          completionTime) {
        return SwapModel.lnReceive(
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
          boltzFees: boltzFee,
          lockupFees: lockupFee,
          claimFees: claimFee,
        );
      },
      lnSend: (id,
          keyIndex,
          type,
          status,
          environment,
          creationTime,
          sendWalletId,
          invoice,
          sendTxid,
          preimage,
          refundAddress,
          refundTxid,
          boltzFee,
          lockupFee,
          claimFee,
          completionTime) {
        return SwapModel.lnSend(
          id: id,
          type: type.name,
          status: status.name,
          isTestnet: environment == Environment.testnet,
          keyIndex: keyIndex,
          creationTime: creationTime.millisecondsSinceEpoch,
          sendWalletId: sendWalletId,
          invoice: invoice,
          sendTxid: sendTxid,
          preimage: preimage,
          refundAddress: refundAddress,
          refundTxid: refundTxid,
          completionTime: completionTime?.millisecondsSinceEpoch,
          boltzFees: boltzFee,
          lockupFees: lockupFee,
          claimFees: claimFee,
        );
      },
      chain: (id,
          keyIndex,
          type,
          status,
          environment,
          creationTime,
          sendWalletId,
          sendTxid,
          receiveWalletId,
          receiveAddress,
          receiveTxid,
          refundAddress,
          refundTxid,
          boltzFee,
          lockupFee,
          claimFee,
          completionTime) {
        return SwapModel.chain(
          id: id,
          type: type.name,
          status: status.name,
          isTestnet: environment == Environment.testnet,
          keyIndex: keyIndex,
          creationTime: creationTime.millisecondsSinceEpoch,
          sendWalletId: sendWalletId,
          sendTxid: sendTxid,
          receiveWalletId: receiveWalletId,
          receiveAddress: receiveAddress,
          receiveTxid: receiveTxid,
          refundAddress: refundAddress,
          refundTxid: refundTxid,
          completionTime: completionTime?.millisecondsSinceEpoch,
          boltzFees: boltzFee,
          lockupFees: lockupFee,
          claimFees: claimFee,
        );
      },
    );
  }

  Swap toEntity() {
    final swapType = SwapType.values.byName(type);
    final swapStatus = SwapStatus.values.byName(status);
    final environment = isTestnet ? Environment.testnet : Environment.mainnet;
    final creationDateTime = DateTime.fromMillisecondsSinceEpoch(creationTime);

    return map(
      lnReceive: (model) => Swap.lnReceive(
        id: model.id,
        keyIndex: model.keyIndex,
        type: swapType,
        status: swapStatus,
        environment: environment,
        creationTime: creationDateTime,
        receiveWalletId: model.receiveWalletId,
        invoice: model.invoice,
        receiveAddress: model.receiveAddress,
        receiveTxid: model.receiveTxid,
        boltzFee: model.boltzFees,
        lockupFee: model.lockupFees,
        claimFee: model.claimFees,
        completionTime: model.completionTime != null
            ? DateTime.fromMillisecondsSinceEpoch(model.completionTime!)
            : null,
      ),
      lnSend: (model) => Swap.lnSend(
        id: model.id,
        keyIndex: model.keyIndex,
        type: swapType,
        status: swapStatus,
        environment: environment,
        creationTime: creationDateTime,
        sendWalletId: model.sendWalletId,
        invoice: model.invoice,
        sendTxid: model.sendTxid,
        preimage: model.preimage,
        refundAddress: model.refundAddress,
        refundTxid: model.refundTxid,
        boltzFee: model.boltzFees,
        lockupFee: model.lockupFees,
        claimFee: model.claimFees,
        completionTime: model.completionTime != null
            ? DateTime.fromMillisecondsSinceEpoch(model.completionTime!)
            : null,
      ),
      chain: (model) => Swap.chain(
        id: model.id,
        keyIndex: model.keyIndex,
        type: swapType,
        status: swapStatus,
        environment: environment,
        creationTime: creationDateTime,
        sendWalletId: model.sendWalletId,
        sendTxid: model.sendTxid,
        receiveWalletId: model.receiveWalletId,
        receiveAddress: model.receiveAddress,
        receiveTxid: model.receiveTxid,
        refundAddress: model.refundAddress,
        refundTxid: model.refundTxid,
        boltzFee: model.boltzFees,
        lockupFee: model.lockupFees,
        claimFee: model.claimFees,
        completionTime: model.completionTime != null
            ? DateTime.fromMillisecondsSinceEpoch(model.completionTime!)
            : null,
      ),
    );
  }

  // Common helper methods
  String get swapId => map(
        lnReceive: (model) => model.id,
        lnSend: (model) => model.id,
        chain: (model) => model.id,
      );

  // Factory methods for JSON serialization/deserialization
  factory SwapModel.fromJson(Map<String, dynamic> json) =>
      _$SwapModelFromJson(json);
}
