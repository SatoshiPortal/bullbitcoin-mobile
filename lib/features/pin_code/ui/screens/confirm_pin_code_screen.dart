import 'package:bb_mobile/features/pin_code/presentation/bloc/pin_code_setting_bloc.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/dialpad/dial_pad.dart';
import 'package:bb_mobile/ui/components/inputs/text_input.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/template/screen_template.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class ConfirmPinCodeScreen extends StatelessWidget {
  const ConfirmPinCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void backHandler() {
      context.read<PinCodeSettingBloc>().add(const PinCodeSettingStarted());
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        backHandler();
      },
      child: Scaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: TopBar(onBack: backHandler, title: "Authentication"),
        ),
        body: StackedPage(
          bottomChildHeight: MediaQuery.of(context).size.height * 0.11,
          bottomChild: const _ConfirmButton(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Gap(75),
                BBText(
                  'Confirm new pin',
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
                  selector:
                      (state) => (
                        state.pinCodeConfirmation,
                        state.obscurePinCode,
                      ),
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
                  selector:
                      (state) =>
                          state.pinCode != state.pinCodeConfirmation &&
                          state.pinCodeConfirmation.isNotEmpty,
                  builder: (context, hasError) {
                    return hasError
                        ? BBText(
                          'PINs do not match',
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
                        PinCodeSettingPinCodeConfirmationNumberAdded(
                          int.parse(value),
                        ),
                      ),
                  onBackspacePressed:
                      () => context.read<PinCodeSettingBloc>().add(
                        const PinCodeSettingPinCodeConfirmationNumberRemoved(),
                      ),
                ),
              ],
            ),
          ),
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
        selector: (state) => state.canConfirm,
        builder: (context, canConfirm) {
          return BBButton.big(
            label: 'Confirm',
            textStyle: context.font.headlineLarge,
            disabled: !canConfirm,
            bgColor:
                canConfirm ? context.colour.secondary : context.colour.outline,
            onPressed: () {
              if (canConfirm) {
                context.read<PinCodeSettingBloc>().add(
                  const PinCodeSettingPinCodeConfirmed(),
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
