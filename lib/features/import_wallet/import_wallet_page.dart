import 'dart:io';

import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/tab_menu_vertical_button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitbox/ui/bitbox_router.dart';
import 'package:bb_mobile/features/bitbox/ui/screens/bitbox_action_screen.dart';
import 'package:bb_mobile/features/import_coldcard_q/router.dart';
import 'package:bb_mobile/features/import_mnemonic/router.dart';
import 'package:bb_mobile/features/import_qr_device/router.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_router.dart';
import 'package:bb_mobile/features/ledger/ui/ledger_router.dart';
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
      appBar: AppBar(title: Text(context.loc.importWalletTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              const Gap(16),
              BBText(
                context.loc.importWalletSectionGeneric,
                style: context.font.titleMedium,
              ),
              const Gap(12),
              TabMenuVerticalButton(
                title: context.loc.importWalletImportMnemonic,
                onTap: () => context.pushNamed(
                  ImportMnemonicRoute.importMnemonicHome.name,
                ),
              ),
              const Gap(16),
              TabMenuVerticalButton(
                title: context.loc.importWalletImportWatchOnly,
                onTap: () =>
                    context.pushNamed(ImportWatchOnlyWalletRoutes.import.name),
              ),
              const Gap(24),
              BBText(
                context.loc.importWalletSectionHardware,
                style: context.font.titleMedium,
              ),
              const Gap(12),
              TabMenuVerticalButton(
                title: context.loc.importWalletColdcardQ,
                onTap: () => context.pushNamed(
                  ImportColdcardQRoute.importColdcardQ.name,
                ),
              ),
              const Gap(16),
              TabMenuVerticalButton(
                title: context.loc.importWalletSeedSigner,
                onTap: () => context.pushNamed(
                  ImportQrDeviceRoute.importSeedSigner.name,
                ),
              ),
              const Gap(16),
              TabMenuVerticalButton(
                title: context.loc.importWalletSpecter,
                onTap: () =>
                    context.pushNamed(ImportQrDeviceRoute.importSpecter.name),
              ),
              const Gap(16),
              TabMenuVerticalButton(
                title: context.loc.importWalletKrux,
                onTap: () =>
                    context.pushNamed(ImportQrDeviceRoute.importKrux.name),
              ),
              const Gap(16),
              TabMenuVerticalButton(
                title: context.loc.importWalletJade,
                onTap: () =>
                    context.pushNamed(ImportQrDeviceRoute.importJade.name),
              ),
              const Gap(16),
              TabMenuVerticalButton(
                title: context.loc.importWalletPassport,
                onTap: () =>
                    context.pushNamed(ImportQrDeviceRoute.importPassport.name),
              ),
              const Gap(16),
              TabMenuVerticalButton(
                title: context.loc.importWalletKeystone,
                onTap: () =>
                    context.pushNamed(ImportQrDeviceRoute.importKeystone.name),
              ),
              const Gap(16),
              TabMenuVerticalButton(
                title: context.loc.importWalletLedger,
                onTap: () => context.pushNamed(LedgerRoute.importLedger.name),
              ),
              if (context.read<SettingsCubit>().state.isSuperuser ?? false) ...[
                const Gap(16),
                TabMenuVerticalButton(
                  title: 'BitBox',
                  onTap: () => Platform.isAndroid
                      ? context.pushNamed(
                          BitBoxRoute.importBitBox.name,
                          extra: const BitBoxRouteParams(
                            requestedDeviceType: SignerDeviceEntity.bitbox02,
                          ),
                        )
                      : SnackBarUtils.showSnackBar(
                          context,
                          'BitBox is only supported on Android',
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
