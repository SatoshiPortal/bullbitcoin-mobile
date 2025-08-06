import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/loading/status_screen.dart';
import 'package:bb_mobile/features/app_unlock/ui/pin_code_unlock_screen.dart';
import 'package:bb_mobile/features/pin_code/presentation/bloc/pin_code_setting_bloc.dart';
import 'package:bb_mobile/features/pin_code/ui/screens/choose_pin_code_screen.dart';
import 'package:bb_mobile/features/pin_code/ui/screens/confirm_pin_code_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PinCodeSettingFlow extends StatelessWidget {
  const PinCodeSettingFlow({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => locator<PinCodeSettingBloc>(),
      child: BlocListener<PinCodeSettingBloc, PinCodeSettingState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status == PinCodeSettingStatus.success) {
            log.info('Pin Code Set Successfully');
            context.pop();
          } else if (state.status == PinCodeSettingStatus.failure) {
            log.info('Pin Code Set Failed');
          }
        },
        child: BlocSelector<
          PinCodeSettingBloc,
          PinCodeSettingState,
          PinCodeSettingStatus
        >(
          selector: (state) => state.status,
          builder: (context, status) {
            switch (status) {
              case PinCodeSettingStatus.unlock:
                return PinCodeUnlockScreen(
                  onSuccess:
                      () => context.read<PinCodeSettingBloc>().add(
                        const PinCodeSettingStarted(),
                      ),
                  canPop: true,
                );
              case PinCodeSettingStatus.choose:
                return const ChoosePinCodeScreen();
              case PinCodeSettingStatus.confirm:
                return const ConfirmPinCodeScreen();
              case PinCodeSettingStatus.success:
              case PinCodeSettingStatus.failure:
                return const StatusScreen(
                  title: 'Processing',
                  description: 'Setting up your PIN code',
                );
            }
          },
        ),
      ),
    );
  }
}
