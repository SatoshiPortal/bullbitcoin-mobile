import 'package:bb_mobile/_ui/components/buttons/button.dart';
import 'package:bb_mobile/_ui/components/dialpad/dial_pad.dart';
import 'package:bb_mobile/_ui/components/inputs/text_input.dart';
import 'package:bb_mobile/_ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:bb_mobile/key_server/presentation/bloc/key_server_cubit.dart';
import 'package:bb_mobile/key_server/ui/key_server_flow.dart';
import 'package:bb_mobile/router.dart' show AppRoute;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class RecoverWithSecretScreen extends StatelessWidget {
  final bool fromOnboarding;
  const RecoverWithSecretScreen({super.key, required this.fromOnboarding});

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
              "Enter your${fromOnboarding ? '' : 'backup'} ${state.authInputType == AuthInputType.pin ? 'PIN' : 'password'}",
        ),
      ),
      body: PageLayout(
        bottomChild: const RecoverButton(),
        bottomHeight: 72,
        children: [
          if (fromOnboarding) const Gap(100) else const Gap(10),
          BBText(
            '${fromOnboarding ? 'Enter your' : 'Test to make sure you remember your backup '} ${state.authInputType == AuthInputType.pin ? 'PIN' : 'password'} ${fromOnboarding ? 'to continue' : ''}',
            textAlign: TextAlign.center,
            style: context.font.labelMedium?.copyWith(
              color: context.colour.outline,
            ),
            maxLines: 3,
          ),
          const Gap(120),
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
            onRightTap: () => context.read<KeyServerCubit>().toggleObscure(),
            rightIcon: state.isPasswordObscured
                ? const Icon(Icons.visibility_off_outlined)
                : const Icon(Icons.visibility_outlined),
            onlyNumbers: state.authInputType == AuthInputType.pin,
            onChanged: (String value) {
              if (state.authInputType == AuthInputType.password) {
                context.read<KeyServerCubit>().enterKey(value);
              }
            },
          ),
          const Gap(50),
          BBButton.small(
            label:
                'Pick ${state.authInputType == AuthInputType.pin ? 'password' : 'PIN'} instead >>',
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
              onNumberPressed: (e) =>
                  context.read<KeyServerCubit>().enterKey(e),
              onBackspacePressed: () =>
                  context.read<KeyServerCubit>().backspaceKey(),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class RecoverButton extends StatelessWidget {
  const RecoverButton({super.key});

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
            context.read<KeyServerCubit>().recoverKey();
          }
        },
        textColor: context.colour.onSecondary,
      ),
    );
  }
}
