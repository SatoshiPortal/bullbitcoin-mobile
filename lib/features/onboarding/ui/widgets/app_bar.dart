import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class OnboardingAppBar extends StatelessWidget implements PreferredSizeWidget {
  const OnboardingAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: context.colour.primary,
      flexibleSpace: TopBar(
        title: context.loc.onboardingRecoverWallet,
        onBack: () {
          context.read<OnboardingBloc>().add(const OnboardingGoBack());
          context.pop();
        },
      ),
      automaticallyImplyLeading: false,
      forceMaterialTransparency: true,
    );
  }

  @override
  Size get preferredSize => const Size(double.maxFinite, kToolbarHeight);
}
