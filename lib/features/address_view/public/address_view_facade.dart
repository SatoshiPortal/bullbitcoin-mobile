export '../domain/usecases/get_address_at_index_usecase.dart';
export '../domain/usecases/get_receive_address_usecase.dart';
import '../domain/labeled_wallet_address_repository.dart';
import '../domain/wallet_address.dart';

export '../domain/wallet_address.dart'
    show WalletAddress, $WalletAddressCopyWith;
export '../domain/labeled_wallet_address_repository.dart'
    show LabeledWalletAddressRepository;

/// Address projections enriched by the feature's labeling policy.
class AddressViewFacade {
  final LabeledWalletAddressRepository _repository;

  const AddressViewFacade(this._repository);

  Future<WalletAddress> getLastRevealedReceiveAddress({
    required String walletId,
  }) => _repository.getLastRevealedReceiveAddress(walletId: walletId);
}
