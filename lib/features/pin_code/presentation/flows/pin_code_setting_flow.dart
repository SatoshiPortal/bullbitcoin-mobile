import 'package:bb_mobile/core/locator/di_initializer.dart';
import 'package:bb_mobile/core/presentation/widgets/page_view/bloc/page_view_bloc.dart';
import 'package:bb_mobile/core/presentation/widgets/page_view/page_view_with_bloc.dart';
import 'package:bb_mobile/features/pin_code/presentation/blocs/pin_code_setting/pin_code_setting_bloc.dart';
import 'package:bb_mobile/features/pin_code/presentation/screens/pin_code_input_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PinCodeSettingFlow extends StatelessWidget {
  const PinCodeSettingFlow({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => locator<PinCodeSettingBloc>(),
      child: BlocBuilder<PinCodeSettingBloc, PinCodeSettingState>(
        builder: (context, state) {
          final status = state.status;
          switch (status) {
            case PinCodeSettingStatus.initial:
              return PageViewWithBloc(
                pages: [
                  PinCodeInputScreen(
                    pinCode: state.pinCode,
                    onKey: (String key) =>
                        context.read<PinCodeSettingBloc>().add(
                              PinCodeSettingPinCodeChanged(state.pinCode + key),
                            ),
                    onBackspace: () => context.read<PinCodeSettingBloc>().add(
                          PinCodeSettingPinCodeChanged(
                            state.pinCode.substring(
                              0,
                              state.pinCode.length - 1 ?? 0,
                            ),
                          ),
                        ),
                    onSubmit: () => context.read<PageViewBloc>().add(
                          const PageViewNextPagePressed(),
                        ),
                  ), // Input new pin
                  PinCodeInputScreen(
                    pinCode: state.pinCodeConfirmation,
                    onKey: (String key) =>
                        context.read<PinCodeSettingBloc>().add(
                              PinCodeSettingPinCodeConfirmationChanged(
                                state.pinCodeConfirmation + key,
                              ),
                            ),
                    onBackspace: () => context.read<PinCodeSettingBloc>().add(
                          PinCodeSettingPinCodeConfirmationChanged(
                            state.pinCodeConfirmation.substring(
                              0,
                              state.pinCodeConfirmation.length - 1 ?? 0,
                            ),
                          ),
                        ),
                    onSubmit: () => context.read<PinCodeSettingBloc>().add(
                          const PinCodeSettingSubmitted(),
                        ),
                  ), // Confirm new pin
                ],
              );
            case PinCodeSettingStatus.loading:
              // TODO: Use correct loading screen
              return const CircularProgressIndicator();
            case PinCodeSettingStatus.success:
              // TODO: Use correct success screen
              // If a different success text is needed for creation and change,
              //  use a different success status for each
              return const Text('Pin Code Set Successfully');
            case PinCodeSettingStatus.failure:
              // TODO: Use correct failure screen
              return const Text('Pin Code Set Failed');
          }
        },
      ),
    );
  }
}
