import 'package:bb_mobile/core/locator/di_initializer.dart';
import 'package:bb_mobile/features/pin_code/presentation/blocs/pin_code_unlock/pin_code_unlock_bloc.dart';
import 'package:bb_mobile/features/pin_code/presentation/widgets/numeric_keyboard.dart';
import 'package:bb_mobile/features/pin_code/presentation/widgets/pin_code_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PinCodeUnlockScreen extends StatelessWidget {
  const PinCodeUnlockScreen({
    super.key,
    required this.onSuccess,
    this.canPop = false,
  });

  final void Function() onSuccess;
  final bool canPop;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => locator<PinCodeUnlockBloc>()
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
        child: PinCodeUnlockInputScreen(
          onSuccess: onSuccess,
          canPop: canPop,
        ),
      ),
    );
  }
}

class PinCodeUnlockInputScreen extends StatelessWidget {
  const PinCodeUnlockInputScreen({
    super.key,
    required this.onSuccess,
    this.canPop = false,
  });

  final void Function() onSuccess;
  final bool canPop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: canPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pin lock'),
          automaticallyImplyLeading: canPop,
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Enter your pin code to unlock',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            BlocSelector<PinCodeUnlockBloc, PinCodeUnlockState, String>(
              selector: (state) => state.pinCode,
              builder: (context, pinCode) {
                return PinCodeDisplay(
                  pinCode: pinCode,
                );
              },
            ),
            const SizedBox(height: 20),
            BlocSelector<PinCodeUnlockBloc, PinCodeUnlockState, List<int>>(
              selector: (state) => state.keyboardNumbers,
              builder: (context, keyboardNumbers) {
                return NumericKeyboard(
                  numbers: keyboardNumbers,
                  onNumberPressed: (number) {
                    context.read<PinCodeUnlockBloc>().add(
                          PinCodeUnlockNumberAdded(number),
                        );
                  },
                  onBackspacePressed: () {
                    context.read<PinCodeUnlockBloc>().add(
                          const PinCodeUnlockNumberRemoved(),
                        );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            BlocSelector<PinCodeUnlockBloc, PinCodeUnlockState, bool>(
              selector: (state) => state.canSubmit,
              builder: (context, canSubmit) {
                return ElevatedButton(
                  onPressed: canSubmit
                      ? () => context.read<PinCodeUnlockBloc>().add(
                            const PinCodeUnlockSubmitted(),
                          )
                      : null,
                  child: const Text('Unlock'),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
