import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/exchange_settings/domain/entities/exchange_preferences.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/exchange_preferences_cubit.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/exchange_preferences_state.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/exchange_settings_failure_l10n.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ExchangePreferencesScreen extends StatefulWidget {
  const ExchangePreferencesScreen({super.key});

  @override
  State<ExchangePreferencesScreen> createState() =>
      _ExchangePreferencesScreenState();
}

class _ExchangePreferencesScreenState extends State<ExchangePreferencesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ExchangePreferencesCubit>().loadPreferences();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ExchangePreferencesCubit>().state;

    return BlocListener<ExchangePreferencesCubit, ExchangePreferencesState>(
      listenWhen: (previous, current) =>
          previous.isSaving && !current.isSaving && current.saveFailure == null,
      listener: (context, state) {
        BullSnackBar.show(
          context,
          message: context.loc.exchangeAppSettingsSaveSuccessMessage,
        );
        ExchangeScope.refreshSession(context);
      },
      child: BullScaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: BullTopBar(
            title: context.loc.settingsAppSettingsTitle,
            onBack: () => context.pop(),
          ),
        ),
        body: Column(
          children: [
            BullFadingLinearProgress(
              trigger: state.isLoading,
              backgroundColor: context.bull.surface,
              foregroundColor: context.bull.primary,
            ),
            Expanded(child: _buildContent(context, state)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ExchangePreferencesState state) {
    final preferences = state.preferences;

    if (state.isLoading && preferences == null) {
      return const SizedBox.shrink();
    }

    if (preferences == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BullText(
              state.loadFailure?.toTranslated(context) ??
                  context.loc.exchangeAccountInfoLoadErrorMessage,
              style: context.bullText.bodyMedium?.copyWith(
                color: context.bull.error,
              ),
            ),
            const Gap(BullSpacing.md),
            BullButton.big(
              label: context.loc.retry,
              onPressed: () =>
                  context.read<ExchangePreferencesCubit>().loadPreferences(),
              bgColor: context.bull.onSurface,
              textColor: context.bull.surface,
            ),
          ],
        ),
      );
    }

    final hasUnsetValues = !preferences.isComplete;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(BullSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdownField(
              context,
              context.loc.exchangeAppSettingsPreferredLanguageLabel,
              preferences.language,
              ExchangeLanguage.values.map((lang) => lang.code).toList(),
              ExchangeLanguage.values.map((lang) => lang.displayName).toList(),
              context.read<ExchangePreferencesCubit>().updateLanguage,
            ),
            const Gap(BullSpacing.lg),
            _buildDropdownField(
              context,
              context.loc.exchangeAppSettingsDefaultCurrencyLabel,
              preferences.currency,
              FiatCurrency.values.map((currency) => currency.code).toList(),
              FiatCurrency.values.map((currency) => currency.code).toList(),
              context.read<ExchangePreferencesCubit>().updateCurrency,
            ),
            const Gap(BullSpacing.xl),
            _EmailNotificationsToggle(preferences: preferences),
            const Spacer(),
            if (hasUnsetValues) ...[
              BullText(
                context.loc.exchangeAppSettingsValidationWarning,
                style: context.bullText.bodySmall?.copyWith(
                  color: context.bull.error,
                ),
              ),
              const Gap(BullSpacing.md),
            ],
            if (state.saveFailure != null) ...[
              BullInfoCard(
                description: state.saveFailure!.toTranslated(context),
                tagColor: context.bull.error,
                bgColor: context.bull.errorContainer,
                onTap: () =>
                    context.read<ExchangePreferencesCubit>().savePreferences(),
              ),
              const Gap(BullSpacing.md),
            ],
            SizedBox(
              width: double.infinity,
              child: BullButton.big(
                label: context.loc.exchangeAppSettingsSaveButton,
                onPressed: () =>
                    context.read<ExchangePreferencesCubit>().savePreferences(),
                disabled: state.isSaving || hasUnsetValues,
                bgColor: hasUnsetValues
                    ? context.bull.outline
                    : context.bull.onSurface,
                textColor: context.bull.surface,
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
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BullText(
          label,
          style: context.bullText.labelMedium?.copyWith(
            color: context.bull.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Gap(BullSpacing.xs),
        BullDropdown<String>(
          value: selectedValue,
          items: values
              .asMap()
              .entries
              .map(
                (entry) => DropdownMenuItem<String>(
                  value: values[entry.key],
                  child: BullText(
                    displayTexts[entry.key],
                    style: context.bullText.headlineSmall?.copyWith(
                      color: context.bull.onSurface,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ],
    );
  }
}

class _EmailNotificationsToggle extends StatelessWidget {
  const _EmailNotificationsToggle({required this.preferences});

  final ExchangePreferences preferences;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BullSpacing.md),
      decoration: BoxDecoration(
        color: context.bull.surface,
        borderRadius: BorderRadius.circular(BullRadius.sm),
        boxShadow: [
          BoxShadow(
            color: context.bull.overlay.withValues(alpha: 0.05),
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
                BullText(
                  context.loc.exchangeAppSettingsEmailNotificationsLabel,
                  style: context.bullText.labelMedium?.copyWith(
                    color: context.bull.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Gap(BullSpacing.xxs),
                BullText(
                  context.loc.exchangeAppSettingsEmailNotificationsDescription,
                  style: context.bullText.bodySmall?.copyWith(
                    color: context.bull.textMuted,
                  ),
                ),
              ],
            ),
          ),
          BullSwitch(
            value: preferences.emailNotificationsEnabled,
            onChanged: (value) {
              context.read<ExchangePreferencesCubit>().updateEmailNotifications(
                value,
              );
            },
          ),
        ],
      ),
    );
  }
}
