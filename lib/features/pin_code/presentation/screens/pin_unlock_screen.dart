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
            onKey: (String key) => context.read<PinCodeUnlockBloc>().add(
                  PinCodeUnlockPinChanged(state.pinCode + key),
                ),
            onBackspace: () => context.read<PinCodeUnlockBloc>().add(
                  PinCodeUnlockPinChanged(
                    state.pinCode.substring(
                      0,
                      state.pinCode.length - 1 ?? 0,
                    ),
                  ),
                ),
            onSubmit: () => context.read<PinCodeUnlockBloc>().add(
                  const PinCodeUnlockSubmitted(),
                ),
            timeoutSeconds: state.timeoutSeconds,
            failedAttempts: state.failedAttempts,
          ),
        ),
      ),
    );
  }
}
