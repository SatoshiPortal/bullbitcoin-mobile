import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/onboarding/ui/widgets/create_wallet_button.dart';
import 'package:bb_mobile/features/onboarding/ui/widgets/recover_backup_button.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:bb_mobile/ui/themes/fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class OnboardingSplash extends StatelessWidget {
  const OnboardingSplash({
    super.key,
    this.loading = false,
  });

  final bool loading;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _BG(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Spacer(
                  flex: 2,
                ),
                Image.asset(
                  Assets.bbLogoWhite.path,
                  height: 127,
                ),
                const Gap(36),
                BBText(
                  'Bull Bitcoin',
                  style: AppFonts.textTitleTheme.textStyle.copyWith(
                    fontSize: 54,
                    fontWeight: FontWeight.w500,
                    color: context.colour.onPrimary,
                    height: 1,
                  ),
                ),
                BBText(
                  'Own your Money',
                  style: AppFonts.textTitleTheme.textStyle.copyWith(
                    fontSize: 40,
                    fontWeight: FontWeight.w500,
                    color: context.colour.secondary,
                    height: 1,
                  ),
                ),
                const Gap(10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: BBText(
                    'Sovereign non-custodial Bitcoin wallet and Bitcoin-only exchange service.',
                    style: context.font.labelSmall,
                    color: context.colour.onPrimary,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                ),
                const Spacer(flex: 2),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 40,
                  ),
                  child: _Actions(
                    loading: loading,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.loading,
  });

  final bool loading;
  @override
  Widget build(BuildContext context) {
    bool creating = false;
    if (!loading) {
      creating = context.select(
        (OnboardingBloc bloc) => bloc.state.loadingCreate(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (creating || loading) ...[
          Center(
            child: CircularProgressIndicator(
              color: context.colour.onPrimary,
            ),
          ),
        ] else ...[
          const CreateWalletButton(),
          const Gap(10),
          const RecoverWalletButton(),
        ],
      ],
    );
  }
}

class _BG extends StatelessWidget {
  const _BG();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: context.colour.primary,
          height: double.infinity,
          width: double.infinity,
        ),
        Opacity(
          opacity: 0.1,
          child: Image.asset(
            Assets.images2.bgLong.path,
            fit: BoxFit.cover,
            height: double.infinity,
            width: double.infinity,
          ),
        ),
      ],
    );
  }
}
