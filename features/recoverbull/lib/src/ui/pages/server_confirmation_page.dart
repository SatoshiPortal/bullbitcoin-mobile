import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/recoverbull_server_url.dart';
import '../../domain/usecases/manage_backup_settings_usecase.dart';
import '../../l10n/context_localizations.dart';
import '../../presentation/recoverbull_failure_l10n.dart';
import '../../presentation/vault_flow_cubit.dart';
import '../recoverbull_flow_navigator.dart';
import 'connecting_page.dart';
import 'vault_key_instead.dart';

final recoverBullWebsite = Uri.parse('https://recoverbull.com/');

Future<void> openRecoverBullWebsite() async {
  if (await canLaunchUrl(recoverBullWebsite)) {
    await launchUrl(recoverBullWebsite, mode: LaunchMode.externalApplication);
  }
}

/// Asks for consent to reach the key server before any connection is made.
class ServerConfirmationPage extends StatelessWidget {
  const ServerConfirmationPage({super.key});

  Future<void> _accept(BuildContext context) async {
    final cubit = context.read<VaultFlowCubit>();
    final server = cubit.state.settings?.server;
    if (server == null) return;
    await cubit.settings(AcceptBackupServer(server));
    if (!context.mounted) return;
    if (cubit.state.settings?.permissionGranted != true) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const ConnectingPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VaultFlowCubit, VaultFlowState>(
      builder: (context, state) {
        final server =
            state.settings?.server.toString() ?? recoverBullDefaultServerUrl;
        final isDefault = server == recoverBullDefaultServerUrl;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: () => recoverBullBack(context),
              icon: const Icon(Icons.arrow_back),
            ),
            title: BullText(
              context.loc.recoverbullServerConfirmTitle,
              style: context.bullText.headlineMedium,
              color: context.bull.onSurface,
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                const Gap(24),
                Icon(
                  isDefault ? Icons.verified_user : Icons.warning_amber,
                  size: 64,
                  color: isDefault
                      ? context.bull.primary
                      : context.bull.tertiary,
                ),
                const Gap(32),
                BullText(
                  isDefault
                      ? context.loc.recoverbullServerUsingDefault
                      : context.loc.recoverbullServerUsingCustom,
                  style: context.bullText.headlineMedium,
                  textAlign: .center,
                ),
                const Gap(16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.bull.cardBackground,
                    borderRadius: BorderRadius.circular(
                      context.bullShapes.card,
                    ),
                    border: Border.all(color: context.bull.border),
                  ),
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      BullText(
                        context.loc.recoverbullServerUrlLabel,
                        style: context.bullText.labelSmall?.copyWith(
                          color: context.bull.textMuted,
                        ),
                      ),
                      const Gap(8),
                      BullText(
                        server,
                        style: context.bullText.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(24),
                if (!isDefault) ...[
                  BullInfoCard(
                    description: context.loc.recoverbullServerCustomWarning,
                    tagColor: context.bull.error,
                    bgColor: context.bull.errorContainer,
                  ),
                  const Gap(24),
                ],
                BullText(
                  context.loc.recoverbullServerTorNotice,
                  style: context.bullText.bodyMedium?.copyWith(
                    color: context.bull.textMuted,
                  ),
                  textAlign: .center,
                ),
                if (state.failure case final failure?) ...[
                  const Gap(16),
                  BullText(
                    failure.toTranslated(context),
                    style: context.bullText.bodyMedium?.copyWith(
                      color: context.bull.error,
                    ),
                    textAlign: .center,
                  ),
                ],
                const Spacer(),
                BullButton.big(
                  label: context.loc.recoverbullContinue,
                  disabled: state.busy || state.settings == null,
                  onPressed: () => _accept(context),
                  bgColor: context.bull.onSurface,
                  textColor: context.bull.surface,
                ),
                const Gap(8),
                const VaultKeyInsteadButton(),
                const Gap(8),
                GestureDetector(
                  onTap: openRecoverBullWebsite,
                  child: Row(
                    mainAxisAlignment: .center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: context.bull.primary,
                      ),
                      const Gap(8),
                      BullText(
                        context.loc.recoverbullLearnMore,
                        style: context.bullText.bodyMedium,
                        color: context.bull.primary,
                      ),
                    ],
                  ),
                ),
                const Gap(24),
              ],
            ),
          ),
        );
      },
    );
  }
}
