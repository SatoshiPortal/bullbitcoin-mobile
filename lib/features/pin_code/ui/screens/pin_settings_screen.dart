import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/pin_code/presentation/blocs/pin_code_setting_bloc/pin_code_setting_bloc.dart';
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
          title: context.loc.pinCodeSecurityPinTitle,
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
                  crossAxisAlignment: .start,
                  children: [
                    Text(
                      context.loc.pinCodeManageTitle,
                      style: context.font.headlineMedium?.copyWith(
                        color: context.appColors.outlineVariant,
                      ),
                    ),
                    const Gap(16),
                    Text(
                      context.loc.pinCodeCreateDescription,
                      style: context.font.bodyMedium?.copyWith(
                        color: context.appColors.outline,
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
                    label: isPinCodeSet
                        ? context.loc.pinCodeChangeButton
                        : context.loc.pinCodeCreateButton,
                    onPressed: () => bloc.add(const PinCodeCreate()),
                    bgColor: context.appColors.secondary,
                    textColor: context.appColors.onSecondary,
                  ),
                  const Gap(16),
                  if (isPinCodeSet)
                    BBButton.big(
                      label: context.loc.pinCodeRemoveButton,
                      onPressed: () => bloc.add(const PinCodeDelete()),
                      bgColor: context.appColors.errorContainer,
                      textColor: context.appColors.onSecondary,
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
