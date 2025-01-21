import 'package:bb_mobile/core/presentation/widgets/page_view/bloc/page_view_bloc.dart';
import 'package:bb_mobile/features/pin_code/presentation/blocs/pin_code_setting/pin_code_setting_bloc.dart';
import 'package:bb_mobile/features/pin_code/presentation/widgets/pin_code_display.dart';
import 'package:bb_mobile/features/pin_code/presentation/widgets/shuffled_numbers_keyboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NewPinCodeScreen extends StatelessWidget {
  const NewPinCodeScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Pin Code'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            'Enter a new pin code',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          BlocSelector<PinCodeSettingBloc, PinCodeSettingState, String>(
            selector: (state) => state.pinCode,
            builder: (context, pinCode) => PinCodeDisplay(
              pinCode: pinCode,
            ),
          ),
          const SizedBox(height: 20),
          ShuffledNumbersKeyboard(
            onNumberSelected:
                context.watch<PinCodeSettingBloc>().state.canAddPinCodeNumber
                    ? (int number) => context.read<PinCodeSettingBloc>().add(
                          PinCodeSettingPinCodeChanged(
                            '${context.read<PinCodeSettingBloc>().state.pinCode}$number',
                          ),
                        )
                    : null,
            onBackspacePressed: context
                    .watch<PinCodeSettingBloc>()
                    .state
                    .canBackspacePinCode
                ? () {
                    final pinCode =
                        context.read<PinCodeSettingBloc>().state.pinCode;
                    context.read<PinCodeSettingBloc>().add(
                          PinCodeSettingPinCodeChanged(
                            pinCode.substring(
                              0,
                              pinCode.length - 1 < 0 ? 0 : pinCode.length - 1,
                            ),
                          ),
                        );
                  }
                : null,
          ),
          const SizedBox(height: 20),
          BlocSelector<PinCodeSettingBloc, PinCodeSettingState, bool>(
            selector: (state) => state.isValidPinCode,
            builder: (context, isValidPinCode) => ElevatedButton(
              onPressed: isValidPinCode
                  ? () => context.read<PageViewBloc>().add(
                        const PageViewNextPagePressed(),
                      )
                  : null,
              child: const Text('Next'),
            ),
          ),
        ],
      ),
    );
  }
}
