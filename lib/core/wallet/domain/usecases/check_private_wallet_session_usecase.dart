import 'package:bb_mobile/core/wallet/data/wallet_signing_material_resolver.dart';

/// Answers whether a wallet's private capability is loaded, for callers that
/// need to show loaded/locked state without being able to reach the material.
final class CheckPrivateWalletSessionUsecase {
  final WalletSigningMaterialResolver _resolver;

  const CheckPrivateWalletSessionUsecase(this._resolver);

  bool isLoaded(String walletId) =>
      _resolver.isPrivateCapabilityLoaded(walletId);
}
