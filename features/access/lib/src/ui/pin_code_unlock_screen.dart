import 'package:access/src/access_l10n.dart';
import 'package:access/src/presentation/access_failure_l10n.dart';
import 'package:access/src/presentation/bloc/app_unlock_bloc.dart';
import 'package:access/src/locator.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class PinCodeUnlockScreen extends StatelessWidget {
  const PinCodeUnlockScreen({
    super.key,
    required this.onSuccess,
    this.canPop = false,
  });

  final VoidCallback onSuccess;
  final bool canPop;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          accessLocator<AppUnlockBloc>()..add(const AppUnlockStarted()),
      child: BlocListener<AppUnlockBloc, AppUnlockState>(
        listenWhen: (previous, current) =>
            previous.timeoutSeconds != current.timeoutSeconds ||
            previous.status != current.status,
        listener: (context, state) async {
          if (state.status == AppUnlockStatus.failure) {
            if (state.failure case final failure?) {
              BullSnackBar.show(
                context,
                message: failure.toTranslated(context),
              );
            }
          } else if (state.status == AppUnlockStatus.success) {
            onSuccess();
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
        backgroundColor: context.bull.surface,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: BullTopBar(
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
                          style: context.bullType.subtitle
                              .copyWith(fontWeight: FontWeight.w500)
                              .copyWith(color: context.bull.onSurface),
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
                            return BullPinDots(
                              showLabel: context.loc.pinCodeShowPin,
                              hideLabel: context.loc.pinCodeHidePin,
                              value: pinCode,
                              obscure: obscurePinCode,
                              semanticLabel:
                                  context.loc.appUnlockEnterPinMessage,
                              onToggleObscure: () => context
                                  .read<AppUnlockBloc>()
                                  .add(AppUnlockPinCodeObscureToggled()),
                            );
                          },
                        ),
                        const Gap(2),
                        BlocSelector<
                          AppUnlockBloc,
                          AppUnlockState,
                          (bool, int, int)
                        >(
                          selector: (state) => (
                            state.showError,
                            state.failedAttempts,
                            state.timeoutSeconds,
                          ),
                          builder: (context, data) {
                            final (showError, failedAttempts, timeoutSeconds) =
                                data;
                            // During a cooldown the countdown replaces the
                            // incorrect-PIN line: the last attempt was never
                            // verified, so calling it incorrect would leak
                            // nothing but confuse the user.
                            if (timeoutSeconds > 0) {
                              return Text(
                                context.loc.appUnlockTryAgainIn(timeoutSeconds),
                                textAlign: .start,
                                style: context.bullType.caption.copyWith(
                                  color: context.bull.error,
                                ),
                              );
                            }
                            return showError && failedAttempts > 0
                                ? Text(
                                    context.loc.appUnlockIncorrectPinError(
                                      failedAttempts,
                                      failedAttempts == 1
                                          ? context.loc.appUnlockAttemptSingular
                                          : context.loc.appUnlockAttemptPlural,
                                    ),
                                    textAlign: .start,
                                    style: context.bullType.caption.copyWith(
                                      color: context.bull.error,
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
                child: BlocSelector<AppUnlockBloc, AppUnlockState, bool>(
                  selector: (state) =>
                      state.timeoutSeconds == 0 && !state.isVerifying,
                  builder: (context, padEnabled) {
                    return BullPinPad(
                      scrambleHint: context.loc.pinCodeScrambleKeypadHint,
                      enabled: padEnabled,
                      onDigit: (digit) => context.read<AppUnlockBloc>().add(
                        AppUnlockPinCodeNumberAdded(digit),
                      ),
                      onBackspace: () => context.read<AppUnlockBloc>().add(
                        const AppUnlockPinCodeNumberRemoved(),
                      ),
                    );
                  },
                ),
              ),
              const Gap(32),
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
                return BullButton.primary(
                  label: context.loc.appUnlockButton,
                  textStyle: context.bullType.subtitle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  onPressed: (!canSubmit)
                      ? null
                      : () {
                          if (canSubmit) {
                            context.read<AppUnlockBloc>().add(
                              const AppUnlockSubmitted(),
                            );
                          }
                        },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
