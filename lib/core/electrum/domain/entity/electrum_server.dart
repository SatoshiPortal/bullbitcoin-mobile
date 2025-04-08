import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'electrum_server.freezed.dart';

enum ElectrumServerProvider {
  custom,
  bullBitcoin,
  blockstream,
}

@freezed
sealed class ElectrumServer with _$ElectrumServer {
  factory ElectrumServer({
    required ElectrumServerProvider provider,
    required String url,
    required Network network,
    String? socks5,
    @Default(20) int stopGap,
    @Default(5) int timeout,
    @Default(5) int retry,
    @Default(true) bool validateDomain,
  }) = _ElectrumServer;
  const ElectrumServer._();
}
