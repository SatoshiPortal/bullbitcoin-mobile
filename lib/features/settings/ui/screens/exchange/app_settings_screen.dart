import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ExchangeAppSettingsScreen extends StatelessWidget {
  const ExchangeAppSettingsScreen({super.key});

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
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Settings saved successfully',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.white),
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: theme.colorScheme.onSurface.withAlpha(204),
            behavior: SnackBarBehavior.floating,
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 100, left: 40, right: 40),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: context.colour.secondaryFixed,
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: TopBar(
            title: 'App Settings',
            onBack: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDropdownField(
                  context,
                  'Preferred Language',
                  selectedLanguage,
                  ExchangeLanguage.values.map((lang) => lang.code).toList(),
                  ExchangeLanguage.values
                      .map((lang) => lang.displayName)
                      .toList(),
                  (value) {
                    context.read<ExchangeCubit>().updateSelectedLanguage(value);
                  },
                ),
                const SizedBox(height: 24),
                _buildDropdownField(
                  context,
                  'Default Currency',
                  selectedCurrency,
                  FiatCurrency.values.map((currency) => currency.code).toList(),
                  FiatCurrency.values.map((currency) => currency.code).toList(),
                  (value) {
                    context.read<ExchangeCubit>().updateSelectedCurrency(value);
                  },
                ),
                const Spacer(),
                if (hasUnsetValues) ...[
                  BBText(
                    'Please set both language and currency preferences before saving.',
                    style: context.font.bodySmall?.copyWith(
                      color: context.colour.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  child: BBButton.big(
                    label: 'Save',
                    onPressed: () async {
                      await context.read<ExchangeCubit>().savePreferences();
                    },
                    disabled: state.isSaving || hasUnsetValues,
                    bgColor:
                        hasUnsetValues ? context.colour.outline : Colors.black,
                    textColor: context.colour.onPrimary,
                  ),
                ),
              ],
            ),
          ),
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
            color: context.colour.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          child: Material(
            elevation: 4,
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(4.0),
            child: Center(
              child: DropdownButtonFormField<String>(
                value: selectedValue,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: context.colour.secondary,
                ),
                items:
                    values
                        .asMap()
                        .entries
                        .map(
                          (entry) => DropdownMenuItem<String>(
                            value: values[entry.key],
                            child: BBText(
                              displayTexts[entry.key],
                              style: context.font.headlineSmall,
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
