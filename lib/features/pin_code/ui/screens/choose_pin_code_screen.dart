import 'package:bb_mobile/features/pin_code/presentation/bloc/pin_code_setting_bloc.dart';
import 'package:bb_mobile/router.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/inputs/pin_input.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/numpad/num_pad.dart';
import 'package:bb_mobile/ui/components/template/screen_template.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ChoosePinCodeScreen extends StatelessWidget {
  const ChoosePinCodeScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () => context.go(AppRoute.home.path),
          title: "Authentication",
        ),
      ),
      body: StackedPage(
        bottomChildHeight: MediaQuery.of(context).size.height * 0.11,
        bottomChild: const _ConfirmButton(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BBText(
                'Create new pin',
                textAlign: TextAlign.center,
                style: context.font.labelMedium?.copyWith(
                  color: context.colour.outline,
                ),
                maxLines: 3,
              ),
              const Gap(50),
              BlocSelector<PinCodeSettingBloc, PinCodeSettingState, String>(
                selector: (state) => state.pinCode,
                builder: (context, pinCode) {
                  return PinInput(
                    value: pinCode,
                    rightIcon: const Icon(Icons.visibility_off_outlined),
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
              const Gap(50),
              NumPad(
                onNumberPressed: (value) =>
                    context.read<PinCodeSettingBloc>().add(
                          PinCodeSettingPinCodeNumberAdded(int.parse(value)),
                        ),
                onBackspacePressed: () =>
                    context.read<PinCodeSettingBloc>().add(
                          const PinCodeSettingPinCodeNumberRemoved(),
                        ),
              ),
            ],
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
        selector: (state) => state.isValidPinCode,
        builder: (context, isValidPinCode) {
          return BBButton.big(
            label: 'Confirm',
            textStyle: context.font.headlineLarge,
            disabled: !isValidPinCode,
            bgColor: isValidPinCode
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
