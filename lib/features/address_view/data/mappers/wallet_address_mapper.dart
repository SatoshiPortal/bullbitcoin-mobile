import 'package:sync/sync.dart' show Keychain;
import 'package:bb_mobile/features/address_view/data/models/wallet_address_model.dart';
import 'package:bb_mobile/features/address_view/domain/wallet_address.dart';
import 'package:labels/labels.dart';

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
          ? Keychain.internal
          : Keychain.external,
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
      isChange: walletAddress.keyChain == Keychain.internal,
      balanceSat: walletAddress.balanceSat,
      nrOfTransactions: walletAddress.nrOfTransactions,
      createdAt: walletAddress.createdAt,
      updatedAt: walletAddress.updatedAt,
    );
  }
}
