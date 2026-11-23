import 'package:signers/signers.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/import_watch_only_failure_l10n.dart';
import 'package:primitives/primitives.dart' show Err, Ok;
import 'package:bull_ui/bull_ui.dart' show BullSnackBar;
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:primitives/primitives.dart' show NetworkCapability;

import 'dart:io' show Platform;

import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/import_coldcard/router.dart';
import 'package:bb_mobile/features/import_mnemonic/router.dart';
import 'package:wallet_import/wallet_import.dart';
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
                onTap: () => ImportNavigation.openWatchOnly(context),
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
                      onTap: () => ImportNavigation.openQrInstructions(
                        context,
                        QrImportDevice.seedsigner,
                      ),
                    ),
                    const Gap(16),
                    BullTabMenuVerticalButton(
                      title: context.loc.importWalletSpecter,
                      onTap: () => ImportNavigation.openQrInstructions(
                        context,
                        QrImportDevice.specter,
                      ),
                    ),
                    const Gap(16),
                    BullTabMenuVerticalButton(
                      title: context.loc.importWalletKrux,
                      onTap: () => ImportNavigation.openQrInstructions(
                        context,
                        QrImportDevice.krux,
                      ),
                    ),
                    const Gap(16),
                    BullTabMenuVerticalButton(
                      title: context.loc.importWalletJade,
                      onTap: () => ImportNavigation.openQrInstructions(
                        context,
                        QrImportDevice.jade,
                      ),
                    ),
                    const Gap(16),
                    BullTabMenuVerticalButton(
                      title: context.loc.importWalletPassport,
                      onTap: () => ImportNavigation.openQrInstructions(
                        context,
                        QrImportDevice.passport,
                      ),
                    ),
                    const Gap(16),
                    BullTabMenuVerticalButton(
                      title: context.loc.importWalletKeystone,
                      onTap: () => ImportNavigation.openQrInstructions(
                        context,
                        QrImportDevice.keystone,
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
                              await _reviewAccount(
                                context,
                                account,
                                context.loc.ledgerDefaultWalletLabel,
                              );
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
                              await _reviewAccount(
                                context,
                                account,
                                context.loc.bitboxScreenDefaultWalletLabel,
                              );
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

  Future<void> _reviewAccount(
    BuildContext context,
    SignerAccount account,
    String label,
  ) async {
    switch (WatchOnlyInput.fromSignerAccount(account)) {
      case Ok(:final value):
        await ImportNavigation.openWatchOnly(
          context,
          input: value,
          label: label,
        );
      case Err(:final failure):
        final legacyFailure = failure is WatchOnlyNetworkMismatchFailure
            ? const NetworkMismatchFailure()
            : const InvalidFormatFailure();
        BullSnackBar.show(
          context,
          message: legacyFailure.toTranslated(context),
        );
    }
  }
}
