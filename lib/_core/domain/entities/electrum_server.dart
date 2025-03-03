import 'package:bb_mobile/_core/domain/entities/wallet.dart';
import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/_utils/constants.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'electrum_server.freezed.dart';

@freezed
sealed class ElectrumServer with _$ElectrumServer {
  factory ElectrumServer.custom({
    required String url,
    required Network network,
    String? socks5,
    @Default(20) int stopGap,
    @Default(5) int timeout,
    @Default(5) int retry,
    @Default(true) bool validateDomain,
  }) = CustomElectrumServer;

  factory ElectrumServer.bullBitcoin({
    required String url,
    required Network network,
    String? socks5,
    @Default(20) int stopGap,
    @Default(5) int timeout,
    @Default(5) int retry,
    @Default(true) bool validateDomain,
  }) = BullBitcoinElectrumServer;

  factory ElectrumServer.bullBitcoinFromNetwork({
    required Network network,
  }) {
    switch (network) {
      case Network.bitcoinMainnet:
        return ElectrumServer.bullBitcoin(
          url: ApiServiceConstants.bbElectrumUrlPath,
          network: network,
        );
      case Network.bitcoinTestnet:
        return ElectrumServer.bullBitcoin(
          url: ApiServiceConstants.bbElectrumTestUrlPath,
          network: network,
        );
      case Network.liquidMainnet:
        return ElectrumServer.bullBitcoin(
          url: ApiServiceConstants.bbLiquidElectrumUrlPath,
          network: network,
        );
      case Network.liquidTestnet:
        return ElectrumServer.bullBitcoin(
          url: ApiServiceConstants.bbLiquidElectrumTestUrlPath,
          network: network,
        );
    }
  }
}
