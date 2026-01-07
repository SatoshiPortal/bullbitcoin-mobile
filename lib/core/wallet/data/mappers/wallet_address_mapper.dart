import 'package:bb_mobile/features/labels/domain/label.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_address_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';

class WalletAddressMapper {
  static WalletAddress toEntity(
    WalletAddressModel walletAddressModel, {
    List<Label> labels = const [],
  }) {
    return WalletAddress(
      walletId: walletAddressModel.walletId,
      index: walletAddressModel.index,
      address: walletAddressModel.address,
      keyChain: walletAddressModel.isChange
          ? WalletAddressKeyChain.internal
          : WalletAddressKeyChain.external,
      balanceSat: walletAddressModel.balanceSat,
      nrOfTransactions: walletAddressModel.nrOfTransactions,
      //highestPreviousBalanceSat: walletAddressModel.highestPreviousBalanceSat,
      labels: labels,
      createdAt: walletAddressModel.createdAt,
      updatedAt: walletAddressModel.updatedAt,
    );
  }

  static WalletAddressModel fromEntity(WalletAddress walletAddress) {
    return WalletAddressModel(
      address: walletAddress.address,
      walletId: walletAddress.walletId,
      index: walletAddress.index,
      isChange: walletAddress.keyChain == WalletAddressKeyChain.internal,
      balanceSat: walletAddress.balanceSat,
      nrOfTransactions: walletAddress.nrOfTransactions,
      createdAt: walletAddress.createdAt,
      updatedAt: walletAddress.updatedAt,
    );
  }
}
