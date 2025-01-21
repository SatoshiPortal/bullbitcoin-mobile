import 'package:bb_mobile/core/presentation/widgets/page_view/bloc/page_view_bloc.dart';
import 'package:bb_mobile/features/pin_code/presentation/blocs/pin_code_setting/pin_code_setting_bloc.dart';
import 'package:bb_mobile/features/pin_code/presentation/widgets/pin_code_display.dart';
import 'package:bb_mobile/features/pin_code/presentation/widgets/shuffled_numbers_keyboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NewPinCodeConfirmationScreen extends StatelessWidget {
  const NewPinCodeConfirmationScreen({
    super.key,
  });

  void _backHandler(BuildContext context) {
    context.read<PageViewBloc>().add(
          const PageViewPreviousPagePressed(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }
        _backHandler(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Confirm Pin Code'),
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _backHandler(context),
          ),
        ),
        body: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              'Re-enter the new pin code',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            BlocSelector<PinCodeSettingBloc, PinCodeSettingState, String>(
              selector: (state) => state.pinCodeConfirmation,
              builder: (context, pinCode) => PinCodeDisplay(
                pinCode: pinCode,
              ),
            ),
            const SizedBox(height: 20),
            ShuffledNumbersKeyboard(
              onNumberSelected: context
                      .watch<PinCodeSettingBloc>()
                      .state
                      .canAddPinCodeConfirmationNumber
                  ? (int number) => context.read<PinCodeSettingBloc>().add(
                        PinCodeSettingPinCodeConfirmationChanged(
                          '${context.read<PinCodeSettingBloc>().state.pinCodeConfirmation}$number',
                        ),
                      )
                  : null,
              onBackspacePressed: context
                      .watch<PinCodeSettingBloc>()
                      .state
                      .canBackspacePinCodeConfirmation
                  ? () {
                      final pinCode = context
                          .read<PinCodeSettingBloc>()
                          .state
                          .pinCodeConfirmation;
                      context.read<PinCodeSettingBloc>().add(
                            PinCodeSettingPinCodeConfirmationChanged(
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
              selector: (state) => state.canSubmit,
              builder: (context, canSubmit) => ElevatedButton(
                onPressed: canSubmit
                    ? () => context.read<PinCodeSettingBloc>().add(
                          const PinCodeSettingSubmitted(),
                        )
                    : null,
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
