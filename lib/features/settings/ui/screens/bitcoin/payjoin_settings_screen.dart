import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/switch/bb_switch.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/tiles/bordered_tappable_tile.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/public/payjoin_disclaimer_dialog.dart';
import 'package:bb_mobile/features/settings/presentation/settings_failure_l10n.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

/// Payjoin settings (product decision 2026-07-25/26): deliberately minimal —
/// the enable toggle, a row that re-opens the one-time disclaimer pop-up,
/// and a row navigating to the advanced settings page (minimum amount,
/// session expiry, servers). The disclaimer shows automatically exactly once
/// the first time payjoin is enabled (see [PayjoinDisclaimerDialog]).
class PayjoinSettingsScreen extends StatefulWidget {
  const PayjoinSettingsScreen({super.key});

  @override
  State<PayjoinSettingsScreen> createState() => _PayjoinSettingsScreenState();
}

class _PayjoinSettingsScreenState extends State<PayjoinSettingsScreen> {
  bool _updating = false;

  Future<void> _setPayjoinEnabled(bool enabled) async {
    if (_updating) return;
    setState(() => _updating = true);

    final cubit = context.read<SettingsCubit>();
    final result = await cubit.togglePayjoinEnabled(
      enabled,
      requestConsent: () async {
        if (!mounted) return false;
        return PayjoinDisclaimerDialog.show(context);
      },
    );
    result.fold((_) {}, (failure) {
      log.warning(
        'Failed to update Payjoin from settings: ${failure.logMessage}',
      );
      if (mounted) {
        SnackBarUtils.showSnackBar(context, failure.toTranslated(context));
      }
    });

    if (mounted) setState(() => _updating = false);
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = context.select(
      (SettingsCubit cubit) => cubit.state.isPayjoinEnabled,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.settingsPayjoinTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: BBText(
                      context.loc.settingsPayjoinEnabledLabel,
                      style: context.font.bodyLarge,
                    ),
                  ),
                  BBSwitch(
                    value: isEnabled,
                    onChanged: _updating ? null : _setPayjoinEnabled,
                  ),
                ],
              ),
              const Gap(16),
              BorderedTappableTile(
                onTap: () async {
                  await PayjoinDisclaimerDialog.show(context);
                },
                child: Row(
                  children: [
                    Expanded(
                      child: BBText(
                        context.loc.settingsPayjoinDisclaimerRowLabel,
                        style: context.font.bodyLarge,
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
              if (isEnabled) ...[
                const Gap(16),
                BorderedTappableTile(
                  onTap: () => context.pushNamed(
                    SettingsRoute.payjoinAdvancedSettings.name,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: BBText(
                          context.loc.settingsPayjoinAdvancedTitle,
                          style: context.font.bodyLarge,
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
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
