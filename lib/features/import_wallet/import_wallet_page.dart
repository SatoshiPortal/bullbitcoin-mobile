import 'package:signers/signers.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/get_ledger_watch_only_wallet_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/get_bitbox_watch_only_wallet_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/import_watch_only_failure_l10n.dart';
import 'package:primitives/primitives.dart' show Err, Ok;
import 'package:bull_ui/bull_ui.dart' show BullSnackBar;
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:primitives/primitives.dart' show NetworkCapability;

import 'dart:io' show Platform;

import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/import_coldcard/router.dart';
import 'package:bb_mobile/features/import_mnemonic/router.dart';
import 'package:bb_mobile/features/import_qr_device/router.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullTabMenuVerticalButton, BullText, Gap, BullTypographyX;
import 'package:go_router/go_router.dart';

class ImportWalletPage extends StatelessWidget {
  const ImportWalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    final network = SettingsFacade.networkOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.importWalletTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              const Gap(16),
              BullText(
                context.loc.importWalletSectionGeneric,
                style: context.bullType.body.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Gap(12),
              BullTabMenuVerticalButton(
                title: context.loc.importWalletImportMnemonic,
                onTap: () => context.pushNamed(
                  ImportMnemonicRoute.importMnemonicHome.name,
                ),
              ),
              const Gap(16),
              BullTabMenuVerticalButton(
                title: context.loc.importWalletImportWatchOnly,
                onTap: () =>
                    context.pushNamed(ImportWatchOnlyWalletRoutes.import.name),
              ),
              NetworkCapabilityVisibility(
                capability: NetworkCapability.hardwareWallet,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Gap(24),
                    BullText(
                      context.loc.importWalletSectionHardware,
                      style: context.bullType.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Gap(12),
                    BullTabMenuVerticalButton(
                      title: context.loc.importWalletColdcardQ,
                      onTap: () => context.pushNamed(
                        ImportColdcardRoute.importColdcardQ.name,
                      ),
                    ),
                    const Gap(16),
                    BullTabMenuVerticalButton(
                      title: context.loc.importWalletColdcardMk4,
                      onTap: () => context.pushNamed(
                        ImportColdcardRoute.importColdcardMk4.name,
                      ),
                    ),
                    const Gap(16),
                    BullTabMenuVerticalButton(
                      title: context.loc.importWalletSeedSigner,
                      onTap: () => context.pushNamed(
                        ImportQrDeviceRoute.importSeedSigner.name,
                      ),
                    ),
                    const Gap(16),
                    BullTabMenuVerticalButton(
                      title: context.loc.importWalletSpecter,
                      onTap: () => context.pushNamed(
                        ImportQrDeviceRoute.importSpecter.name,
                      ),
                    ),
                    const Gap(16),
                    BullTabMenuVerticalButton(
                      title: context.loc.importWalletKrux,
                      onTap: () => context.pushNamed(
                        ImportQrDeviceRoute.importKrux.name,
                      ),
                    ),
                    const Gap(16),
                    BullTabMenuVerticalButton(
                      title: context.loc.importWalletJade,
                      onTap: () => context.pushNamed(
                        ImportQrDeviceRoute.importJade.name,
                      ),
                    ),
                    const Gap(16),
                    BullTabMenuVerticalButton(
                      title: context.loc.importWalletPassport,
                      onTap: () => context.pushNamed(
                        ImportQrDeviceRoute.importPassport.name,
                      ),
                    ),
                    const Gap(16),
                    BullTabMenuVerticalButton(
                      title: context.loc.importWalletKeystone,
                      onTap: () => context.pushNamed(
                        ImportQrDeviceRoute.importKeystone.name,
                      ),
                    ),
                    const Gap(16),
                    BullTabMenuVerticalButton(
                      title: context.loc.importWalletLedger,
                      onTap: network == null
                          ? null
                          : () async {
                              final account =
                                  await SignersNavigation.importLedger(
                                    context,
                                    network: network,
                                  );
                              if (account == null || !context.mounted) return;
                              final result = GetLedgerWatchOnlyWalletUsecase()
                                  .execute(
                                    account: account,
                                    label: context.loc.ledgerDefaultWalletLabel,
                                  );
                              switch (result) {
                                case Ok(:final value):
                                  await context.pushNamed(
                                    ImportWatchOnlyWalletRoutes.import.name,
                                    extra: value,
                                  );
                                case Err(:final failure):
                                  BullSnackBar.show(
                                    context,
                                    message: failure.toTranslated(context),
                                  );
                              }
                            },
                    ),
                    const Gap(16),
                    BullTabMenuVerticalButton(
                      title: Platform.isAndroid
                          ? context.loc.importWalletBitBox
                          : context.loc.importWalletBitBoxNova,
                      onTap: network == null
                          ? null
                          : () async {
                              final account =
                                  await SignersNavigation.importBitBox(
                                    context,
                                    network: network,
                                    requestedDeviceType: SignerDevice.bitbox02,
                                  );
                              if (account == null || !context.mounted) return;
                              final result = GetBitBoxWatchOnlyWalletUsecase()
                                  .execute(
                                    account: account,
                                    label: context
                                        .loc
                                        .bitboxScreenDefaultWalletLabel,
                                  );
                              switch (result) {
                                case Ok(:final value):
                                  await context.pushNamed(
                                    ImportWatchOnlyWalletRoutes.import.name,
                                    extra: value,
                                  );
                                case Err(:final failure):
                                  BullSnackBar.show(
                                    context,
                                    message: failure.toTranslated(context),
                                  );
                              }
                            },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
