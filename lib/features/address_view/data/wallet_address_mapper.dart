import 'package:wallet/wallet.dart';
import '../domain/wallet_address.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';

class WalletAddressMapper {
  static WalletAddress toEntity(
    WalletAddressRecord walletAddressModel, {
    List<Label> labels = const [],
  }) {
    return WalletAddress(
      walletId: walletAddressModel.walletId,
      index: walletAddressModel.index,
      address: walletAddressModel.address,
      keyChain: walletAddressModel.keyChain,
      balanceSat: walletAddressModel.balanceSat,
      nrOfTransactions: walletAddressModel.nrOfTransactions,
      //highestPreviousBalanceSat: walletAddressModel.highestPreviousBalanceSat,
      labels: labels,
      createdAt: walletAddressModel.createdAt,
      updatedAt: walletAddressModel.updatedAt,
    );
  }
}
