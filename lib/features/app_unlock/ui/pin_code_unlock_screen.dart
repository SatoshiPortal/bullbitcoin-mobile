import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/dialpad/dial_pad.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/app_unlock/presentation/bloc/app_unlock_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class PinCodeUnlockScreen extends StatelessWidget {
  const PinCodeUnlockScreen({super.key, this.onSuccess, this.canPop = false});

  final void Function()? onSuccess;
  final bool canPop;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => locator<AppUnlockBloc>()..add(const AppUnlockStarted()),
      child: BlocListener<AppUnlockBloc, AppUnlockState>(
        listener: (context, state) async {
          if (state.status == AppUnlockStatus.success) {
            // If onSuccess is provided, call it, otherwise go to home as default
            onSuccess != null
                ? onSuccess!()
                : context.goNamed(WalletRoute.walletHome.name);
          } else if (state.timeoutSeconds > 0) {
            await Future.delayed(const Duration(seconds: 1), () {
              if (context.mounted) {
                context.read<AppUnlockBloc>().add(
                  const AppUnlockCountdownTick(),
                );
              }
            });
          }
        },
        child: PinCodeUnlockInputScreen(canPop: canPop),
      ),
    );
  }
}

class PinCodeUnlockInputScreen extends StatelessWidget {
  const PinCodeUnlockInputScreen({super.key, this.canPop = false});

  final bool canPop;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: canPop,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: TopBar(
            onBack: canPop ? () => context.pop() : null,
            title: "Authentication",
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Gap(75),
                  BBText(
                    'Enter your pin code to unlock',
                    textAlign: TextAlign.center,
                    style: context.font.headlineMedium?.copyWith(
                      color: context.colour.outline,
                    ),
                    maxLines: 3,
                  ),
                  const Gap(50),
                  BlocSelector<AppUnlockBloc, AppUnlockState, (String, bool)>(
                    selector: (state) => (state.pinCode, state.obscurePinCode),
                    builder: (context, data) {
                      final (pinCode, obscurePinCode) = data;
                      return BBInputText(
                        value: pinCode,
                        obscure: obscurePinCode,
                        onRightTap:
                            () => context.read<AppUnlockBloc>().add(
                              AppUnlockPinCodeObscureToggled(),
                            ),
                        rightIcon: const Icon(Icons.visibility_off_outlined),
                        onlyNumbers: true,
                        onChanged: (value) {},
                      );
                    },
                  ),
                  const Gap(130),
                  DialPad(
                    disableFeedback: true,
                    onNumberPressed:
                        (value) => context.read<AppUnlockBloc>().add(
                          AppUnlockPinCodeNumberAdded(int.parse(value)),
                        ),
                    onBackspacePressed:
                        () => context.read<AppUnlockBloc>().add(
                          const AppUnlockPinCodeNumberRemoved(),
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 10,
            ),
            child: BlocSelector<AppUnlockBloc, AppUnlockState, bool>(
              selector: (state) => state.canSubmit,
              builder: (context, canSubmit) {
                return BBButton.big(
                  label: 'Unlock',
                  textStyle: context.font.headlineLarge,
                  disabled: !canSubmit,
                  bgColor:
                      canSubmit
                          ? context.colour.secondary
                          : context.colour.outline,
                  onPressed: () {
                    if (canSubmit) {
                      context.read<AppUnlockBloc>().add(
                        const AppUnlockSubmitted(),
                      );
                    }
                  },
                  textColor: context.colour.onSecondary,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
