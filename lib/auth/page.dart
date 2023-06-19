import 'package:bb_mobile/_pkg/extensions.dart';
import 'package:bb_mobile/_pkg/storage.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/auth/bloc/cubit.dart';
import 'package:bb_mobile/auth/bloc/state.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key, required this.fromSettings});

  final bool fromSettings;

  @override
  Widget build(BuildContext context) {
    final authCubit = AuthCubit(
      storage: locator<IStorage>(),
      fromSettings: fromSettings,
    );

    return BlocProvider.value(
      value: authCubit,
      child: BlocListener<AuthCubit, AuthState>(
        listenWhen: (previous, current) =>
            previous.loggedIn != current.loggedIn,
        listener: (context, state) async {
          if (state.loggedIn) {
            if (!state.fromSettings) {
              locator<HomeCubit>().getWalletsFromStorage();
              context.go('/home');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: BBText.body('Pin Changed'),
                ),
              );
              context.pop();
            }
          }
        },
        child: const _Screen(),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    final starting = context.select((AuthCubit x) => x.state.onStartChecking);
    final fromSettings = context.select((AuthCubit x) => x.state.fromSettings);

    return Scaffold(
      appBar: !fromSettings
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              flexibleSpace: BBAppBar(
                text: 'Authentication',
                onBack: () {
                  context.pop();
                },
              ),
            ),
      body: SingleChildScrollView(
        child: starting
            ? Container()
            : const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Gap(60),
                    AuthTitleText(),
                    Gap(48),
                    AuthPasswordField(),
                    AuthKeyPad(),
                    Gap(24),
                    AuthConfirmButton(),
                  ],
                ),
              ).animate(delay: 1000.milliseconds).fade(),
      ),
    );
  }
}

class AuthPasswordField extends StatelessWidget {
  const AuthPasswordField({super.key});

  @override
  Widget build(BuildContext context) {
    final pin = context.select((AuthCubit x) => x.state.displayPin());
    final _ = context.select((AuthCubit x) => x.state.err.isNotEmpty);

    return Row(
      children: [
        const SizedBox(width: 40),
        Expanded(
          child: Center(
            child: BBText.titleLarge(
              pin,
              isBold: true,
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: IconButton(
            iconSize: 32,
            color: pin.isEmpty
                ? context.colour.surface
                : context.colour.onBackground,
            onPressed: () {
              SystemSound.play(SystemSoundType.click);
              HapticFeedback.mediumImpact();

              context.read<AuthCubit>().backspacePressed();
            },
            icon: const FaIcon(FontAwesomeIcons.deleteLeft),
          ),
        ),
      ],
    );
  }
}

class AuthTitleText extends StatelessWidget {
  const AuthTitleText({super.key});

  @override
  Widget build(BuildContext context) {
    final title = context.select((AuthCubit x) => x.state.titleText());

    return Center(
      child: BBText.body(
        title,
      ),
    );
  }
}

class NumberButton extends StatefulWidget {
  const NumberButton({super.key, required this.text});

  final String text;

  @override
  State<NumberButton> createState() => _NumberButtonState();
}

class _NumberButtonState extends State<NumberButton> {
  bool isRed = false;

  @override
  Widget build(BuildContext context) {
    final _ = OutlinedButton.styleFrom(
      shape: const CircleBorder(),
      backgroundColor: context.colour.onBackground,
      foregroundColor: context.colour.primary,
    );

    final __ = OutlinedButton.styleFrom(
      shape: const CircleBorder(),
      backgroundColor: context.colour.primary,
      foregroundColor: context.colour.background,
    );

    return Center(
      child: SizedBox(
        height: 80,
        width: 80,
        child: GestureDetector(
          onTapUp: (e) {
            setState(() {
              isRed = false;
            });
          },
          onTapDown: (e) {
            setState(() {
              isRed = true;
            });
          },
          onTapCancel: () {
            setState(() {
              isRed = false;
            });
          },
          child: OutlinedButton(
            onPressed: () {
              SystemSound.play(SystemSoundType.click);
              HapticFeedback.mediumImpact();

              context.read<AuthCubit>().keyPressed(widget.text);
            },
            child: BBText.titleLarge(
              widget.text,
              isBold: true,
            ),
          ).animate().blur(
                begin: const Offset(1, 1),
                end: isRed ? const Offset(2, 2) : Offset.zero,
              ),
        ),
      ),
    );
  }
}

class AuthKeyPad extends StatelessWidget {
  const AuthKeyPad({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.55,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ),
        child: GridView(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
          ),
          children: [
            for (var i = 1; i < 10; i = i + 1) ...[
              NumberButton(text: i.toString()),
            ],
            Container(),
            const NumberButton(text: '0'),
            Container(),
          ],
        ),
      ),
    );
  }
}

class AuthConfirmButton extends StatelessWidget {
  const AuthConfirmButton({super.key});

  @override
  Widget build(BuildContext context) {
    final showButton = context.select((AuthCubit x) => x.state.showButton());
    final err = context.select((AuthCubit x) => x.state.err);

    if (err.isNotEmpty)
      return Center(
        child: BBText.body(
          err,
        ),
      );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.6,
        child: BBButton.bigRed(
          disabled: !showButton,
          onPressed: () {
            if (showButton) context.read<AuthCubit>().confirmPressed();
          },
          label: 'auth.button'.translate,
        ),
      ),
    );
  }
}
