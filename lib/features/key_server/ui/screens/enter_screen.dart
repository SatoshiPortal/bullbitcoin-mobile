import 'package:bb_mobile/core/recoverbull/domain/entity/key_server.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/dialpad/dial_pad.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart' show TopBar;
import 'package:bb_mobile/core/widgets/template/screen_template.dart';
import 'package:bb_mobile/core/widgets/text/text.dart' show BBText;
import 'package:bb_mobile/features/key_server/presentation/bloc/key_server_cubit.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class EnterScreen extends StatelessWidget {
  const EnterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.select((KeyServerCubit x) => x.state);
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () => context.go(WalletRoute.walletHome.path),
          title:
              "Choose access ${state.authInputType == AuthInputType.pin ? 'PIN' : 'password'}",
        ),
      ),
      body: StackedPage(
        bottomChild: const ConfirmButton(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BBText(
                'You must memorize this ${state.authInputType == AuthInputType.pin ? 'PIN' : 'password'} to recover access to your wallet. It must be at least 6 digits. If you lose this ${state.authInputType == AuthInputType.pin ? 'PIN' : 'password'} you cannot recover your backup.',
                textAlign: TextAlign.center,
                style: context.font.labelMedium?.copyWith(
                  color: context.colour.outline,
                ),
                maxLines: 3,
              ),
              const Gap(60),
              if (state.authInputType == AuthInputType.password)
                BBText(
                  'Password',
                  textAlign: TextAlign.start,
                  style: context.font.labelSmall?.copyWith(
                    color: context.colour.secondary,
                  ),
                )
              else
                const SizedBox.shrink(),
              const Gap(2),
              BBInputText(
                value: state.password,
                obscure: state.isPasswordObscured,
                onRightTap:
                    () => context.read<KeyServerCubit>().toggleObscure(),
                rightIcon:
                    state.isPasswordObscured
                        ? const Icon(Icons.visibility_off_outlined)
                        : const Icon(Icons.visibility_outlined),
                onlyPaste: state.authInputType == AuthInputType.pin,
                onChanged: (String value) {
                  if (state.authInputType == AuthInputType.password) {
                    context.read<KeyServerCubit>().enterKey(value);
                  }
                },
              ),
              const Gap(2),
              if (state.isInCommonPasswordList)
                BBText(
                  'This ${(state.authInputType == AuthInputType.pin) ? 'PIN' : 'Password'} is too common. Please choose a different one.',
                  textAlign: TextAlign.start,
                  style: context.font.labelSmall?.copyWith(
                    color: context.colour.error,
                  ),
                )
              else if (!state.hasValidPasswordLength)
                BBText(
                  '${(state.authInputType == AuthInputType.pin) ? 'PIN' : 'Password'} must be at least 6 digits long',
                  textAlign: TextAlign.start,
                  style: context.font.labelSmall?.copyWith(
                    color: context.colour.error,
                  ),
                )
              else
                const SizedBox.shrink(),
              const Gap(72),
              BBButton.small(
                label:
                    'Pick a ${state.authInputType == AuthInputType.pin ? 'password' : 'pin'} instead >>',
                bgColor: Colors.transparent,
                textColor: context.colour.inversePrimary,
                textStyle: context.font.labelSmall,
                onPressed:
                    () => context.read<KeyServerCubit>().toggleAuthInputType(
                      state.authInputType == AuthInputType.pin
                          ? AuthInputType.password
                          : AuthInputType.pin,
                    ),
              ),
              if (state.authInputType == AuthInputType.pin)
                DialPad(
                  disableFeedback: true,
                  onNumberPressed:
                      (e) => context.read<KeyServerCubit>().enterKey(e),
                  onBackspacePressed:
                      () => context.read<KeyServerCubit>().backspaceKey(),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}

class ConfirmButton extends StatelessWidget {
  const ConfirmButton({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.select((KeyServerCubit x) => x.state);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: BBButton.big(
        label: 'Confirm',
        textStyle: context.font.headlineLarge,
        disabled: !state.canProceed,
        bgColor:
            state.canProceed
                ? context.colour.secondary
                : context.colour.outline,
        onPressed: () {
          if (state.canProceed) {
            context.read<KeyServerCubit>().confirmKey();
          }
        },
        textColor: context.colour.onSecondary,
      ),
    );
  }
}
