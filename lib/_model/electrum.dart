import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'electrum.freezed.dart';
part 'electrum.g.dart';

@freezed
class ElectrumNetwork with _$ElectrumNetwork {
  const factory ElectrumNetwork.bullbitcoin({
    @Default('ssl://$bbelectrum:50002') String mainnet,
    @Default('ssl://$bbelectrum:60002') String testnet,
    @Default(20) int stopGap,
    @Default(5) int timeout,
    @Default(5) int retry,
    @Default(true) bool validateDomain,
    @Default('bullbitcoin') String name,
  }) = _BullbitcoinElectrumNetwork;

  const factory ElectrumNetwork.defaultElectrum({
    @Default('ssl://$openelectrum:50002') String mainnet,
    @Default('ssl://$openelectrum:60002') String testnet,
    @Default(20) int stopGap,
    @Default(5) int timeout,
    @Default(5) int retry,
    @Default(true) bool validateDomain,
    @Default('default') String name,
  }) = _DefaultElectrumNetwork;

  const factory ElectrumNetwork.custom({
    required String mainnet,
    required String testnet,
    @Default(20) int stopGap,
    @Default(5) int timeout,
    @Default(5) int retry,
    @Default(true) bool validateDomain,
    @Default('custom') String name,
  }) = _CustomElectrumNetwork;

  factory ElectrumNetwork.fromJson(Map<String, dynamic> json) =>
      _$ElectrumNetworkFromJson(json);
}
