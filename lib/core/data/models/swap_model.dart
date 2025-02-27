import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/entities/swap.dart';
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
  }) = _SwapModel;
  const SwapModel._();

  factory SwapModel.fromEntity(Swap swap) {
    return SwapModel(
      id: swap.id,
      type: swap.type.name,
      status: swap.status.name,
      isTestnet: swap.environment == Environment.testnet,
    );
  }

  factory SwapModel.fromJson(Map<String, Object?> json) =>
      _$SwapModelFromJson(json);
}
