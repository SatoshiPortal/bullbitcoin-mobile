import 'package:bb_mobile/features/pin_code/presentation/bloc/pin_code_setting_bloc.dart';
import 'package:bb_mobile/features/pin_code/presentation/widgets/numeric_keyboard.dart';
import 'package:bb_mobile/features/pin_code/presentation/widgets/pin_code_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChoosePinCodeScreen extends StatelessWidget {
  const ChoosePinCodeScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Pin Code'),
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
                      'Enter a new pin code',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 60),
                    BlocSelector<PinCodeSettingBloc, PinCodeSettingState,
                        String>(
                      selector: (state) => state.pinCode,
                      builder: (context, pinCode) {
                        return PinCodeDisplay(
                          pinCode: pinCode,
                        );
                      },
                    ),
                    const SizedBox(height: 60),
                    BlocSelector<PinCodeSettingBloc, PinCodeSettingState,
                        List<int>>(
                      selector: (state) => state.choosePinKeyboardNumbers,
                      builder: (context, keyboardNumbers) {
                        return NumericKeyboard(
                          numbers: keyboardNumbers,
                          onNumberPressed: (number) =>
                              context.read<PinCodeSettingBloc>().add(
                                    PinCodeSettingPinCodeNumberAdded(number),
                                  ),
                          onBackspacePressed: () =>
                              context.read<PinCodeSettingBloc>().add(
                                    const PinCodeSettingPinCodeNumberRemoved(),
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
                    selector: (state) => state.isValidPinCode,
                    builder: (context, isValidPinCode) {
                      return ElevatedButton(
                        onPressed: isValidPinCode
                            ? () => context.read<PinCodeSettingBloc>().add(
                                  const PinCodeSettingPinCodeChosen(),
                                )
                            : null,
                        child: const Text('Next'),
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
    );
  }
}
