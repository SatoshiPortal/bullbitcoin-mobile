import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';

/// Read capability used by flows that offer the wallet's change addresses.
abstract interface class ChangeAddressPort {
  Future<List<WalletAddress>> getUsedChangeAddresses(
    String walletId, {
    int? limit,
    int? fromIndex,
    required bool descending,
  });
}
