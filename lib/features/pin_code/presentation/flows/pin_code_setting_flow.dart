import 'package:bb_mobile/core/locator/di_initializer.dart';
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
      create: (_) => locator<PinCodeSettingBloc>()
        ..add(
          const PinCodeSettingStarted(),
        ),
      child: BlocSelector<PinCodeSettingBloc, PinCodeSettingState,
          PinCodeSettingStatus>(
        selector: (state) => state.status,
        builder: (context, status) {
          switch (status) {
            case PinCodeSettingStatus.initial:
            case PinCodeSettingStatus.loading:
              // TODO: Use correct loading screen
              return const CircularProgressIndicator();
            case PinCodeSettingStatus.creationInProgress:
              return PageViewWithBloc(
                pages: [
                  PinCodeInputScreen(), // Input new pin
                  PinCodeInputScreen(), // Confirm new pin
                ],
              );
            case PinCodeSettingStatus.changeInProgress:
              return PageViewWithBloc(
                pages: [
                  PinCodeInputScreen(), // Input old pin
                  PinCodeInputScreen(), // Input new pin
                  PinCodeInputScreen(), // Confirm new pin
                ],
              );
            case PinCodeSettingStatus.success:
              // TODO: Use correct success screen
              // If a different success text is needed for creation and change,
              //  use a different success status for each
              throw UnimplementedError();
            case PinCodeSettingStatus.failure:
              // TODO: Use correct failure screen
              throw UnimplementedError();
          }
        },
      ),
    );
  }
}
