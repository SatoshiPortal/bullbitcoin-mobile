import 'package:bb_mobile/core/locator/di_initializer.dart';
import 'package:bb_mobile/features/pin_code/presentation/blocs/pin_code_unlock/pin_code_unlock_bloc.dart';
import 'package:bb_mobile/features/pin_code/presentation/screens/pin_code_input_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PinCodeUnlockScreen extends StatelessWidget {
  const PinCodeUnlockScreen({
    super.key,
    required this.onSuccess,
  });

  final void Function() onSuccess;

  // Function to handle key press
  void _handleOnKey(
    BuildContext context,
    String pinCode,
    int key,
    bool canAddNumber,
  ) {
    if (canAddNumber) {
      context.read<PinCodeUnlockBloc>().add(
            PinCodeUnlockPinChanged('$pinCode$key'),
          );
    }
  }

  // Function to handle backspace press
  void _handleOnBackspace(
    BuildContext context,
    String pinCode,
    bool canBackspace,
  ) {
    if (canBackspace) {
      context.read<PinCodeUnlockBloc>().add(
            PinCodeUnlockPinChanged(
              pinCode.substring(
                0,
                pinCode.length - 1 < 0 ? 0 : pinCode.length - 1,
              ),
            ),
          );
    }
  }

  // Function to handle submit
  void _handleOnSubmit(BuildContext context, bool canSubmit) {
    if (canSubmit) {
      context.read<PinCodeUnlockBloc>().add(
            const PinCodeUnlockSubmitted(),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => locator<PinCodeUnlockBloc>()
        ..add(
          const PinCodeUnlockStarted(),
        ),
      child: BlocListener<PinCodeUnlockBloc, PinCodeUnlockState>(
        listener: (context, state) async {
          if (state.status == PinCodeUnlockStatus.success) {
            onSuccess();
          } else if (state.timeoutSeconds > 0) {
            await Future.delayed(
              const Duration(seconds: 1),
              () {
                if (context.mounted) {
                  context
                      .read<PinCodeUnlockBloc>()
                      .add(const PinCodeUnlockCountdownTick());
                }
              },
            );
          }
        },
        child: BlocBuilder<PinCodeUnlockBloc, PinCodeUnlockState>(
          builder: (context, state) => PinCodeInputScreen(
            pinCode: state.pinCode,
            title: "Unlock",
            subtitle: "Enter your pin code to unlock",
            onKey: (int key) => _handleOnKey(
              context,
              state.pinCode,
              key,
              state.canAddNumber,
            ),
            onBackspace: () => _handleOnBackspace(
              context,
              state.pinCode,
              state.canBackspace,
            ),
            submitButtonLabel: "Unlock",
            onSubmit: () => _handleOnSubmit(
              context,
              state.canSubmit,
            ),
            timeoutSeconds: state.timeoutSeconds,
            failedAttempts: state.failedAttempts,
          ),
        ),
      ),
    );
  }
}
