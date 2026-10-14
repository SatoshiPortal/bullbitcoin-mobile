import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/public/payjoin_disclaimer_dialog.dart';
import 'package:bb_mobile/features/settings/presentation/settings_failure_l10n.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_payjoin/bull_payjoin.dart' show PayjoinAction;
import 'package:bull_ui/bull_ui.dart' show BullBorderedTile, BullSwitch, Gap;
import 'package:go_router/go_router.dart';

/// Payjoin settings: one switch per action, payments with other users
/// (off by default) and exchange orders (on by default), a row that re-opens
/// the one-time disclaimer pop-up, and a row navigating to the advanced
/// settings page (minimum amount, session expiry, servers). The disclaimer
/// shows automatically the first time receiving from users is turned on (see
/// [PayjoinDisclaimerDialog]).
class PayjoinSettingsScreen extends StatefulWidget {
  const PayjoinSettingsScreen({super.key});

  @override
  State<PayjoinSettingsScreen> createState() => _PayjoinSettingsScreenState();
}

class _PayjoinSettingsScreenState extends State<PayjoinSettingsScreen> {
  bool _updating = false;

  Future<void> _setPayjoinEnabled(PayjoinAction action, bool enabled) async {
    if (_updating) return;
    setState(() => _updating = true);

    final cubit = context.read<SettingsCubit>();
    final result = await cubit.togglePayjoinEnabled(
      action,
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

  Widget _switchRow(String label, PayjoinAction action) {
    final isEnabled = context.select(
      (SettingsCubit cubit) => cubit.state.isPayjoinEnabled(action),
    );
    final isLoaded = context.select(
      (SettingsCubit cubit) => cubit.state.payjoinPolicy != null,
    );
    return Row(
      children: [
        Expanded(child: BBText(label, style: context.font.bodyLarge)),
        BullSwitch(
          value: isEnabled,
          onChanged: _updating || !isLoaded
              ? null
              : (enabled) => _setPayjoinEnabled(action, enabled),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) => BBText(
    title,
    style: context.font.titleSmall,
    color: context.appColors.secondary,
  );

  @override
  Widget build(BuildContext context) {
    final isAnyEnabled = context.select(
      (SettingsCubit cubit) => cubit.state.isAnyPayjoinEnabled,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.settingsPayjoinTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle(context.loc.settingsPayjoinUsersSection),
              const Gap(8),
              _switchRow(
                context.loc.settingsPayjoinSendLabel,
                PayjoinAction.send,
              ),
              _switchRow(
                context.loc.settingsPayjoinReceiveLabel,
                PayjoinAction.receive,
              ),
              const Gap(24),
              _sectionTitle(context.loc.settingsPayjoinExchangeSection),
              const Gap(8),
              _switchRow(
                context.loc.settingsPayjoinBuyLabel,
                PayjoinAction.buy,
              ),
              _switchRow(
                context.loc.settingsPayjoinSellLabel,
                PayjoinAction.sell,
              ),
              const Gap(24),
              BullBorderedTile(
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
              if (isAnyEnabled) ...[
                const Gap(16),
                BullBorderedTile(
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
