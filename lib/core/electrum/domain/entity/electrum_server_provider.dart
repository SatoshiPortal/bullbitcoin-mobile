import 'package:freezed_annotation/freezed_annotation.dart';

part 'electrum_server_provider.freezed.dart';

enum DefaultElectrumServerProvider { bullBitcoin, blockstream }

@freezed
sealed class ElectrumServerProvider with _$ElectrumServerProvider {
  const factory ElectrumServerProvider.customProvider() =
      CustomElectrumServerProvider;
  const factory ElectrumServerProvider.defaultProvider({
    @Default(DefaultElectrumServerProvider.bullBitcoin)
    DefaultElectrumServerProvider defaultServerProvider,
  }) = DefaultServerProvider;
}
