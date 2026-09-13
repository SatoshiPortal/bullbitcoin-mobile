import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/progress_screen.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/presentation/recoverbull_failure_l10n.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/view_vault_key_page.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class DeriveVaultKeyPage extends StatefulWidget {
  const DeriveVaultKeyPage({super.key});

  @override
  State<DeriveVaultKeyPage> createState() => _DeriveVaultKeyPageState();
}

class _DeriveVaultKeyPageState extends State<DeriveVaultKeyPage> {
  bool _openingKey = false;

  @override
  void initState() {
    super.initState();
    context.read<RecoverBullBloc>().add(const OnVaultKeyDerivation());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.loc.backupSettingsViewVaultKey)),
    body: SafeArea(
      child: BlocConsumer<RecoverBullBloc, RecoverBullState>(
        listener: (context, state) {
          if (state.vaultKey != null && !_openingKey) {
            _openingKey = true;
            ViewVaultKeyPage.showVerified(context);
          }
        },
        builder: (context, state) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (state.failure case final failure?) ...[
              BBText(
                failure.toTranslated(context),
                style: context.font.bodyMedium,
              ),
              const Gap(24),
              BBButton.big(
                label: context.loc.tryAgainButton,
                bgColor: context.appColors.onSurface,
                textColor: context.appColors.surface,
                onPressed: () => context.read<RecoverBullBloc>().add(
                  const OnVaultKeyDerivation(),
                ),
              ),
            ] else
              ProgressScreen(
                isLoading: true,
                title: context.loc.recoverbullKeyChecking,
                description: context.loc.recoverbullKeyCheckingDescription,
              ),
            const Gap(24),
            BBButton.big(
              label: state.failure == null
                  ? context.loc.cancelButton
                  : context.loc.recoverbullKeyOtherMethod,
              bgColor: context.appColors.transparent,
              textColor: context.appColors.onSurface,
              outlined: true,
              onPressed: () => context.pop(),
            ),
          ],
        ),
      ),
    ),
  );
}
