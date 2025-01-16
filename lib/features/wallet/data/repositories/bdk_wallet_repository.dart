import 'package:bb_mobile/features/wallet/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_repository.dart';

class BdkWalletRepository implements WalletRepository, BitcoinWalletRepository {
  final WalletMetadata metadata;

  @override
  String get walletId => metadata.id;

  BdkWalletRepository({required this.metadata, required String seed});
}
