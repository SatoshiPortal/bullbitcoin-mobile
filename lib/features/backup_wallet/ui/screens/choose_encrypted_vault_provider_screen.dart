import 'dart:ui';
import 'package:bb_mobile/core/recoverbull/data/constants/backup_providers.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/backup_provider.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/key_server.dart'
    show CurrentKeyServerFlow;
import 'package:bb_mobile/features/backup_wallet/presentation/bloc/backup_wallet_bloc.dart';
import 'package:bb_mobile/features/backup_wallet/ui/widgets/how_to_decide.dart';
import 'package:bb_mobile/features/key_server/ui/widgets/error_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/router.dart' show AppRoute;
import 'package:bb_mobile/ui/components/cards/tag_card.dart';
import 'package:bb_mobile/ui/components/loading/status_screen.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'
    show BlocConsumer, BlocProvider, ReadContext;
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ChooseVaultProviderScreen extends StatefulWidget {
  const ChooseVaultProviderScreen({super.key});

  @override
  State<ChooseVaultProviderScreen> createState() =>
      _ChooseVaultProviderScreenState();
}

class _ChooseVaultProviderScreenState extends State<ChooseVaultProviderScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => locator<BackupWalletBloc>(),
      child: const _Screen(),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BackupWalletBloc, BackupWalletState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        state.status.when(
          initial: () => {},
          loading: (type) {
            if (type == LoadingType.googleSignIn) {
              showDialog(
                context: context,
                barrierDismissible: false,
                barrierColor: Colors.white,
                builder: (_) => StatusScreen(
                  title: "You will need to sign-in to Google Drive",
                  description:
                      "Google will ask you to share personal information with this app.",
                  extras: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: "This information ",
                            style: context.font.headlineMedium,
                          ),
                          TextSpan(
                            text: "will not ",
                            style: context.font.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: "leave your phone and is ",
                            style: context.font.headlineMedium,
                          ),
                          TextSpan(
                            text: "never ",
                            style: context.font.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: "shared with Bull Bitcoin.",
                            style: context.font.headlineMedium,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
          },
          success: () {
            if (state.backupFile.isNotEmpty) {
              context.pushNamed(
                AppRoute.keyServerFlow.name,
                extra: (
                  state.backupFile,
                  CurrentKeyServerFlow.enter.toString(),
                  false
                ),
              );
            }
          },
          failure: (message) {
            showDialog(
              context: context,
              barrierDismissible: false,
              barrierColor: Colors.white,
              builder: (_) => StatusScreen(
                hasError: true,
                errorMessage: message,
                title: 'Oops! Something went wrong',
                description: message,
                buttonText: 'Close',
                onTap: () => Navigator.of(context).pop(),
              ),
            );
          },
        );
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            forceMaterialTransparency: true,
            automaticallyImplyLeading: false,
            flexibleSpace: TopBar(
              onBack: () => context.pop(),
              title: "Choose vault location",
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProviderTile(
                  provider: backupProviders[0],
                  onTap: () => context.read<BackupWalletBloc>().add(
                        const OnGoogleDriveBackupSelected(),
                      ),
                ),
                const Gap(16),
                _ProviderTile(
                  provider: backupProviders[1],
                  onTap: () {},
                ),
                const Gap(16),
                _ProviderTile(
                  provider: backupProviders[2],
                  onTap: () => context.read<BackupWalletBloc>().add(
                        const OnFileSystemBackupSelected(),
                      ),
                ),
                const Gap(16),
                _HowToDecideButton(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HowToDecideButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showHowToDecideSheet(context),
      child: BBText(
        "How to decide?",
        style: context.font.headlineLarge?.copyWith(
          color: context.colour.primary,
        ),
      ),
    );
  }

  void _showHowToDecideSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.topCenter,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.25,
                  color: context.colour.secondary.withAlpha(25),
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: HowToDecideSheetBackupOption(),
          ),
        ],
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  final BackupProviderEntity provider;
  final VoidCallback onTap;

  const _ProviderTile({
    required this.provider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colour.onPrimary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Image.asset(
                provider.iconPath,
                fit: BoxFit.cover,
              ),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BBText(
                    provider.name,
                    style: context.font.headlineMedium,
                  ),
                  const Gap(10),
                  OptionsTag(text: provider.description),
                ],
              ),
            ),
            const Gap(8),
            Icon(
              Icons.arrow_forward,
              color: context.colour.secondary,
            ),
          ],
        ),
      ),
    );
  }
}
