import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/tab_menu_vertical_button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/connect_hardware_wallet/router.dart';
import 'package:bb_mobile/features/import_coldcard_q/router.dart';
import 'package:bb_mobile/features/import_mnemonic/router.dart';
import 'package:bb_mobile/features/import_qr_device/router.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ImportWalletPage extends StatelessWidget {
  const ImportWalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a new wallet')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Gap(16),
              if (context.read<SettingsCubit>().state.isSuperuser ?? false) ...[
                TabMenuVerticalButton(
                  title: 'Connect Hardware Wallet',
                  onTap:
                      () => context.pushNamed(
                        ConnectHardwareWalletRoute.connectHardwareWallet.name,
                      ),
                ),
              ] else ...[
                BBText('Generic wallets', style: context.font.titleMedium),
                const Gap(12),
                TabMenuVerticalButton(
                  title: 'Import Mnemonic',
                  onTap:
                      () => context.pushNamed(
                        ImportMnemonicRoute.importMnemonicHome.name,
                      ),
                ),
                const Gap(16),
                TabMenuVerticalButton(
                  title: 'Import watch-only',
                  onTap:
                      () => context.pushNamed(
                        ImportWatchOnlyWalletRoutes.import.name,
                      ),
                ),
                const Gap(24),
                BBText('Hardware wallets', style: context.font.titleMedium),
                const Gap(12),
                TabMenuVerticalButton(
                  title: 'Coldcard Q',
                  onTap:
                      () => context.pushNamed(
                        ImportColdcardQRoute.importColdcardQ.name,
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
                const Gap(16),
                TabMenuVerticalButton(
                  title: 'Specter',
                  onTap:
                      () => context.pushNamed(
                        ImportQrDeviceRoute.importSpecter.name,
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
              ],
            ],
          ),
        ),
      ),
    );
  }
}
