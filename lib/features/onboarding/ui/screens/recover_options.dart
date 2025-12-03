import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/cards/backup_option_card.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class OnboardingRecoverOptions extends StatefulWidget {
  const OnboardingRecoverOptions({super.key});

  @override
  State<OnboardingRecoverOptions> createState() =>
      _OnboardingRecoverOptionsState();
}

class _OnboardingRecoverOptionsState extends State<OnboardingRecoverOptions> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () => context.pop(),
          title: context.loc.onboardingRecoverYourWallet,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            const Gap(16),
            BackupOptionCard(
              icon: Image.asset(
                Assets.misc.encryptedVault.path,
                fit: .contain,
              ),
              title: context.loc.onboardingEncryptedVault,
              description: context.loc.onboardingEncryptedVaultDescription,
              onTap:
                  () => {
                    context.pushNamed(
                      RecoverBullRoute.recoverbullFlows.name,
                      extra: RecoverBullFlowsExtra(
                        flow: RecoverBullFlow.recoverVault,
                        vault: null,
                      ),
                    ),
                  },
            ),
            const Gap(16),
            BackupOptionCard(
              icon: Image.asset(
                Assets.misc.physicalBackup.path,
                fit: .contain,
              ),
              title: context.loc.onboardingPhysicalBackup,
              description: context.loc.onboardingPhysicalBackupDescription,

              onTap:
                  () => context.pushNamed(
                    OnboardingRoute.recoverFromPhysical.name,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
