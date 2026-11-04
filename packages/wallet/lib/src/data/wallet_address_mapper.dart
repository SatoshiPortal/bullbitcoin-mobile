import 'package:wallet/wallet.dart';
import 'models/wallet_address_model.dart';

class WalletAddressMapper {
  static WalletAddressRecord toEntity(WalletAddressModel walletAddressModel) {
    return WalletAddressRecord(
      walletId: walletAddressModel.walletId,
      index: walletAddressModel.index,
      address: walletAddressModel.address,
      keyChain: walletAddressModel.isChange
          ? WalletAddressKeyChain.internal
          : WalletAddressKeyChain.external,
      balanceSat: walletAddressModel.balanceSat,
      nrOfTransactions: walletAddressModel.nrOfTransactions,
      //highestPreviousBalanceSat: walletAddressModel.highestPreviousBalanceSat,
      createdAt: walletAddressModel.createdAt,
      updatedAt: walletAddressModel.updatedAt,
    );
  }
}
