import 'package:bb_mobile/core/recoverbull/domain/entity/vault_provider.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/backup_option_card.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/presentation/recoverbull_failure_l10n.dart';
import 'package:bb_mobile/features/recoverbull/router.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ViewBackupKeyPage extends StatefulWidget {
  const ViewBackupKeyPage({super.key});

  @override
  State<ViewBackupKeyPage> createState() => _ViewBackupKeyPageState();
}

class _ViewBackupKeyPageState extends State<ViewBackupKeyPage> {
  bool? _local;

  void _chooseMethod(bool local) {
    context.read<RecoverBullBloc>().add(const OnClearError());
    setState(() => _local = local);
  }

  void _pickFile() => context.read<RecoverBullBloc>().add(
    const OnVaultSelection(provider: VaultProvider.customLocation),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.loc.backupSettingsViewVaultKey),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (_local == null) {
            context.pop();
          } else {
            setState(() => _local = null);
          }
        },
      ),
    ),
    body: SafeArea(
      child: BlocBuilder<RecoverBullBloc, RecoverBullState>(
        builder: (context, state) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (_local == null) ...[
              BBText(
                context.loc.recoverbullKeyChooseMethod,
                style: context.font.bodyMedium,
              ),
              const Gap(24),
              BackupOptionCard(
                icon: Image.asset('assets/misc/custom_location.png'),
                title: context.loc.recoverbullKeyFromFile,
                description: context.loc.recoverbullKeyFromFileDescription,
                onTap: () => _chooseMethod(true),
              ),
              const Gap(16),
              BackupOptionCard(
                icon: Image.asset('assets/misc/encrypted_vault.png'),
                title: context.loc.recoverbullKeyFromServer,
                description: context.loc.recoverbullKeyFromServerDescription,
                onTap: () => _chooseMethod(false),
              ),
              const Gap(24),
              BBText(
                context.loc.recoverbullKeyFileRequired,
                style: context.font.bodySmall,
              ),
            ] else ...[
              BBText(
                _local!
                    ? context.loc.recoverbullKeyFromFile
                    : context.loc.recoverbullKeyFromServer,
                style: context.font.headlineMedium,
              ),
              const Gap(16),
              BBText(
                _local!
                    ? context.loc.recoverbullKeyLocalInstructions
                    : context.loc.recoverbullKeyServerInstructions,
                style: context.font.bodyMedium,
              ),
              const Gap(24),
              if (state.vault case final vault?) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.appColors.border),
                  ),
                  child: BBText(vault.filename, style: context.font.bodyMedium),
                ),
                const Gap(16),
              ],
              if (state.failure case final failure?) ...[
                BBText(
                  failure.toTranslated(context),
                  style: context.font.bodyMedium,
                  color: context.appColors.error,
                ),
                const Gap(16),
              ],
              if (state.isLoading)
                const FadingLinearProgress(trigger: true)
              else ...[
                BBButton.big(
                  label: state.vault == null
                      ? context.loc.recoverbullKeyChooseFile
                      : context.loc.recoverbullKeyChooseAnotherFile,
                  onPressed: _pickFile,
                  outlined: state.vault != null,
                  bgColor: state.vault == null
                      ? context.appColors.onSurface
                      : context.appColors.transparent,
                  textColor: state.vault == null
                      ? context.appColors.surface
                      : context.appColors.onSurface,
                ),
                if (state.vault != null) ...[
                  const Gap(16),
                  BBButton.big(
                    label: _local!
                        ? context.loc.recoverbullKeyUnlockAndDerive
                        : context.loc.recoverbullContinue,
                    bgColor: context.appColors.onSurface,
                    textColor: context.appColors.surface,
                    onPressed: () => context.pushNamed(
                      RecoverBullRoute.recoverbullFlows.name,
                      extra: RecoverBullFlowsExtra(
                        flow: RecoverBullFlow.viewVaultKey,
                        vault: state.vault,
                        deriveKeyLocally: _local!,
                      ),
                    ),
                  ),
                ],
                const Gap(16),
                BBButton.big(
                  label: _local!
                      ? context.loc.recoverbullKeyUseServer
                      : context.loc.recoverbullKeyUseLocal,
                  onPressed: () => _chooseMethod(!_local!),
                  outlined: true,
                  bgColor: context.appColors.transparent,
                  textColor: context.appColors.onSurface,
                ),
              ],
            ],
          ],
        ),
      ),
    ),
  );
}
