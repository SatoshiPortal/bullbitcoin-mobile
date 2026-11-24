import 'package:address_view/address_view.dart';
import 'package:bb_mobile/features/wallet/data/ark_reserve_top_up.dart';
import 'package:bb_mobile/features/wallet/data/ark_source_wallet_name.dart';
import 'package:bb_mobile/features/wallet/data/wallet_registrations.dart';
import 'package:bb_mobile/features/wallet/data/wallet_sync_binding.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bull_ark/ark_foreground_setup.dart' show ArkAppServices;
import 'package:bull_ark/ark_setup.dart' show ArkServiceUnavailableFailure;
import 'package:fees/fees.dart' show Fees;
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' show BoxFit, Image;
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart' show Spend;
import 'package:sync/sync.dart' show SyncReason, WalletCatalogPort;
import 'package:sync/write.dart' show ForegroundWalletSynchronization;

/// What the wallet gives Ark: its Secure Bitcoin operations (fresh receive
/// addresses, sends for exit fees, wallet names), its card artwork, the
/// confirmation arrow and the way home.
ArkAppServices walletArkAppServices(GetIt locator) => ArkAppServices(
  nextReceiveAddress: (walletId) async => switch (await locator<AddressView>()
      .receiveAddress(walletId: walletId, advance: true)) {
    Ok(:final value) => Ok(value.address),
    Err() => const Err(ArkServiceUnavailableFailure()),
  },
  send: (walletId, address, amount) => arkReserveSend(
    network: BitcoinNetwork.regtest,
    spend: locator<Spend>(),
    fees: locator<Fees>(),
    synchronize: (id) async {
      final key = await WalletSyncBinding.keyForId(
        locator<WalletRegistrations>(),
        id,
      );
      await locator<ForegroundWalletSynchronization>().executeKey(
        key,
        locator<WalletCatalogPort>(),
        reason: SyncReason.manual,
      );
    },
  )(walletId, address, amount),
  walletName: (walletId) async =>
      arkSourceWalletName(await locator<WalletRegistrations>().fetch(walletId)),
  walletBackground: Image.asset(
    Assets.backgrounds.bgSecureWallet.path,
    fit: BoxFit.cover,
  ),
  confirmIcon: Image.asset(Assets.icons.rightArrow.path, height: 24, width: 24),
  onHome: (context) => context.goNamed(WalletRoute.walletHome.name),
);
