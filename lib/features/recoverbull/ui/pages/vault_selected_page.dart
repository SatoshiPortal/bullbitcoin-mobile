import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/vault_provider.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/router.dart';
import 'package:bb_mobile/features/recoverbull/ui/widgets/key_server_status_widget.dart';
import 'package:bb_mobile/features/recoverbull_google_drive/router.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class VaultSelectedPage extends StatelessWidget {
  final VaultProvider provider;
  final EncryptedVault vault;
  final RecoverBullFlow flow;

  const VaultSelectedPage({
    super.key,
    required this.provider,
    required this.vault,
    required this.flow,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.recoverbullVaultSelected),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: KeyServerStatusWidget(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            BBText(
              context.loc.recoverbullVaultImportedSuccess,
              textAlign: TextAlign.left,
              style: context.font.bodySmall,
            ),
            const Gap(16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: context.appColors.onSurface),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BBText(vault.id, style: context.font.headlineMedium),
                  const Gap(16),
                  BBText(
                    DateFormat(
                      "yyyy-MMM-dd, HH:mm:ss",
                    ).format(vault.createdAt.toLocal()),
                    style: context.font.headlineMedium,
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (provider == VaultProvider.googleDrive) ...[
              BBButton.big(
                label: context.loc.recoverbullSeeMoreVaults,
                onPressed:
                    () => context.pushNamed(
                      RecoverBullGoogleDriveRoute.listDriveVaults.name,
                      extra: flow,
                    ),
                bgColor: context.appColors.transparent,
                textColor: context.appColors.onSurface,
                outlined: true,
              ),
              const Gap(16),
            ],
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height * 0.05,
              ),
              child: BBButton.big(
                label: context.loc.recoverbullDecryptVault,
                onPressed:
                    () => context.pushNamed(
                      RecoverBullRoute.recoverbullFlows.name,
                      extra: RecoverBullFlowsExtra(flow: flow, vault: vault),
                    ),
                bgColor: context.appColors.onSurface,
                textColor: context.appColors.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
