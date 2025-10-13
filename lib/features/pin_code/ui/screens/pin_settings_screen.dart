import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/pin_code/presentation/bloc/pin_code_setting_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class PinSettingsScreen extends StatelessWidget {
  const PinSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<PinCodeSettingBloc>();
    final isPinCodeSet = context.watch<PinCodeSettingBloc>().state.isPinCodeSet;

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () => context.pop(),
          title: "Security PIN",
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manage your security PIN',
                      style: context.font.headlineMedium?.copyWith(
                        color: context.colour.outlineVariant,
                      ),
                    ),
                    const Gap(16),
                    Text(
                      'Your PIN protects access to your wallet and settings. Keep it memorable.',
                      style: context.font.bodyMedium?.copyWith(
                        color: context.colour.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  BBButton.big(
                    label: isPinCodeSet ? 'Change PIN' : 'Create PIN',
                    onPressed: () => bloc.add(const PinCodeCreate()),
                    bgColor: context.colour.secondary,
                    textColor: context.colour.onSecondary,
                  ),
                  const Gap(16),
                  if (isPinCodeSet)
                    BBButton.big(
                      label: 'Remove Security PIN',
                      onPressed: () => bloc.add(const PinCodeDelete()),
                      bgColor: context.colour.errorContainer,
                      textColor: context.colour.onSecondary,
                    ),
                  const Gap(24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
