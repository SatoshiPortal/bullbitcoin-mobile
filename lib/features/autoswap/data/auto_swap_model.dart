import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auto_swap_model.freezed.dart';

@freezed
sealed class AutoSwapModel with _$AutoSwapModel {
  const factory AutoSwapModel({
    @Default(true) bool enabled,
    @Default(1000000) int balanceThresholdSats,
    @Default(2000000) int triggerBalanceSats,
    @Default(3.0) double feeThresholdPercent,
    @Default(false) bool blockTillNextExecution,
    @Default(false) bool alwaysBlock,
    @Default(null) String? recipientWalletId,
    @Default(true) bool showWarning,
  }) = _AutoSwapModel;

  const AutoSwapModel._();

  factory AutoSwapModel.fromEntity(AutoSwap entity) {
    return AutoSwapModel(
      enabled: entity.enabled,
      balanceThresholdSats: entity.balanceThresholdSats,
      triggerBalanceSats: entity.triggerBalanceSats,
      feeThresholdPercent: entity.feeThresholdPercent,
      blockTillNextExecution: entity.blockTillNextExecution,
      alwaysBlock: entity.alwaysBlock,
      recipientWalletId: entity.recipientWalletId,
      showWarning: entity.showWarning,
    );
  }

  AutoSwap toEntity() {
    return AutoSwap(
      enabled: enabled,
      balanceThresholdSats: balanceThresholdSats,
      triggerBalanceSats: triggerBalanceSats,
      feeThresholdPercent: feeThresholdPercent,
      blockTillNextExecution: blockTillNextExecution,
      alwaysBlock: alwaysBlock,
      recipientWalletId: recipientWalletId,
      showWarning: showWarning,
    );
  }

  factory AutoSwapModel.fromSqlite(AutoSwapRow row) {
    return AutoSwapModel(
      enabled: row.enabled,
      balanceThresholdSats: row.balanceThresholdSats,
      triggerBalanceSats: row.triggerBalanceSats,
      feeThresholdPercent: row.feeThresholdPercent,
      blockTillNextExecution: row.blockTillNextExecution,
      alwaysBlock: row.alwaysBlock,
      recipientWalletId: row.recipientWalletId,
      showWarning: row.showWarning,
    );
  }

  AutoSwapRow toSqlite() {
    return AutoSwapRow(
      id: 1,
      enabled: enabled,
      balanceThresholdSats: balanceThresholdSats,
      triggerBalanceSats: triggerBalanceSats,
      feeThresholdPercent: feeThresholdPercent,
      blockTillNextExecution: blockTillNextExecution,
      alwaysBlock: alwaysBlock,
      recipientWalletId: recipientWalletId,
      showWarning: showWarning,
    );
  }
}
