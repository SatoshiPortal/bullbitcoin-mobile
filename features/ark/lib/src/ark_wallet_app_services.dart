import 'package:address_view/address_view.dart' show AddressView;
import 'package:bull_ui/bull_ui.dart' show BuildContext, Widget;
import 'package:fees/fees.dart' show Fees;
import 'package:get_it/get_it.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart'
    show WalletInventory, WalletRegistration, WalletRegistrationNotFoundFailure;
import 'package:spend/spend.dart' show Spend;
import 'package:sync/sync.dart'
    show
        SyncReason,
        SyncStorageFailure,
        WalletCatalogPort,
        WalletKey,
        WalletSnapshotException;
import 'package:sync/write.dart' show ForegroundWalletSynchronization;

import 'ark_app_services.dart';
import 'data/ark_reserve_top_up.dart';
import 'domain/ark_display_data_port.dart';
import 'domain/ark_failure.dart';

/// Binds Ark to the app's wallet capabilities. Service lookups happen only
/// when a callback needs them. The host supplies artwork and navigation.
ArkAppServices arkWalletAppServices(
  GetIt locator, {
  Widget? walletBackground,
  Widget? confirmIcon,
  void Function(BuildContext context)? onHome,
}) => ArkAppServices(
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
      // This is a best-effort refresh, not Spend authorization.
      if (await locator<WalletInventory>().readWallet(id) case Ok(
        :final value,
      )) {
        await locator<ForegroundWalletSynchronization>().executeKey(
          WalletKey(id: value.id, network: value.network),
          locator<WalletCatalogPort>(),
          reason: SyncReason.manual,
        );
      }
    },
  )(walletId, address, amount),
  walletName: (walletId) async =>
      switch (await locator<WalletInventory>().readWallet(walletId)) {
        Ok(value: WalletRegistration(isDefault: true)) =>
          const ArkDefaultSourceWallet(),
        Ok(value: WalletRegistration(:final label?))
            when label.trim().isNotEmpty =>
          ArkNamedSourceWallet(label),
        Ok(:final value) => ArkNamedSourceWallet(_sourceOrigin(value.id)),
        Err(failure: WalletRegistrationNotFoundFailure()) => null,
        Err() => throw const WalletSnapshotException(SyncStorageFailure()),
      },
  walletBackground: walletBackground,
  confirmIcon: confirmIcon,
  onHome: onHome,
);

String _sourceOrigin(String id) {
  const suffix = ':regtest';
  return id.endsWith(suffix) ? id.substring(0, id.length - suffix.length) : id;
}
