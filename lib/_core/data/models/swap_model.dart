import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/swap.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

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
    Map<String, dynamic>? chainSwapJson,
    Map<String, dynamic>? lnReceiveSwapJson,
    Map<String, dynamic>? lnSendSwapJson,
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
      chainSwapJson: swap.chainSwapDetails?.toJson(),
      lnReceiveSwapJson: swap.receiveSwapDetails?.toJson(),
      lnSendSwapJson: swap.sendSwapDetails?.toJson(),
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
      chainSwapDetails:
          chainSwapJson != null ? ChainSwap.fromJson(chainSwapJson!) : null,
      receiveSwapDetails: lnReceiveSwapJson != null
          ? LnReceiveSwap.fromJson(lnReceiveSwapJson!)
          : null,
      sendSwapDetails:
          lnSendSwapJson != null ? LnSendSwap.fromJson(lnSendSwapJson!) : null,
    );
  }

  factory SwapModel.fromJson(Map<String, Object?> json) =>
      _$SwapModelFromJson(json);
}
