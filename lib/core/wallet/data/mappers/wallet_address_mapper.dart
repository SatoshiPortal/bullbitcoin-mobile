import 'package:bb_mobile/core/wallet/data/models/wallet_address_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';

class WalletAddressMapper {
  static WalletAddress toEntity(
    WalletAddressModel walletAddressModel, {
    required String walletId,
    required WalletAddressKeyChain keyChain,
    required WalletAddressStatus status,
    int? balanceSat,
    int? highestPreviousBalanceSat,
  }) {
    return switch (walletAddressModel) {
      BitcoinWalletAddressModel(:final index, :final address) =>
        WalletAddress.bitcoin(
          walletId: walletId,
          index: index,
          address: address,
          keyChain: keyChain,
          status: status,
          balanceSat: balanceSat,
          highestPreviousBalanceSat: highestPreviousBalanceSat,
        ),
      LiquidWalletAddressModel(
        :final index,
        :final standard,
        :final confidential,
      ) =>
        WalletAddress.liquid(
          walletId: walletId,
          index: index,
          standard: standard,
          confidential: confidential,
          keyChain: keyChain,
          status: status,
          balanceSat: balanceSat,
          highestPreviousBalanceSat: highestPreviousBalanceSat,
        ),
    };
  }
}
