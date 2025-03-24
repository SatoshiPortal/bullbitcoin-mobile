import 'package:bb_mobile/_ui/components/buttons/button.dart';
import 'package:bb_mobile/_ui/components/dialpad/dailpad.dart';
import 'package:bb_mobile/_ui/components/inputs/secure_input.dart';
import 'package:bb_mobile/_ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:bb_mobile/key_server/presentation/bloc/key_server_cubit.dart';
import 'package:bb_mobile/key_server/ui/key_server_flow.dart';
import 'package:bb_mobile/router.dart' show AppRoute;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ConfirmScreen extends StatelessWidget {
  const ConfirmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.select((KeyServerCubit x) => x.state);
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () => context.go(AppRoute.home.path),
          title:
              "Confirm ${state.authInputType == AuthInputType.pin ? 'PIN' : 'password'}",
        ),
      ),
      body: PageLayout(
        bottomChild: const ConfirmButton(),
        bottomHeight: 80,
        children: [
          BBText(
            'Please re-enter your ${state.authInputType == AuthInputType.pin ? 'PIN' : 'password'} to confirm.',
            textAlign: TextAlign.center,
            style: context.font.labelMedium?.copyWith(
              color: context.colour.outline,
            ),
            maxLines: 2,
          ),
          const Gap(120),
          if (state.authInputType == AuthInputType.password)
            BBText(
              'Confirm Password',
              textAlign: TextAlign.start,
              style: context.font.labelSmall?.copyWith(
                color: context.colour.secondary,
              ),
            )
          else
            const SizedBox.shrink(),
          const Gap(2),
          ObscuredTextInput(
            text: state.secret,
            obscure: state.isSecretObscured,
            onVisibilityToggle: () =>
                context.read<KeyServerCubit>().toggleObscure(),
            isPassword: state.authInputType == AuthInputType.password,
            onChanged: (value) {
              if (state.authInputType == AuthInputType.password) {
                context.read<KeyServerCubit>().enterKey(value);
              }
            },
          ),
          const Gap(50),
          BBButton.big(
            label:
                'Use ${state.authInputType == AuthInputType.pin ? 'password' : 'PIN'} instead >>',
            bgColor: Colors.transparent,
            textColor: context.colour.inversePrimary,
            textStyle: context.font.labelSmall,
            onPressed: () => context.read<KeyServerCubit>().toggleAuthInputType(
                  state.authInputType == AuthInputType.pin
                      ? AuthInputType.password
                      : AuthInputType.pin,
                ),
          ),
          if (state.authInputType == AuthInputType.pin)
            DialPad(
              onTap: (e) {
                SystemSound.play(SystemSoundType.click);
                HapticFeedback.mediumImpact();
                context.read<KeyServerCubit>().enterKey(e);
              },
            )
          else
            const SizedBox.shrink(),
        ],
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
        bgColor: state.canProceed
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
