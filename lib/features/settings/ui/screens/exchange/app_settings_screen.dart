import 'package:bb_mobile/core/exchange/domain/usecases/save_user_preferences_usecase.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ExchangeAppSettingsScreen extends StatefulWidget {
  const ExchangeAppSettingsScreen({super.key});

  @override
  State<ExchangeAppSettingsScreen> createState() =>
      _ExchangeAppSettingsScreenState();
}

class _ExchangeAppSettingsScreenState extends State<ExchangeAppSettingsScreen> {
  String? selectedLanguage;
  String? selectedCurrency;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExchangeCubit, ExchangeState>(
      builder: (context, state) {
        final userSummary = state.userSummary;

        // Initialize values from userSummary if not already set
        if (selectedLanguage == null && userSummary != null) {
          selectedLanguage = userSummary.language;
        }
        if (selectedCurrency == null && userSummary != null) {
          selectedCurrency = userSummary.currency;
        }

        return Scaffold(
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
                    selectedLanguage ?? 'Not Set',
                    ['English', 'French', 'Spanish', 'German'],
                    (value) {
                      setState(() {
                        selectedLanguage = value;
                      });
                    },
                    isNotSet: selectedLanguage == null,
                  ),
                  const SizedBox(height: 24),
                  _buildDropdownField(
                    context,
                    'Default Currency',
                    selectedCurrency ?? 'Not Set',
                    ['CAD \$', 'USD \$', 'EUR €', 'GBP £'],
                    (value) {
                      setState(() {
                        selectedCurrency = value;
                      });
                    },
                    isNotSet: selectedCurrency == null,
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: BBButton.big(
                      label: _isSaving ? 'Saving...' : 'Save',
                      onPressed: _isSaving ? () {} : () => _savePreferences(),
                      bgColor: Colors.black,
                      textColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDropdownField(
    BuildContext context,
    String label,
    String selectedValue,
    List<String> options,
    Function(String?) onChanged, {
    bool isNotSet = false,
  }) {
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
        BBInputText(
          value: selectedValue,
          onChanged: (value) => onChanged(value),
          rightIcon: Icon(
            Icons.keyboard_arrow_down,
            color: isNotSet ? context.colour.error : context.colour.outline,
          ),
          onRightTap: () {
            // TODO: Show dropdown menu
          },
          style: context.font.bodyLarge?.copyWith(
            color: isNotSet ? context.colour.error : context.colour.secondary,
          ),
        ),
        if (isNotSet) ...[
          const SizedBox(height: 4),
          BBText(
            'Please set a value',
            style: context.font.bodySmall?.copyWith(
              color: context.colour.error,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _savePreferences() async {
    if (selectedLanguage == null || selectedCurrency == null) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: BBText(
            'Please set both language and currency before saving',
            style: context.font.bodyMedium,
          ),
          backgroundColor: context.colour.error,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await locator<SaveUserPreferencesUsecase>().execute(
        language: selectedLanguage!,
        currency: selectedCurrency,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: BBText(
            'Settings saved successfully',
            style: context.font.bodyMedium,
          ),
          backgroundColor: context.colour.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: BBText(
            'Failed to save settings: $e',
            style: context.font.bodyMedium,
          ),
          backgroundColor: context.colour.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
