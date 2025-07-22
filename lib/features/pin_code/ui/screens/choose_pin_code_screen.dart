import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/dialpad/dial_pad.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/pin_code/presentation/bloc/pin_code_setting_bloc.dart';
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
          title: "Authentication",
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Gap(75),
                BBText(
                  'Create new pin',
                  textAlign: TextAlign.center,
                  style: context.font.headlineMedium?.copyWith(
                    color: context.colour.outline,
                  ),
                  maxLines: 3,
                ),
                const Gap(50),
                BlocSelector<
                  PinCodeSettingBloc,
                  PinCodeSettingState,
                  (String, bool)
                >(
                  selector: (state) => (state.pinCode, state.obscurePinCode),
                  builder: (context, data) {
                    final (pinCode, obscurePinCode) = data;
                    return BBInputText(
                      value: pinCode,
                      obscure: obscurePinCode,
                      onRightTap:
                          () => context.read<PinCodeSettingBloc>().add(
                            const PinCodeSettingPinCodeObscureToggled(),
                          ),
                      rightIcon:
                          obscurePinCode
                              ? const Icon(Icons.visibility_off_outlined)
                              : const Icon(Icons.visibility_outlined),
                      onlyNumbers: true,
                      onChanged: (value) {},
                    );
                  },
                ),
                const Gap(2),
                BlocSelector<PinCodeSettingBloc, PinCodeSettingState, bool>(
                  selector: (state) => state.isValidPinCode,
                  builder: (context, isValidPinCode) {
                    return !isValidPinCode &&
                            context
                                .read<PinCodeSettingBloc>()
                                .state
                                .pinCode
                                .isNotEmpty
                        ? BBText(
                          'PIN must be at least ${context.read<PinCodeSettingBloc>().state.minPinCodeLength} digits long',
                          textAlign: TextAlign.start,
                          style: context.font.labelSmall?.copyWith(
                            color: context.colour.error,
                          ),
                        )
                        : const SizedBox.shrink();
                  },
                ),
                const Gap(130),
                DialPad(
                  onNumberPressed:
                      (value) => context.read<PinCodeSettingBloc>().add(
                        PinCodeSettingPinCodeNumberAdded(int.parse(value)),
                      ),
                  onBackspacePressed:
                      () => context.read<PinCodeSettingBloc>().add(
                        const PinCodeSettingPinCodeNumberRemoved(),
                      ),
                  disableFeedback: true,
                ),
              ],
            ),
          ),
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
            label: 'Confirm',
            textStyle: context.font.headlineLarge,
            disabled: !isValidPinCode,
            bgColor:
                isValidPinCode
                    ? context.colour.secondary
                    : context.colour.outline,
            onPressed: () {
              if (isValidPinCode) {
                context.read<PinCodeSettingBloc>().add(
                  const PinCodeSettingPinCodeChosen(),
                );
              }
            },
            textColor: context.colour.onSecondary,
          );
        },
      ),
    );
  }
}
