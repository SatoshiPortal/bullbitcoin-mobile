import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExchangeBitcoinWalletsScreen extends StatelessWidget {
  const ExchangeBitcoinWalletsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.secondaryFixed,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.exchangeBitcoinWalletsTitle,
          onBack: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              const SizedBox(height: 12),
              _buildAddressField(
                context,
                context.loc.exchangeBitcoinWalletsBitcoinAddressLabel,
                'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
              ),
              const SizedBox(height: 24),
              _buildAddressField(
                context,
                context.loc.exchangeBitcoinWalletsLightningAddressLabel,
                '',
              ),
              const SizedBox(height: 24),
              _buildAddressField(
                context,
                context.loc.exchangeBitcoinWalletsLiquidAddressLabel,
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
      crossAxisAlignment: .start,
      children: [
        Text(
          label,
          style: context.font.labelMedium?.copyWith(
            color: context.appColors.secondary,
          ),
        ),
        const SizedBox(height: 12),
        BBInputText(
          value: value,
          onChanged: (newValue) {
            // TODO: Implement address update functionality
          },
          hint: value.isEmpty
              ? context.loc.exchangeBitcoinWalletsEnterAddressHint
              : null,
          hintStyle: context.font.bodyMedium?.copyWith(
            color: context.appColors.surfaceContainer,
          ),
          rightIcon: Icon(
            Icons.edit,
            size: 20,
            color: context.appColors.outline,
          ),
          onRightTap: () {
            // TODO: Implement edit functionality
          },
          style: context.font.bodyLarge?.copyWith(
            color: context.appColors.secondary,
            fontWeight: .w500,
          ),
        ),
      ],
    );
  }
}
