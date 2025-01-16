import 'package:bb_mobile/features/wallet/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_repository.dart';

class LwkWalletRepository implements WalletRepository, LiquidWalletRepository {
  final WalletMetadata metadata;

  @override
  String get walletId => metadata.id;

  const LwkWalletRepository({required this.metadata, required String seed});
}
