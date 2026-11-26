import 'package:exchange/exchange.dart';

import '../../../exchange_l10n.dart';
import '../../domain/entities/exchange_preferences.dart';
import '../../presentation/exchange_preferences_bloc.dart';
import '../../domain/exchange_preferences_machine.dart';
import '../../presentation/exchange_settings_failure_l10n.dart';

import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ExchangePreferencesScreen extends StatefulWidget {
  final Future<void> Function(BuildContext) refreshSession;

  const ExchangePreferencesScreen({required this.refreshSession, super.key});

  @override
  State<ExchangePreferencesScreen> createState() =>
      _ExchangePreferencesScreenState();
}

class _ExchangePreferencesScreenState extends State<ExchangePreferencesScreen> {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<ExchangePreferencesBloc>().state;

    return BlocListener<ExchangePreferencesBloc, PreferencesState>(
      // Only a write whose values are all on screen is reported as saved
      // (SET-2).
      listenWhen: (previous, current) =>
          previous is! PreferencesSaved && current is PreferencesSaved,
      listener: (context, state) {
        BullSnackBar.show(
          context,
          message: context.loc.exchangeAppSettingsSaveSuccessMessage,
        );
        widget.refreshSession(context);
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
              trigger: state is PreferencesLoading,
              backgroundColor: context.bull.surface,
              foregroundColor: context.bull.primary,
            ),
            Expanded(child: _buildContent(context, state)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, PreferencesState state) {
    final bloc = context.read<ExchangePreferencesBloc>();
    final preferences = shownPreferences(state);
    final failure = switch (state) {
      PreferencesSaveFailed(:final failure) => failure,
      PreferencesLoading() ||
      PreferencesLoadFailed() ||
      PreferencesSignedOut() ||
      PreferencesEditing() ||
      PreferencesSaving() ||
      PreferencesSaved() => null,
    };

    if (preferences == null) {
      return switch (state) {
        PreferencesLoadFailed(:final failure) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BullText(
                failure.toTranslated(context),
                style: context.bullType.body.copyWith(
                  color: context.bull.error,
                ),
              ),
              const Gap(BullSpacing.md),
              BullButton.secondary(
                label: context.loc.retry,
                onPressed: () => bloc.add(const PreferencesRetryPressed()),
              ),
            ],
          ),
        ),
        PreferencesSignedOut() => Center(
          child: Padding(
            padding: const EdgeInsets.all(BullSpacing.md),
            child: BullText(
              context.loc.exchangeSettingsSignedOut,
              style: context.bullType.body.copyWith(color: context.bull.error),
            ),
          ),
        ),
        PreferencesLoading() ||
        PreferencesEditing() ||
        PreferencesSaving() ||
        PreferencesSaved() ||
        PreferencesSaveFailed() => const SizedBox.shrink(),
      };
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
              (code) => bloc.add(PreferencesLanguageChosen(code)),
            ),
            const Gap(BullSpacing.lg),
            _buildDropdownField(
              context,
              context.loc.exchangeAppSettingsDefaultCurrencyLabel,
              preferences.currency,
              FiatCurrency.values.map((currency) => currency.code).toList(),
              FiatCurrency.values.map((currency) => currency.code).toList(),
              (code) => bloc.add(PreferencesCurrencyChosen(code)),
            ),
            const Gap(BullSpacing.xl),
            _EmailNotificationsToggle(preferences: preferences),
            const Spacer(),
            if (hasUnsetValues) ...[
              BullText(
                context.loc.exchangeAppSettingsValidationWarning,
                style: context.bullType.label
                    .copyWith(fontWeight: FontWeight.w400)
                    .copyWith(color: context.bull.error),
              ),
              const Gap(BullSpacing.md),
            ],
            if (failure != null) ...[
              BullInfoCard(
                description: failure.toTranslated(context),
                tagColor: context.bull.error,
                bgColor: context.bull.errorContainer,
                onTap: () => bloc.add(const PreferencesSavePressed()),
              ),
              const Gap(BullSpacing.md),
            ],
            SizedBox(
              width: double.infinity,
              child: BullButton.primary(
                label: context.loc.exchangeAppSettingsSaveButton,
                onPressed: (state is PreferencesSaving || hasUnsetValues)
                    ? null
                    : () => bloc.add(const PreferencesSavePressed()),
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
          style: context.bullType.caption.copyWith(
            color: context.bull.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Gap(BullSpacing.xs),
        BullDropdown<String>(
          value: selectedValue,
          items: [
            for (var i = 0; i < values.length; i++)
              BullPickerItem(value: values[i], label: displayTexts[i]),
          ],
          onChanged: onChanged,
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
        borderRadius: BorderRadius.circular(context.bullShapes.card),
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
                  style: context.bullType.caption.copyWith(
                    color: context.bull.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Gap(BullSpacing.xxs),
                BullText(
                  context.loc.exchangeAppSettingsEmailNotificationsDescription,
                  style: context.bullType.label
                      .copyWith(fontWeight: FontWeight.w400)
                      .copyWith(color: context.bull.textMuted),
                ),
              ],
            ),
          ),
          BullSwitch(
            value: preferences.emailNotificationsEnabled,
            onChanged: (value) => context.read<ExchangePreferencesBloc>().add(
              PreferencesEmailToggled(value),
            ),
          ),
        ],
      ),
    );
  }
}
