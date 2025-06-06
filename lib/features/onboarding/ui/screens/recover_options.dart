import 'package:bb_mobile/features/key_server/presentation/bloc/key_server_cubit.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/ui/components/cards/tag_card.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    final isSuperuser = context.select(
      (SettingsCubit cubit) => cubit.state.isSuperuser ?? false,
    );
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () => context.pop(),
          title: 'Recover your wallet',
        ),
      ),
      body: BlocProvider(
        create: (context) => locator<KeyServerCubit>(),
        child: BlocBuilder<KeyServerCubit, KeyServerState>(
          builder: (context, state) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Gap(20),
                    BBText(
                      'Without a backup, you will eventually lose access to your money. It is critically important to do a backup.',
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: context.font.bodyLarge,
                    ),
                    const Gap(16),
                    if (isSuperuser) ...[
                      BackupOptionCard(
                        icon: Image.asset(
                          'assets/encrypted_vault.png',
                          width: 36,
                          height: 45,
                          fit: BoxFit.cover,
                        ),
                        title: 'Encrypted vault',
                        description:
                            'Anonymous backup with strong encryption using your cloud.',
                        tag: 'Easy and simple (1 minute)',
                        onTap:
                            () => {
                              context.read<KeyServerCubit>().checkConnection(),
                              context.pushNamed(
                                OnboardingRoute
                                    .chooseRecoverProvider
                                    .name, // ChooseVaultProviderScreen
                                extra: true,
                              ),
                            },
                      ),
                      const Gap(16),
                    ],
                    BackupOptionCard(
                      icon: Image.asset(
                        'assets/physical_backup.png',
                        width: 36,
                        height: 45,
                        fit: BoxFit.cover,
                      ),
                      title: 'Physical backup',
                      description:
                          'Write down 12 words on a piece of paper. Keep them safe and make sure not to lose them.',
                      tag: 'Trustless (take your time)',
                      onTap:
                          () => context.pushNamed(
                            OnboardingRoute.recoverFromPhysical.name,
                          ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class BackupOptionCard extends StatelessWidget {
  final Widget icon;
  final String title;
  final String description;
  final String tag;
  final VoidCallback onTap;

  const BackupOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.tag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: context.colour.surface),
          boxShadow: [
            BoxShadow(
              color: context.colour.surface,
              offset: const Offset(0, 2),
            ),
          ],
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 6,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 36, height: 45, child: icon),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BBText(title, style: context.font.headlineMedium),
                        const Gap(10),
                        BBText(
                          description,
                          style: context.font.bodySmall?.copyWith(
                            color: context.colour.outline,
                          ),
                          maxLines: 3,
                        ),
                        const Gap(10),
                        OptionsTag(text: tag),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 24,
              height: 24,
              child: Icon(Icons.arrow_forward, color: context.colour.secondary),
            ),
          ],
        ),
      ),
    );
  }
}
