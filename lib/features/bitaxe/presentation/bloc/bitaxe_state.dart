import 'package:bb_mobile/features/bitaxe/domain/entities/bitaxe_device.dart';
import 'package:bb_mobile/features/bitaxe/domain/errors/bitaxe_domain_error.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bitaxe_state.freezed.dart';

@freezed
sealed class BitaxeState with _$BitaxeState {
  const factory BitaxeState({
    BitaxeDevice? device,
    @Default(false) bool isConnecting,
    @Default(false) bool isPolling,
    @Default(false) bool isLoadingSystemInfo,
    BitaxeDomainError? error,
    ConnectionStep? currentStep,
    @Default(false) bool isRestarting,
    @Default(false) bool isRemovingConnection,
  }) = _BitaxeState;
}

enum ConnectionStep { testingConnection, completed }
