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
        listener: (context, state) {
          if (state.status == PinCodeUnlockStatus.success) {
            onSuccess();
          }
    );
  }
}
