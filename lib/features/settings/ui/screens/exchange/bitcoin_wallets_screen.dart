import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExchangeBitcoinWalletsScreen extends StatelessWidget {
  const ExchangeBitcoinWalletsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colour.secondaryFixed,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Default Bitcoin Wallets',
          onBack: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _buildAddressField(
                context,
                'Bitcoin Address',
                'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
              ),
              const SizedBox(height: 24),
              _buildAddressField(context, 'Lightning (LN address)', ''),
              const SizedBox(height: 24),
              _buildAddressField(
                context,
                'Liquid address',
                'lq1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressField(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.font.labelMedium?.copyWith(
            color: context.colour.secondary,
          ),
        ),
        const SizedBox(height: 12),
        BBInputText(
          value: value,
          onChanged: (newValue) {
            // TODO: Implement address update functionality
          },
          hint: value.isEmpty ? 'Enter address' : null,
          hintStyle: context.font.bodyMedium?.copyWith(
            color: context.colour.surfaceContainer,
          ),
          rightIcon: Icon(Icons.edit, size: 20, color: context.colour.outline),
          onRightTap: () {
            // TODO: Implement edit functionality
          },
          style: context.font.bodyLarge?.copyWith(
            color: context.colour.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
