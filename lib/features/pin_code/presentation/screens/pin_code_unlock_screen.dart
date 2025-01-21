import 'package:bb_mobile/core/locator/di_initializer.dart';
import 'package:bb_mobile/features/pin_code/presentation/blocs/pin_code_unlock/pin_code_unlock_bloc.dart';
import 'package:bb_mobile/features/pin_code/presentation/screens/pin_code_input_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PinCodeUnlockScreen extends StatelessWidget {
  const PinCodeUnlockScreen({super.key, required this.onSuccess});

  final void Function() onSuccess;

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
            onKey: (int key) => context.read<PinCodeUnlockBloc>().add(
                  PinCodeUnlockPinChanged('${state.pinCode}$key'),
                ),
            disableKeys: !state.canAddNumber,
            onBackspace: () => context.read<PinCodeUnlockBloc>().add(
                  PinCodeUnlockPinChanged(
                    state.pinCode.substring(
                      0,
                      state.pinCode.length - 1 < 0
                          ? 0
                          : state.pinCode.length - 1,
                    ),
                  ),
                ),
            disableBackspace: !state.canBackspace,
            submitButtonLabel: "Unlock",
            onSubmit: () => context.read<PinCodeUnlockBloc>().add(
                  const PinCodeUnlockSubmitted(),
                ),
            disableSubmit: !state.canSubmit,
            timeoutSeconds: state.timeoutSeconds,
            failedAttempts: state.failedAttempts,
          ),
        ),
      ),
    );
  }
}
