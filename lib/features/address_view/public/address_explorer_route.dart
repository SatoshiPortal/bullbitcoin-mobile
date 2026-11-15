import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network;

export 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network;

enum AddressExplorerRoute {
  addressExplorer('/address-explorer');

  const AddressExplorerRoute(this.path);

  final String path;
}

final class AddressExplorerArgs {
  final String address;
  final Network network;

  const AddressExplorerArgs({required this.address, required this.network});
}
