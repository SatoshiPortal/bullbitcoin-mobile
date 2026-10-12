import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/exchange_settings/domain/entities/exchange_preferences.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/exchange_preferences_cubit.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/exchange_preferences_state.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/exchange_settings_failure_l10n.dart';
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
        SnackBarUtils.showSnackBar(
          context,
          context.loc.exchangeAppSettingsSaveSuccessMessage,
        );
        ExchangeScope.refreshSession(context);
      },
      child: Scaffold(
        backgroundColor: context.appColors.background,
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: TopBar(
            title: context.loc.settingsAppSettingsTitle,
            onBack: () => context.pop(),
          ),
        ),
        body: Column(
          children: [
            if (state.isLoading)
              LinearProgressIndicator(
                backgroundColor: context.appColors.surface,
                color: context.appColors.primary,
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
            BBText(
              state.loadFailure?.toTranslated(context) ??
                  context.loc.exchangeAccountInfoLoadErrorMessage,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.error,
              ),
            ),
            const SizedBox(height: 16),
            BBButton.big(
              label: context.loc.retry,
              onPressed: () =>
                  context.read<ExchangePreferencesCubit>().loadPreferences(),
              bgColor: context.appColors.onSurface,
              textColor: context.appColors.surface,
            ),
          ],
        ),
      );
    }

    final hasUnsetValues = !preferences.isComplete;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdownField(
              context,
              context.loc.exchangeAppSettingsPreferredLanguageLabel,
              preferences.language,
              ExchangeLanguage.values.map((lang) => lang.code).toList(),
              ExchangeLanguage.values.map((lang) => lang.displayName).toList(),
              (value) {
                context.read<ExchangePreferencesCubit>().updateLanguage(value);
              },
            ),
            const SizedBox(height: 24),
            _buildDropdownField(
              context,
              context.loc.exchangeAppSettingsDefaultCurrencyLabel,
              preferences.currency,
              FiatCurrency.values.map((currency) => currency.code).toList(),
              FiatCurrency.values.map((currency) => currency.code).toList(),
              (value) {
                context.read<ExchangePreferencesCubit>().updateCurrency(value);
              },
            ),
            const SizedBox(height: 32),
            _EmailNotificationsToggle(preferences: preferences),
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
            if (state.saveFailure != null) ...[
              InfoCard(
                description: state.saveFailure!.toTranslated(context),
                tagColor: context.appColors.error,
                bgColor: context.appColors.errorContainer,
                onTap: () =>
                    context.read<ExchangePreferencesCubit>().savePreferences(),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: BBButton.big(
                label: context.loc.exchangeAppSettingsSaveButton,
                onPressed: () =>
                    context.read<ExchangePreferencesCubit>().savePreferences(),
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
  const _EmailNotificationsToggle({required this.preferences});

  final ExchangePreferences preferences;

  @override
  Widget build(BuildContext context) {
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
          Switch(
            value: preferences.emailNotificationsEnabled,
            onChanged: (value) {
              context.read<ExchangePreferencesCubit>().updateEmailNotifications(
                value,
              );
            },
            activeTrackColor: context.appColors.primary,
            activeThumbColor: context.appColors.surface,
          ),
        ],
      ),
    );
  }
}
