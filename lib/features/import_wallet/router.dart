import 'package:bb_mobile/features/import_wallet/import_wallet_page.dart';
import 'package:go_router/go_router.dart';

enum ImportWalletRoute {
  importWalletHome('/import-wallet-home');

  final String path;

  const ImportWalletRoute(this.path);
}

class ImportWalletRouter {
  static final route = GoRoute(
    name: ImportWalletRoute.importWalletHome.name,
    path: ImportWalletRoute.importWalletHome.path,
    builder: (context, state) => const ImportWalletPage(),
  );
}
