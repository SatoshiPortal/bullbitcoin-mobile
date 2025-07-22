import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExchangeAppSettingsScreen extends StatefulWidget {
  const ExchangeAppSettingsScreen({super.key});

  @override
  State<ExchangeAppSettingsScreen> createState() =>
      _ExchangeAppSettingsScreenState();
}

class _ExchangeAppSettingsScreenState extends State<ExchangeAppSettingsScreen> {
  String selectedLanguage = 'English';
  String selectedCurrency = 'CAD \$';

  @override
  Widget build(BuildContext context) {
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
              // const SizedBox(height: 12),
              _buildDropdownField(
                context,
                'Preferred Language',
                selectedLanguage,
                ['English', 'French', 'Spanish', 'German'],
                (value) {
                  setState(() {
                    selectedLanguage = value!;
                  });
                },
              ),
              const SizedBox(height: 24),
              _buildDropdownField(
                context,
                'Default Currency',
                selectedCurrency,
                ['CAD \$', 'USD \$', 'EUR €', 'GBP £'],
                (value) {
                  setState(() {
                    selectedCurrency = value!;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField(
    BuildContext context,
    String label,
    String selectedValue,
    List<String> options,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
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
            color: context.colour.outline,
          ),
          onRightTap: () {
            // TODO: Show dropdown menu
          },
          style: context.font.bodyLarge?.copyWith(
            color: context.colour.secondary,
          ),
        ),
      ],
    );
  }
}
