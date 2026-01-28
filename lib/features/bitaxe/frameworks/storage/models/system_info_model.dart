// ignore_for_file: invalid_annotation_target

import 'package:bb_mobile/features/bitaxe/domain/entities/pool_configuration.dart';
import 'package:bb_mobile/features/bitaxe/domain/entities/system_info.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'system_info_model.freezed.dart';
part 'system_info_model.g.dart';

/// Data model for SystemInfo from API
@freezed
sealed class SystemInfoModel with _$SystemInfoModel {
  const factory SystemInfoModel({
    // Hardware
    @JsonKey(name: 'ASICModel') required String asicModel,
    required String boardVersion,

    // Hashrate
    required double hashRate,
    @JsonKey(name: 'hashRate_1m') double? hashRate1m,
    @JsonKey(name: 'hashRate_10m') double? hashRate10m,
    @JsonKey(name: 'hashRate_1h') double? hashRate1h,

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
    @JsonKey(name: 'overheat_mode') required int overheatMode,

    // Pool Configuration
    required String stratumURL,
    required int stratumPort,
    required String stratumUser,
    required int stratumExtranonceSubscribe,
    required int stratumSuggestedDifficulty,
    required String fallbackStratumURL,
    required int fallbackStratumPort,
    required String fallbackStratumUser,
    required int fallbackStratumExtranonceSubscribe,
    required int fallbackStratumSuggestedDifficulty,
    required int isUsingFallbackStratum,
    required int poolAddrFamily,
    required double responseTime,

    // Network
    required String hostname,
    required String ipv4,
    String? ipv6,
  }) = _SystemInfoModel;

  factory SystemInfoModel.fromJson(Map<String, dynamic> json) =>
      _$SystemInfoModelFromJson(json);

  const SystemInfoModel._();

  /// Convert model to domain entity
  SystemInfo toEntity() {
    return SystemInfo(
      asicModel: asicModel,
      boardVersion: boardVersion,
      hashRate: hashRate,
      hashRate1m: hashRate1m,
      hashRate10m: hashRate10m,
      hashRate1h: hashRate1h,
      power: power,
      voltage: voltage,
      current: current,
      maxPower: maxPower,
      nominalVoltage: nominalVoltage,
      coreVoltage: coreVoltage,
      coreVoltageActual: coreVoltageActual,
      temp: temp,
      temp2: temp2,
      vrTemp: vrTemp,
      temptarget: temptarget,
      overheatMode: overheatMode,
      primaryPool: PoolConfiguration(
        stratumURL: stratumURL,
        stratumPort: stratumPort,
        stratumUser: stratumUser,
        stratumExtranonceSubscribe: stratumExtranonceSubscribe == 1,
        stratumSuggestedDifficulty: stratumSuggestedDifficulty,
      ),
      fallbackPool: PoolConfiguration(
        stratumURL: fallbackStratumURL,
        stratumPort: fallbackStratumPort,
        stratumUser: fallbackStratumUser,
        stratumExtranonceSubscribe: fallbackStratumExtranonceSubscribe == 1,
        stratumSuggestedDifficulty: fallbackStratumSuggestedDifficulty,
      ),
      isUsingFallbackStratum: isUsingFallbackStratum,
      poolAddrFamily: poolAddrFamily,
      responseTime: responseTime,
      hostname: hostname,
      ipv4: ipv4,
      ipv6: ipv6,
    );
  }
}
