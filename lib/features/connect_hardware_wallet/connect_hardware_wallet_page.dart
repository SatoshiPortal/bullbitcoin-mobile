import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/tab_menu_vertical_button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
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
      appBar: AppBar(title: const Text('Connect Hardware Wallet')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const Gap(32),
            BBText(
              'Choose the hardware wallet you would like to connect',
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
                      title: 'Coldcard Q',
                      onTap:
                          () => context.pushNamed(
                            ImportColdcardQRoute.importColdcardQ.name,
                          ),
                    ),
                    const Gap(16),
                    TabMenuVerticalButton(
                      title: 'Ledger',
                      onTap:
                          () =>
                              context.pushNamed(LedgerRoute.importLedger.name),
                    ),
                    const Gap(16),
                    TabMenuVerticalButton(
                      title: 'Blockstream Jade',
                      onTap:
                          () => context.pushNamed(
                            ImportQrDeviceRoute.importJade.name,
                          ),
                    ),
                    const Gap(16),
                    TabMenuVerticalButton(
                      title: 'Keystone',
                      onTap:
                          () => context.pushNamed(
                            ImportQrDeviceRoute.importKeystone.name,
                          ),
                    ),
                    const Gap(16),
                    TabMenuVerticalButton(
                      title: 'Krux',
                      onTap:
                          () => context.pushNamed(
                            ImportQrDeviceRoute.importKrux.name,
                          ),
                    ),
                    const Gap(16),
                    TabMenuVerticalButton(
                      title: 'Foundation Passport',
                      onTap:
                          () => context.pushNamed(
                            ImportQrDeviceRoute.importPassport.name,
                          ),
                    ),
                    const Gap(16),
                    TabMenuVerticalButton(
                      title: 'SeedSigner',
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
