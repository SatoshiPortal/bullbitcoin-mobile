import 'package:bb_mobile/features/bitaxe/domain/entities/pool_configuration.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'system_info.freezed.dart';

/// Domain entity representing minimal system information from Bitaxe device
@freezed
sealed class SystemInfo with _$SystemInfo {
  const factory SystemInfo({
    // Hardware
    required String asicModel,
    required String boardVersion,

    // Hashrate
    required double hashRate,
    double? hashRate1m,
    double? hashRate10m,
    double? hashRate1h,

    // Power & Electrical
    required double power,
    required double voltage,
    required double current,
    required int maxPower,
    required int nominalVoltage,
    required int coreVoltage,
    required double coreVoltageActual,

    // Temperature
    required double temp,
    required double temp2,
    required double vrTemp,
    required int temptarget,
    required int overheatMode,

    // Pool Configuration
    required PoolConfiguration primaryPool,
    required PoolConfiguration fallbackPool,
    required int isUsingFallbackStratum,
    required int poolAddrFamily,
    required double responseTime,

    // Network
    required String hostname,
    required String ipv4,
    String? ipv6,
  }) = _SystemInfo;

  const SystemInfo._();

  /// Business logic: Hashrate formated for display
  /// API returns hashrate in GH/s; we convert to Th/s
  String get formattedHashRate =>
      '${(hashRate / 1000.0).toStringAsFixed(2)} Th/s';

  /// Business logic: Input voltage formatted for display.
  /// API returns voltage in mV; we convert to V
  String get formattedInputVoltage =>
      '${(voltage / 1000).toStringAsFixed(1)} V';

  /// Business logic: ASIC temperature formatted for display
  String get formattedAsicTemp => '${temp.toStringAsFixed(1)} °C';
}
