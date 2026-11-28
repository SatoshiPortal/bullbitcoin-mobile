import 'package:bb_mobile/overview_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overview/routes.dart';
import 'package:primitives/primitives.dart';

void main() {
  test('the real wallet detail route retains its public name and path', () {
    final route = OverviewRouter.walletDetailRoute(
      scopeWalletHistory: (_, child) => child,
      onOpenCoins: (_, _) async {},
      loadCoinSummary: (_) async => Ok((count: 0, frozenSat: BigInt.zero)),
    );
    expect(WalletRoute.walletHome.name, 'walletHome');
    expect(WalletRoute.walletHome.path, '/wallet');
    expect(WalletRoute.walletDetail.name, 'walletDetail');
    expect(WalletRoute.walletDetail.path, '/wallet/:walletId');
    expect(route.name, WalletRoute.walletDetail.name);
    expect(route.path, WalletRoute.walletDetail.path);
  });
}
