import '../../domain/entities/encrypted_vault.dart';
import '../../domain/entities/vault_provider.dart';
import '../../router/recoverbull_router.dart';
import '../widgets/key_server_status_widget.dart';
import '../../google_drive/recoverbull_google_drive_router.dart';
import '../../router/flow_type.dart';
import '../../l10n/context_localizations.dart';
import 'package:bull_ui/bull_ui.dart';
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
    return BullScaffold(
      appBar: BullTopBar.appBar(
        title: context.loc.recoverbullVaultSelected,
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
            BullText(
              context.loc.recoverbullVaultImportedSuccess,
              textAlign: .left,
              style: context.bullText.bodySmall,
            ),
            const Gap(BullSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: context.bull.onSurface),
                borderRadius: BorderRadius.circular(BullRadius.xs),
              ),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  BullText(vault.id, style: context.bullText.headlineMedium),
                  const Gap(BullSpacing.md),
                  BullText(
                    DateFormat(
                      "yyyy-MMM-dd, HH:mm:ss",
                    ).format(vault.createdAt.toLocal()),
                    style: context.bullText.headlineMedium,
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (provider == VaultProvider.googleDrive) ...[
              BullButton.big(
                label: context.loc.recoverbullSeeMoreVaults,
                onPressed: () => context.pushNamed(
                  RecoverBullGoogleDriveRoute.recoverbullListDriveVaults.name,
                  extra: RecoverBullFlowsExtra(flow: flow, vault: vault),
                ),
                bgColor: context.bull.transparent,
                textColor: context.bull.onSurface,
                outlined: true,
              ),
              const Gap(BullSpacing.md),
            ],
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height * 0.05,
              ),
              child: BullButton.big(
                label: context.loc.recoverbullDecryptVault,
                onPressed: () => context.pushNamed(
                  RecoverBullRoute.recoverbullFlows.name,
                  extra: RecoverBullFlowsExtra(flow: flow, vault: vault),
                ),
                bgColor: context.bull.onSurface,
                textColor: context.bull.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
