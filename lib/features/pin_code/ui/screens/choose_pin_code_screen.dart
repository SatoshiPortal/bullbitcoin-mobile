import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/dialpad/dial_pad.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/pin_code/presentation/blocs/pin_code_setting_bloc/pin_code_setting_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ChoosePinCodeScreen extends StatelessWidget {
  const ChoosePinCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () => context.pop(),
          title: context.loc.pinCodeAuthentication,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    crossAxisAlignment: .stretch,
                    children: [
                      const Gap(30),
                      Text(
                        context.loc.pinCodeCreateTitle,
                        textAlign: .center,
                        style: context.font.headlineMedium?.copyWith(
                          color: context.appColors.onSurface,
                        ),
                        maxLines: 3,
                      ),
                      const Gap(16),
                      Text(
                        context.loc.pinCodeCreateDescription,
                        textAlign: .center,
                        style: context.font.bodyMedium?.copyWith(
                          color: context.appColors.textMuted,
                        ),
                      ),
                      const Gap(30),
                      BlocSelector<
                        PinCodeSettingBloc,
                        PinCodeSettingState,
                        (String, bool)
                      >(
                        selector: (state) =>
                            (state.pinCode, state.obscurePinCode),
                        builder: (context, data) {
                          final (pinCode, obscurePinCode) = data;
                          return BBInputText(
                            value: pinCode,
                            obscure: obscurePinCode,
                            onRightTap: () =>
                                context.read<PinCodeSettingBloc>().add(
                                  const PinCodeSettingPinCodeObscureToggled(),
                                ),
                            rightIcon: obscurePinCode
                                ? Icon(
                                    Icons.visibility_off_outlined,
                                    color: context.appColors.onSurface,
                                  )
                                : Icon(
                                    Icons.visibility_outlined,
                                    color: context.appColors.onSurface,
                                  ),
                            onlyNumbers: true,
                            onChanged: (value) {},
                          );
                        },
                      ),
                      const Gap(2),
                      BlocSelector<
                        PinCodeSettingBloc,
                        PinCodeSettingState,
                        bool
                      >(
                        selector: (state) => state.isValidPinCode,
                        builder: (context, isValidPinCode) {
                          return !isValidPinCode &&
                                  context
                                      .read<PinCodeSettingBloc>()
                                      .state
                                      .pinCode
                                      .isNotEmpty
                              ? Text(
                                  context.loc.pinCodeMinLengthError(
                                    context
                                        .read<PinCodeSettingBloc>()
                                        .state
                                        .minPinCodeLength
                                        .toString(),
                                  ),
                                  textAlign: .start,
                                  style: context.font.labelSmall?.copyWith(
                                    color: context.appColors.error,
                                  ),
                                )
                              : const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: DialPad(
                onNumberPressed: (value) => context
                    .read<PinCodeSettingBloc>()
                    .add(PinCodeSettingPinCodeNumberAdded(int.parse(value))),
                onBackspacePressed: () => context
                    .read<PinCodeSettingBloc>()
                    .add(const PinCodeSettingPinCodeNumberRemoved()),
                disableFeedback: true,
                onlyDigits: true,
              ),
            ),
            const Gap(16),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 10,
          ),
          child: const _ConfirmButton(),
        ),
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: BlocSelector<PinCodeSettingBloc, PinCodeSettingState, bool>(
        selector: (state) => state.isValidPinCode,
        builder: (context, isValidPinCode) {
          return BBButton.big(
            label: context.loc.pinCodeContinue,
            textStyle: context.font.headlineLarge,
            disabled: !isValidPinCode,
            bgColor: isValidPinCode
                ? context.appColors.primary
                : context.appColors.surfaceContainerHighest,
            onPressed: () {
              if (isValidPinCode) {
                context.read<PinCodeSettingBloc>().add(
                  const PinCodeSettingPinCodeChosen(),
                );
              }
            },
            textColor: isValidPinCode
                ? context.appColors.onPrimary
                : context.appColors.textMuted,
          );
        },
      ),
    );
  }
}
