import 'package:bb_mobile/core/locator/di_initializer.dart';
import 'package:bb_mobile/features/app_unlock/presentation/bloc/app_unlock_bloc.dart';
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
      create: (_) => locator<AppUnlockBloc>()
        ..add(
          const AppUnlockStarted(),
        ),
      child: BlocListener<AppUnlockBloc, AppUnlockState>(
        listener: (context, state) async {
          if (state.status == AppUnlockStatus.success) {
            onSuccess();
          } else if (state.timeoutSeconds > 0) {
            await Future.delayed(
              const Duration(seconds: 1),
              () {
                if (context.mounted) {
                  context
                      .read<AppUnlockBloc>()
                      .add(const AppUnlockCountdownTick());
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
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    children: [
                      Text(
                        'Enter your pin code to unlock',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 60),
                      BlocSelector<AppUnlockBloc, AppUnlockState, String>(
                        selector: (state) => state.pinCode,
                        builder: (context, pinCode) {
                          return PinCodeDisplay(
                            pinCode: pinCode,
                          );
                        },
                      ),
                      const SizedBox(height: 60),
                      BlocSelector<AppUnlockBloc, AppUnlockState, List<int>>(
                        selector: (state) => state.keyboardNumbers,
                        builder: (context, keyboardNumbers) {
                          return NumericKeyboard(
                            numbers: keyboardNumbers,
                            onNumberPressed: (number) {
                              context.read<AppUnlockBloc>().add(
                                    AppUnlockPinCodeNumberAdded(number),
                                  );
                            },
                            onBackspacePressed: () {
                              context.read<AppUnlockBloc>().add(
                                    const AppUnlockPinCodeNumberRemoved(),
                                  );
                            },
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
                    BlocSelector<AppUnlockBloc, AppUnlockState, bool>(
                      selector: (state) => state.canSubmit,
                      builder: (context, canSubmit) {
                        return ElevatedButton(
                          onPressed: canSubmit
                              ? () => context.read<AppUnlockBloc>().add(
                                    const AppUnlockSubmitted(),
                                  )
                              : null,
                          child: const Text('Unlock'),
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
