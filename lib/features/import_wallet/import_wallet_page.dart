import 'package:bb_mobile/core/widgets/tab_menu_vertical_button.dart';
import 'package:bb_mobile/features/import_coldcard_q/router.dart';
import 'package:bb_mobile/features/import_mnemonic/router.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_router.dart';
import 'package:flutter/material.dart';
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
              const Gap(24),
              TabMenuVerticalButton(
                title: 'Recover mnemonic',
                onTap:
                    () => context.pushNamed(
                      ImportMnemonicRoute.importMnemonicHome.name,
                    ),
              ),
              const Gap(16),
              TabMenuVerticalButton(
                title: 'Connect Coldcard Q',
                onTap:
                    () => context.pushNamed(
                      ImportColdcardQRoute.importColdcardQ.name,
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
            ],
          ),
        ),
      ),
    );
  }
}
