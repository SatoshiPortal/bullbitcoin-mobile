import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/dialpad/dial_pad.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/authentication/presentation/unlock/app_unlock_bloc.dart';
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
            title: context.loc.appUnlockScreenTitle,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      crossAxisAlignment: .stretch,
                      children: [
                        const Gap(30),
                        Text(
                          context.loc.appUnlockEnterPinMessage,
                          textAlign: .center,
                          style: context.font.headlineMedium?.copyWith(
                            color: context.appColors.outline,
                          ),
                          maxLines: 3,
                        ),
                        const Gap(30),
                        BlocSelector<
                          AppUnlockBloc,
                          AppUnlockState,
                          (String, bool)
                        >(
                          selector: (state) =>
                              (state.pinCode, state.obscurePinCode),
                          builder: (context, data) {
                            final (pinCode, obscurePinCode) = data;
                            return BBInputText(
                              value: pinCode,
                              obscure: obscurePinCode,
                              onRightTap: () => context
                                  .read<AppUnlockBloc>()
                                  .add(AppUnlockPinCodeObscureToggled()),
                              rightIcon: const Icon(
                                Icons.visibility_off_outlined,
                              ),
                              onlyNumbers: true,
                              onChanged: (value) {},
                            );
                          },
                        ),
                        const Gap(2),
                        BlocSelector<
                          AppUnlockBloc,
                          AppUnlockState,
                          (bool, int)
                        >(
                          selector: (state) =>
                              (state.showError, state.failedAttempts),
                          builder: (context, data) {
                            final (showError, failedAttempts) = data;
                            return showError && failedAttempts > 0
                                ? Text(
                                    context.loc.appUnlockIncorrectPinError(
                                      failedAttempts,
                                      failedAttempts == 1
                                          ? context.loc.appUnlockAttemptSingular
                                          : context.loc.appUnlockAttemptPlural,
                                    ),
                                    textAlign: .start,
                                    style: context.font.labelSmall?.copyWith(
                                      color: context.appColors.error,
                                    ),
                                  )
                                : const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: DialPad(
                  disableFeedback: true,
                  onlyDigits: true,
                  onNumberPressed: (value) => context.read<AppUnlockBloc>().add(
                    AppUnlockPinCodeNumberAdded(int.parse(value)),
                  ),
                  onBackspacePressed: () => context.read<AppUnlockBloc>().add(
                    const AppUnlockPinCodeNumberRemoved(),
                  ),
                ),
              ),
              const Gap(16),
            ],
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
                  label: context.loc.appUnlockButton,
                  textStyle: context.font.headlineLarge,
                  disabled: !canSubmit,
                  bgColor: canSubmit
                      ? context.appColors.secondary
                      : context.appColors.outline,
                  onPressed: () {
                    if (canSubmit) {
                      context.read<AppUnlockBloc>().add(
                        const AppUnlockSubmitted(),
                      );
                    }
                  },
                  textColor: context.appColors.onSecondary,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
