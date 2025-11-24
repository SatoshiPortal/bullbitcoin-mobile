import 'dart:io' show Platform;

import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/tab_menu_vertical_button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitbox/ui/bitbox_router.dart';
import 'package:bb_mobile/features/bitbox/ui/screens/bitbox_action_screen.dart';
import 'package:bb_mobile/features/import_coldcard_q/router.dart';
import 'package:bb_mobile/features/import_qr_device/router.dart';
import 'package:bb_mobile/features/ledger/ui/ledger_router.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ConnectHardwareWalletPage extends StatelessWidget {
  const ConnectHardwareWalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.connectHardwareWalletTitle)),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const Gap(32),
            BBText(
              context.loc.connectHardwareWalletDescription,
              style: context.font.bodyLarge,
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            const Gap(48),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TabMenuVerticalButton(
                      title: context.loc.connectHardwareWalletColdcardQ,
                      onTap:
                          () => context.pushNamed(
                            ImportColdcardQRoute.importColdcardQ.name,
                          ),
                    ),
                    const Gap(16),
                    TabMenuVerticalButton(
                      title: context.loc.connectHardwareWalletLedger,
                      onTap:
                          () =>
                              context.pushNamed(LedgerRoute.importLedger.name),
                    ),
                    const Gap(16),
                    if (Platform.isAndroid) ...[
                      TabMenuVerticalButton(
                        title: 'BitBox02',
                        onTap: () => context.pushNamed(
                          BitBoxRoute.importBitBox.name,
                          extra: const BitBoxRouteParams(
                            requestedDeviceType: SignerDeviceEntity.bitbox02,
                          ),
                        ),
                      ),
                      const Gap(16),
                    ],
                    TabMenuVerticalButton(
                      title: context.loc.connectHardwareWalletJade,
                      onTap:
                          () => context.pushNamed(
                            ImportQrDeviceRoute.importJade.name,
                          ),
                    ),
                    const Gap(16),
                    TabMenuVerticalButton(
                      title: context.loc.connectHardwareWalletKeystone,
                      onTap:
                          () => context.pushNamed(
                            ImportQrDeviceRoute.importKeystone.name,
                          ),
                    ),
                    const Gap(16),
                    TabMenuVerticalButton(
                      title: context.loc.connectHardwareWalletKrux,
                      onTap:
                          () => context.pushNamed(
                            ImportQrDeviceRoute.importKrux.name,
                          ),
                    ),
                    const Gap(16),
                    TabMenuVerticalButton(
                      title: context.loc.connectHardwareWalletPassport,
                      onTap:
                          () => context.pushNamed(
                            ImportQrDeviceRoute.importPassport.name,
                          ),
                    ),
                    const Gap(16),
                    TabMenuVerticalButton(
                      title: context.loc.connectHardwareWalletSeedSigner,
                      onTap:
                          () => context.pushNamed(
                            ImportQrDeviceRoute.importSeedSigner.name,
                          ),
                    ),
                    const Gap(32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
