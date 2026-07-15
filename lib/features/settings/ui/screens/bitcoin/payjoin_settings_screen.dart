import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart' show PayjoinConstants;
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

/// Dedicated payjoin settings screen: enable/disable toggle, minimum
/// receive amount, session expiry, and a read-only view of the directory
/// and OHTTP relays used. See PAYJOIN_SETTINGS_PLAN.md §9.
class PayjoinSettingsScreen extends StatefulWidget {
  const PayjoinSettingsScreen({super.key});

  @override
  State<PayjoinSettingsScreen> createState() => _PayjoinSettingsScreenState();
}

class _PayjoinSettingsScreenState extends State<PayjoinSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _minAmountController;
  late final TextEditingController _expireAfterSecController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsCubit>().state.storedSettings;
    final initialMinAmount = settings != null && settings.isPayjoinEnabled
        ? settings.payjoinMinAmountSat
        : PayjoinConstants.defaultMinAmountSat;
    final initialExpireAfterSec =
        settings?.payjoinExpireAfterSec ??
        PayjoinConstants.defaultExpireAfterSec;
    _minAmountController = TextEditingController(
      text: initialMinAmount.toString(),
    );
    _expireAfterSecController = TextEditingController(
      text: initialExpireAfterSec.toString(),
    );
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _expireAfterSecController.dispose();
    super.dispose();
  }

  String? _validateMinAmount(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    // Strictly below the ceiling: only the enabled/disabled toggle is
    // allowed to write the sentinel value itself (see
    // SettingsEntity.isPayjoinEnabled).
    if (parsed == null ||
        parsed < PayjoinConstants.minMinAmountSat ||
        parsed >= PayjoinConstants.maxMinAmountSat) {
      return context.loc.settingsPayjoinMinAmountRangeError(
        PayjoinConstants.minMinAmountSat,
        PayjoinConstants.maxMinAmountSat - 1,
      );
    }
    return null;
  }

  String? _validateExpireAfterSec(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null ||
        parsed < PayjoinConstants.minExpireAfterSec ||
        parsed > PayjoinConstants.maxExpireAfterSec) {
      return context.loc.settingsPayjoinExpireRangeError(
        PayjoinConstants.minExpireAfterSec,
        PayjoinConstants.maxExpireAfterSec,
      );
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final cubit = context.read<SettingsCubit>();
    await Future.wait([
      cubit.setPayjoinMinAmount(int.parse(_minAmountController.text.trim())),
      cubit.setPayjoinExpireAfterSec(
        int.parse(_expireAfterSecController.text.trim()),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = context.select(
      (SettingsCubit cubit) =>
          cubit.state.storedSettings?.isPayjoinEnabled ?? false,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.settingsPayjoinTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoCard(
                  description: context.loc.settingsPayjoinExplanation,
                  tagColor: context.appColors.secondary,
                  bgColor: context.appColors.onSecondary,
                ),
                const Gap(24),
                Row(
                  children: [
                    Expanded(
                      child: BBText(
                        context.loc.settingsPayjoinEnabledLabel,
                        style: context.font.bodyLarge,
                      ),
                    ),
                    Switch(
                      value: isEnabled,
                      onChanged: (value) {
                        context.read<SettingsCubit>().setPayjoinEnabled(value);
                      },
                    ),
                  ],
                ),
                if (isEnabled) ...[
                  const Gap(24),
                  Text(
                    context.loc.settingsPayjoinMinAmountTitle,
                    style: context.font.headlineSmall,
                  ),
                  const Gap(4),
                  Text(
                    context.loc.settingsPayjoinMinAmountDescription,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                  const Gap(8),
                  TextFormField(
                    controller: _minAmountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      suffixText: context.loc.sendSats,
                      border: const OutlineInputBorder(),
                    ),
                    validator: _validateMinAmount,
                    onFieldSubmitted: (_) => _save(),
                  ),
                  const Gap(24),
                  Text(
                    context.loc.settingsPayjoinExpireTitle,
                    style: context.font.headlineSmall,
                  ),
                  const Gap(4),
                  Text(
                    context.loc.settingsPayjoinExpireDescription,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                  const Gap(8),
                  TextFormField(
                    controller: _expireAfterSecController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateExpireAfterSec,
                    onFieldSubmitted: (_) => _save(),
                  ),
                  const Gap(24),
                  BBButton.big(
                    label: context.loc.save,
                    onPressed: _save,
                    bgColor: context.appColors.secondary,
                    textColor: context.appColors.onSecondary,
                  ),
                ],
                const Gap(32),
                Text(
                  context.loc.settingsPayjoinServersTitle,
                  style: context.font.headlineSmall,
                ),
                const Gap(8),
                Text(
                  context.loc.settingsPayjoinDirectoryLabel,
                  style: context.font.bodySmall?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
                const Gap(2),
                Text(
                  PayjoinConstants.directoryUrl,
                  style: context.font.bodyMedium,
                ),
                const Gap(16),
                Text(
                  context.loc.settingsPayjoinRelaysLabel,
                  style: context.font.bodySmall?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
                const Gap(2),
                for (final url in PayjoinConstants.ohttpRelayUrlsBase)
                  Text(url, style: context.font.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
