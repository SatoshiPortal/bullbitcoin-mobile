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
          url: ApiServiceConstants.bbElectrumUrl,
          network: network,
        );
      case Network.bitcoinTestnet:
        return ElectrumServer.bullBitcoin(
          url: ApiServiceConstants.bbElectrumTestUrl,
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

  factory ElectrumServer.publicFromNetwork({
    required Network network,
  }) {
    switch (network) {
      case Network.bitcoinMainnet:
        return ElectrumServer.custom(
          url: ApiServiceConstants.publicElectrumUrl,
          network: network,
        );
      case Network.bitcoinTestnet:
        return ElectrumServer.custom(
          url: ApiServiceConstants.publicElectrumTestUrl,
          network: network,
        );
      case Network.liquidMainnet:
        return ElectrumServer.custom(
          url: ApiServiceConstants.publicLiquidElectrumUrlPath,
          network: network,
        );
      case Network.liquidTestnet:
        return ElectrumServer.custom(
          url: ApiServiceConstants.publicliquidElectrumTestUrlPath,
          network: network,
        );
    }
  }
}
