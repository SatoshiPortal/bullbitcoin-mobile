import 'package:bb_mobile/core/domain/entities/wallet_metadata.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_card_view_model.freezed.dart';

@freezed
class WalletCardViewModel with _$WalletCardViewModel {
  const factory WalletCardViewModel({
    required String walletId,
    required String name,
    required Network network,
    required BigInt balanceSat,
  }) = _WalletCardViewModel;
}
