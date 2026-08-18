import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class ExchangeAppSettingsScreen extends StatefulWidget {
  const ExchangeAppSettingsScreen({super.key});

  @override
  State<ExchangeAppSettingsScreen> createState() =>
      _ExchangeAppSettingsScreenState();
}

class _ExchangeAppSettingsScreenState extends State<ExchangeAppSettingsScreen> {
  @override
  initState() {
    super.initState();
    context.read<ExchangeCubit>().fetchUserSummary(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.select((ExchangeCubit cubit) => cubit.state);
    final userSummary = state.userSummary;
    final selectedLanguage = state.selectedLanguage ?? userSummary?.language;
    final selectedCurrency = state.selectedCurrency ?? userSummary?.currency;

    final hasUnsetValues = selectedLanguage == null || selectedCurrency == null;
    return BlocListener<ExchangeCubit, ExchangeState>(
      listenWhen: (previous, current) => previous.isSaving && !current.isSaving,
      listener: (context, state) {
        SnackBarUtils.showSnackBar(
          context,
          context.loc.exchangeAppSettingsSaveSuccessMessage,
        );
      },
      child: BullPage(
        topBar: BullTopBar(
          title: context.loc.settingsAppSettingsTitle,
          onBack: () => context.pop(),
        ),
        padding: const EdgeInsets.all(BullSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdownField(
              context,
              context.loc.exchangeAppSettingsPreferredLanguageLabel,
              selectedLanguage,
              ExchangeLanguage.values.map((lang) => lang.code).toList(),
              ExchangeLanguage.values.map((lang) => lang.displayName).toList(),
              (value) {
                context.read<ExchangeCubit>().updateSelectedLanguage(value);
              },
            ),
            const SizedBox(height: 24),
            _buildDropdownField(
              context,
              context.loc.exchangeAppSettingsDefaultCurrencyLabel,
              selectedCurrency,
              FiatCurrency.values.map((currency) => currency.code).toList(),
              FiatCurrency.values.map((currency) => currency.code).toList(),
              (value) {
                context.read<ExchangeCubit>().updateSelectedCurrency(value);
              },
            ),
            const SizedBox(height: 32),
            const _EmailNotificationsToggle(),
            const Spacer(),
            if (hasUnsetValues) ...[
              BBText(
                context.loc.exchangeAppSettingsValidationWarning,
                style: context.font.bodySmall?.copyWith(
                  color: context.appColors.error,
                ),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: BullButton.big(
                label: context.loc.exchangeAppSettingsSaveButton,
                onPressed: () async {
                  await context.read<ExchangeCubit>().savePreferences();
                },
                disabled: state.isSaving || hasUnsetValues,
                bgColor: hasUnsetValues
                    ? context.appColors.outline
                    : context.appColors.onSurface,
                textColor: context.appColors.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField(
    BuildContext context,
    String label,
    String? selectedValue,
    List<String> values,
    List<String> displayTexts,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          label,
          style: context.font.labelMedium?.copyWith(
            color: context.appColors.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          child: Material(
            elevation: 2,
            shadowColor: context.appColors.overlay.withValues(alpha: 0.1),
            color: context.appColors.surface,
            borderRadius: BorderRadius.circular(4.0),
            child: Center(
              child: DropdownButtonFormField<String>(
                initialValue: selectedValue,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: context.appColors.onSurface,
                ),
                items: values
                    .asMap()
                    .entries
                    .map(
                      (entry) => DropdownMenuItem<String>(
                        value: values[entry.key],
                        child: BBText(
                          displayTexts[entry.key],
                          style: context.font.headlineSmall?.copyWith(
                            color: context.appColors.onSurface,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmailNotificationsToggle extends StatelessWidget {
  const _EmailNotificationsToggle();

  @override
  Widget build(BuildContext context) {
    final state = context.select((ExchangeCubit cubit) => cubit.state);
    final emailNotificationsEnabled =
        state.selectedEmailNotifications ??
        state.userSummary?.emailNotificationsEnabled ??
        true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: context.appColors.overlay.withValues(alpha: 0.05),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText(
                  context.loc.exchangeAppSettingsEmailNotificationsLabel,
                  style: context.font.labelMedium?.copyWith(
                    color: context.appColors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                BBText(
                  context.loc.exchangeAppSettingsEmailNotificationsDescription,
                  style: context.font.bodySmall?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          BullSwitch(
            value: emailNotificationsEnabled,
            onChanged: (value) {
              context.read<ExchangeCubit>().updateSelectedEmailNotifications(
                value,
              );
            },
          ),
        ],
      ),
    );
  }
}
