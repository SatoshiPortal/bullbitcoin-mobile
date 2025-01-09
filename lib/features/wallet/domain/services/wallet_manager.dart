abstract class WalletManager {}

class WalletManagerImpl implements WalletManager {
  WalletManagerImpl({
    required this.storage,
  });

  final IStorage storage;
}
