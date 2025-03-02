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
    required String receiveWalletReference,
    required String sendWalletReference,
    required int keyIndex,
    required int creationTime,
    int? completionTime,
  }) = _SwapModel;
  const SwapModel._();

  factory SwapModel.fromEntity(Swap swap) {
    return SwapModel(
      id: swap.id,
      type: swap.type.name,
      status: swap.status.name,
      isTestnet: swap.environment == Environment.testnet,
      receiveWalletReference: swap.receiveWalletReference,
      sendWalletReference: swap.sendWalletReference,
      keyIndex: swap.keyIndex,
      creationTime: swap.creationTime.millisecondsSinceEpoch,
      completionTime: swap.completionTime?.millisecondsSinceEpoch,
    );
  }

  Swap toEntity() {
    return Swap(
      id: id,
      receiveWalletReference: receiveWalletReference,
      sendWalletReference: sendWalletReference,
      type: SwapType.values.byName(type),
      status: SwapStatus.values.byName(status),
      environment: isTestnet ? Environment.testnet : Environment.mainnet,
      creationTime: DateTime.fromMillisecondsSinceEpoch(creationTime),
      completionTime: completionTime == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(completionTime!),
      keyIndex: keyIndex,
    );
  }

  factory SwapModel.fromJson(Map<String, Object?> json) =>
      _$SwapModelFromJson(json);
}
