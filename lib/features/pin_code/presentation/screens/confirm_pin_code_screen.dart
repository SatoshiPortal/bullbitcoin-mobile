import 'package:bb_mobile/features/pin_code/presentation/blocs/pin_code_setting/pin_code_setting_bloc.dart';
import 'package:bb_mobile/features/pin_code/presentation/widgets/numeric_keyboard.dart';
import 'package:bb_mobile/features/pin_code/presentation/widgets/pin_code_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ConfirmPinCodeScreen extends StatelessWidget {
  const ConfirmPinCodeScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    void backHandler() {
      context.read<PinCodeSettingBloc>().add(
            const PinCodeSettingStarted(),
          );
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
          title: const Text('Confirm Pin Code'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => backHandler(),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    children: [
                      Text(
                        'Re-enter the new pin code',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 60),
                      BlocSelector<PinCodeSettingBloc, PinCodeSettingState,
                          String>(
                        selector: (state) => state.pinCodeConfirmation,
                        builder: (context, pinCode) {
                          return PinCodeDisplay(
                            pinCode: pinCode,
                          );
                        },
                      ),
                      const SizedBox(height: 60),
                      BlocSelector<PinCodeSettingBloc, PinCodeSettingState,
                          List<int>>(
                        selector: (state) => state.confirmPinKeyboardNumbers,
                        builder: (context, keyboardNumbers) {
                          return NumericKeyboard(
                            numbers: keyboardNumbers,
                            onNumberPressed: (number) =>
                                context.read<PinCodeSettingBloc>().add(
                                      PinCodeSettingPinCodeConfirmationNumberAdded(
                                          number),
                                    ),
                            onBackspacePressed: () =>
                                context.read<PinCodeSettingBloc>().add(
                                      const PinCodeSettingPinCodeConfirmationNumberRemoved(),
                                    ),
                          );
                        },
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BlocSelector<PinCodeSettingBloc, PinCodeSettingState, bool>(
                      selector: (state) => state.canConfirm,
                      builder: (context, canConfirm) {
                        return ElevatedButton(
                          onPressed: canConfirm
                              ? () => context.read<PinCodeSettingBloc>().add(
                                    const PinCodeSettingPinCodeConfirmed(),
                                  )
                              : null,
                          child: const Text('Confirm'),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
