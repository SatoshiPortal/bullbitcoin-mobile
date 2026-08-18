import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/pin_code/presentation/bloc/pin_code_setting_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullPage, BullTopBar, Gap;
import 'package:go_router/go_router.dart';

class PinSettingsScreen extends StatelessWidget {
  const PinSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<PinCodeSettingBloc>();
    final isPinCodeSet = context.watch<PinCodeSettingBloc>().state.isPinCodeSet;

    return BullPage(
      topBar: BullTopBar(
        onBack: () => context.pop(),
        title: context.loc.pinCodeSecurityPinTitle,
      ),
      child: SafeArea(
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
                        color: context.appColors.onSurface,
                      ),
                    ),
                    const Gap(16),
                    Text(
                      context.loc.pinCodeCreateDescription,
                      style: context.font.bodyMedium?.copyWith(
                        color: context.appColors.textMuted,
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
                  BullButton.big(
                    label: isPinCodeSet
                        ? context.loc.pinCodeChangeButton
                        : context.loc.pinCodeCreateButton,
                    onPressed: () => bloc.add(const PinCodeCreate()),
                    bgColor: context.appColors.secondary,
                    textColor: context.appColors.onSecondary,
                  ),
                  const Gap(16),
                  if (isPinCodeSet)
                    BullButton.big(
                      label: context.loc.pinCodeRemoveButton,
                      onPressed: () => bloc.add(const PinCodeDelete()),
                      bgColor: context.appColors.error,
                      textColor: context.appColors.onError,
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
