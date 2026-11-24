import 'package:onboarding/src/onboarding_l10n.dart';
import 'package:onboarding/src/onboarding_navigation.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullBackupOptionCard, BullTopBar, Gap;
import 'package:go_router/go_router.dart';

class OnboardingRecoverOptions extends StatefulWidget {
  const OnboardingRecoverOptions({
    super.key,
    required this.encryptedBackupIcon,
    required this.physicalBackupIcon,
  });

  final ImageProvider encryptedBackupIcon;
  final ImageProvider physicalBackupIcon;

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
        flexibleSpace: BullTopBar(
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
            BullBackupOptionCard(
              icon: Image(image: widget.encryptedBackupIcon, fit: .contain),
              title: context.loc.onboardingEncryptedVault,
              description: context.loc.onboardingEncryptedVaultDescription,
              onTap: () => {
                RecoverBullFeature.open(context, RecoverBullFlow.recoverVault),
              },
            ),
            const Gap(16),
            BullBackupOptionCard(
              icon: Image(image: widget.physicalBackupIcon, fit: .contain),
              title: context.loc.onboardingPhysicalBackup,
              description: context.loc.onboardingPhysicalBackupDescription,

              onTap: () => OnboardingNavigation.openPhysicalRecovery(context),
            ),
          ],
        ),
      ),
    );
  }
}
