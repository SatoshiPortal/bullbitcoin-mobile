import 'package:access/src/access_l10n.dart';
import 'package:access/src/presentation/bloc/pin_code_setting_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';

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
        if (didPop) return;
        backHandler();
      },
      child: Scaffold(
        backgroundColor: context.bull.surface,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: BullTopBar(
            onBack: backHandler,
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
                          context.loc.pinCodeConfirmTitle,
                          textAlign: .center,
                          style: context.bullType.subtitle
                              .copyWith(fontWeight: FontWeight.w500)
                              .copyWith(color: context.bull.onSurface),
                          maxLines: 3,
                        ),
                        const Gap(30),
                        BlocSelector<
                          PinCodeSettingBloc,
                          PinCodeSettingState,
                          (String, bool)
                        >(
                          selector: (state) =>
                              (state.pinCodeConfirmation, state.obscurePinCode),
                          builder: (context, data) {
                            final (pinCode, obscurePinCode) = data;
                            return BullPinDots(
                              showLabel: context.loc.pinCodeShowPin,
                              hideLabel: context.loc.pinCodeHidePin,
                              value: pinCode,
                              obscure: obscurePinCode,
                              semanticLabel: context.loc.pinCodeConfirmTitle,
                              onToggleObscure: () =>
                                  context.read<PinCodeSettingBloc>().add(
                                    const PinCodeSettingPinCodeObscureToggled(),
                                  ),
                            );
                          },
                        ),
                        const Gap(2),
                        BlocSelector<
                          PinCodeSettingBloc,
                          PinCodeSettingState,
                          bool
                        >(
                          selector: (state) => state.showConfirmationError,
                          builder: (context, showError) {
                            return showError
                                ? Text(
                                    context.loc.pinCodeMismatchError,
                                    textAlign: .start,
                                    style: context.bullType.caption.copyWith(
                                      color: context.bull.error,
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
                child: BullPinPad(
                  scrambleHint: context.loc.pinCodeScrambleKeypadHint,
                  onDigit: (digit) => context.read<PinCodeSettingBloc>().add(
                    PinCodeSettingPinCodeConfirmationNumberAdded(digit),
                  ),
                  onBackspace: () => context.read<PinCodeSettingBloc>().add(
                    const PinCodeSettingPinCodeConfirmationNumberRemoved(),
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
          return BullButton.primary(
            label: context.loc.pinCodeConfirm,
            textStyle: context.bullType.subtitle.copyWith(
              fontWeight: FontWeight.w700,
            ),
            onPressed: (!canConfirm)
                ? null
                : () {
                    if (canConfirm) {
                      context.read<PinCodeSettingBloc>().add(
                        const PinCodeSettingPinCodeConfirmed(),
                      );
                    }
                  },
          );
        },
      ),
    );
  }
}
