import 'package:access/src/access_l10n.dart';
import 'package:access/src/presentation/bloc/pin_code_setting_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class ChoosePinCodeScreen extends StatelessWidget {
  const ChoosePinCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bull.surface,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: BullTopBar(
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
                        style: context.bullType.subtitle
                            .copyWith(fontWeight: FontWeight.w500)
                            .copyWith(color: context.bull.onSurface),
                        maxLines: 3,
                      ),
                      const Gap(16),
                      Text(
                        context.loc.pinCodeCreateDescription,
                        textAlign: .center,
                        style: context.bullType.body.copyWith(
                          color: context.bull.onSurface,
                        ),
                      ),
                      const Gap(30),
                      BlocSelector<
                        PinCodeSettingBloc,
                        PinCodeSettingState,
                        (String, bool, int, int)
                      >(
                        selector: (state) => (
                          state.pinCode,
                          state.obscurePinCode,
                          state.minPinCodeLength,
                          state.maxPinCodeLength,
                        ),
                        builder: (context, data) {
                          final (pinCode, obscurePinCode, min, max) = data;
                          return BullPinDots(
                            showLabel: context.loc.pinCodeShowPin,
                            hint: context.loc.pinCodeLengthHint(min, max),
                            hideLabel: context.loc.pinCodeHidePin,
                            value: pinCode,
                            obscure: obscurePinCode,
                            semanticLabel: context.loc.pinCodeCreateTitle,
                            onToggleObscure: () =>
                                context.read<PinCodeSettingBloc>().add(
                                  const PinCodeSettingPinCodeObscureToggled(),
                                ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: BullPinPad(
                scrambleHint: context.loc.pinCodeScrambleKeypadHint,
                onDigit: (digit) => context.read<PinCodeSettingBloc>().add(
                  PinCodeSettingPinCodeNumberAdded(digit),
                ),
                onBackspace: () => context.read<PinCodeSettingBloc>().add(
                  const PinCodeSettingPinCodeNumberRemoved(),
                ),
              ),
            ),
            const Gap(32),
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
          return BullButton.primary(
            label: context.loc.pinCodeContinue,
            textStyle: context.bullType.subtitle.copyWith(
              fontWeight: FontWeight.w700,
            ),
            onPressed: (!isValidPinCode)
                ? null
                : () {
                    if (isValidPinCode) {
                      context.read<PinCodeSettingBloc>().add(
                        const PinCodeSettingPinCodeChosen(),
                      );
                    }
                  },
          );
        },
      ),
    );
  }
}
