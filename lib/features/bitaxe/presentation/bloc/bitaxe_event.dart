import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bitaxe_event.freezed.dart';

@freezed
sealed class BitaxeEvent with _$BitaxeEvent {
  const factory BitaxeEvent.connectToDevice({
    required String ipAddress,
    required Wallet wallet,
  }) = ConnectToDevice;

  const factory BitaxeEvent.startPolling() = StartPolling;
  const factory BitaxeEvent.stopPolling() = StopPolling;
  const factory BitaxeEvent.refreshSystemInfo() = RefreshSystemInfo;
  const factory BitaxeEvent.identifyDevice() = IdentifyDevice;
  const factory BitaxeEvent.clearError() = ClearError;
  const factory BitaxeEvent.loadStoredConnection() = LoadStoredConnection;
  const factory BitaxeEvent.removeConnection() = RemoveConnection;
}
