import 'package:bb_mobile/core/storage/sqlite_database.dart';

import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:drift/drift.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auto_swap_model.freezed.dart';

@freezed
sealed class AutoSwapModel with _$AutoSwapModel {
  const factory AutoSwapModel({
    @Default(false) bool enabled,
    @Default(1000000) int amountThreshold,
    @Default(3) int feeThreshold,
  }) = _AutoSwapModel;

  const AutoSwapModel._();

  factory AutoSwapModel.fromEntity(AutoSwap entity) {
    return AutoSwapModel(
      enabled: entity.enabled,
      amountThreshold: entity.amountThreshold,
      feeThreshold: entity.feeThreshold,
    );
  }

  AutoSwap toEntity() {
    return AutoSwap(
      enabled: enabled,
      amountThreshold: amountThreshold,
      feeThreshold: feeThreshold,
    );
  }

  factory AutoSwapModel.fromSqlite(AutoSwapRow row) {
    return AutoSwapModel(
      enabled: row.enabled,
      amountThreshold: row.amountThreshold,
      feeThreshold: row.feeThreshold,
    );
  }

  AutoSwapRow toSqlite() {
    return AutoSwapRow(
      id: 1,
      enabled: enabled,
      amountThreshold: amountThreshold,
      feeThreshold: feeThreshold,
    );
  }
}
