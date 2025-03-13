import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/swap.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'dart:convert';

part 'swap_model.freezed.dart';
part 'swap_model.g.dart';

@freezed
class SwapModel with _$SwapModel {
  const factory SwapModel({
    required String id,
    required String type,
    required String status,
    @Default(false) bool isTestnet,
    required int keyIndex,
    required int creationTime,
    int? completionTime,
    // Changed from Map<String, dynamic>? to String?
    String? chainSwapJson,
    String? lnReceiveSwapJson,
    String? lnSendSwapJson,
  }) = _SwapModel;

  const SwapModel._();

  factory SwapModel.fromEntity(Swap swap) {
    return SwapModel(
      id: swap.id,
      type: swap.type.name,
      status: swap.status.name,
      isTestnet: swap.environment == Environment.testnet,
      keyIndex: swap.keyIndex,
      creationTime: swap.creationTime.millisecondsSinceEpoch,
      completionTime: swap.completionTime?.millisecondsSinceEpoch,
      chainSwapJson: swap.chainSwapDetails == null
          ? null
          : jsonEncode(swap.chainSwapDetails!.toJson()),
      lnReceiveSwapJson: swap.receiveSwapDetails == null
          ? null
          : jsonEncode(swap.receiveSwapDetails!.toJson()),
      lnSendSwapJson: swap.sendSwapDetails == null
          ? null
          : jsonEncode(swap.sendSwapDetails!.toJson()),
    );
  }

  Swap toEntity() {
    return Swap(
      id: id,
      type: SwapType.values.byName(type),
      status: SwapStatus.values.byName(status),
      environment: isTestnet ? Environment.testnet : Environment.mainnet,
      creationTime: DateTime.fromMillisecondsSinceEpoch(creationTime),
      completionTime: completionTime == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(completionTime!),
      keyIndex: keyIndex,
      chainSwapDetails: chainSwapJson == null
          ? null
          : ChainSwap.fromJson(
              jsonDecode(chainSwapJson!) as Map<String, dynamic>,
            ),
      receiveSwapDetails: lnReceiveSwapJson == null
          ? null
          : LnReceiveSwap.fromJson(
              jsonDecode(lnReceiveSwapJson!) as Map<String, dynamic>,
            ),
      sendSwapDetails: lnSendSwapJson == null
          ? null
          : LnSendSwap.fromJson(
              jsonDecode(lnSendSwapJson!) as Map<String, dynamic>,
            ),
    );
  }

  factory SwapModel.fromJson(Map<String, Object?> json) =>
      _$SwapModelFromJson(json);
}
