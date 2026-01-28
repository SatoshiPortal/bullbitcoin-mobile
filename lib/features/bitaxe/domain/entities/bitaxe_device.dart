import 'package:bb_mobile/features/bitaxe/domain/entities/system_info.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bitaxe_device.freezed.dart';

/// Domain entity representing a Bitaxe device
///
/// Note: `systemInfo` is optional because:
/// - It's fetched fresh from the device each time (not stored)
/// - Stored connections don't have SystemInfo until fetched
/// - When retrieved from storage, SystemInfo will be null until fetched
@freezed
sealed class BitaxeDevice with _$BitaxeDevice {
  const factory BitaxeDevice({
    required String ipAddress,
    required String hostname,
    SystemInfo? systemInfo, // Optional - fetched fresh when needed
    DateTime? lastConnected,
  }) = _BitaxeDevice;

  const BitaxeDevice._();

  /// Business logic: Check if device is currently connected
  /// Returns false if SystemInfo is not available (device not connected or info not fetched)
  bool get isConnected {
    final info = systemInfo;
    return info?.ipv4 == ipAddress;
  }
}
