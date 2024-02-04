import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'electrum.freezed.dart';
part 'electrum.g.dart';

enum ElectrumTypes { blockstream, bullbitcoin, custom }

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
    @Default(ElectrumTypes.bullbitcoin) ElectrumTypes type,
  }) = _BullbitcoinElectrumNetwork;

  const factory ElectrumNetwork.defaultElectrum({
    @Default('ssl://$openelectrum:50002') String mainnet,
    @Default('ssl://$openelectrum:60002') String testnet,
    @Default(20) int stopGap,
    @Default(5) int timeout,
    @Default(5) int retry,
    @Default(true) bool validateDomain,
    @Default('blockstream') String name,
    @Default(ElectrumTypes.blockstream) ElectrumTypes type,
  }) = _DefaultElectrumNetwork;

  const factory ElectrumNetwork.custom({
    required String mainnet,
    required String testnet,
    @Default(20) int stopGap,
    @Default(5) int timeout,
    @Default(5) int retry,
    @Default(true) bool validateDomain,
    @Default('custom') String name,
    @Default(ElectrumTypes.custom) ElectrumTypes type,
  }) = _CustomElectrumNetwork;

  const ElectrumNetwork._();

  factory ElectrumNetwork.fromJson(Map<String, dynamic> json) => _$ElectrumNetworkFromJson(json);

  String getNetworkUrl(bool isTestnet, {bool split = true}) {
    String url;
    if (isTestnet)
      url = testnet;
    else
      url = mainnet;

    if (split) url = url.split('://')[1];

    return url;
  }
}
