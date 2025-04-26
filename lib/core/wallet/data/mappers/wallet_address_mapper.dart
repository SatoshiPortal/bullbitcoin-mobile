import 'package:bb_mobile/core/wallet/data/models/wallet_address_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';

class WalletAddressMapper {
  static WalletAddress toEntity(
    WalletAddressModel walletAddressModel, {
    required WalletAddressKeyChain keyChain,
    required WalletAddressStatus status,
    int? balanceSat,
    int? highestPreviousBalanceSat,
  }) {
    return walletAddressModel.when(
      bitcoin: (index, address) => WalletAddress.bitcoin(
        index: index,
        address: address,
        keyChain: keyChain,
        status: status,
        balanceSat: balanceSat,
        highestPreviousBalanceSat: highestPreviousBalanceSat,
      ),
      liquid: (index, standard, confidential) => WalletAddress.liquid(
        index: index,
        standard: standard,
        confidential: confidential,
        keyChain: keyChain,
        status: status,
        balanceSat: balanceSat,
        highestPreviousBalanceSat: highestPreviousBalanceSat,
      ),
    );
  }
}
