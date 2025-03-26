import 'package:bb_mobile/_ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:bb_mobile/backup_wallet/data/constants/backup_providers.dart'
    show backupProviders;
import 'package:bb_mobile/backup_wallet/domain/entities/backup_provider_entity.dart';
import 'package:bb_mobile/backup_wallet/ui/widgets/option_tag.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/recover_wallet/presentation/bloc/recover_wallet_bloc.dart';
import 'package:bb_mobile/recover_wallet/ui/recover_wallet_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart'
    show BlocConsumer, BlocProvider, ReadContext;
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ChooseVaultProviderScreen extends StatefulWidget {
  final bool fromOnboarding;
  const ChooseVaultProviderScreen({
    super.key,
    this.fromOnboarding = false,
  });

  @override
  State<ChooseVaultProviderScreen> createState() =>
      _ChooseVaultProviderScreenState();
}

class _ChooseVaultProviderScreenState extends State<ChooseVaultProviderScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => locator<RecoverWalletBloc>(),
      child: _Screen(widget.fromOnboarding),
    );
  }
}

class _Screen extends StatelessWidget {
  final bool fromOnboarding;
  const _Screen(this.fromOnboarding);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RecoverWalletBloc, RecoverWalletState>(
      listenWhen: (previous, current) =>
          previous.recoverWalletStatus != current.recoverWalletStatus,
      listener: (context, state) {
        state.recoverWalletStatus.when(
          initial: () => {},
          loading: () {},
          success: () {
            if (!state.encryptedInfo.isCorrupted) {
              context.pushNamed(
                RecoverWalletSubroute.backupInfo.name,
                extra: (state.encryptedInfo, fromOnboarding),
              );
            }
          },
          failure: (message) {
            //TODO; create a proper error screen or widget
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
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
              title: fromOnboarding ? "Choose vault location" : "Test backup",
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!fromOnboarding) ...[
                  BBText(
                    'Test to make sure you can retrieve your encrypted vault.',
                    style: context.font.bodySmall?.copyWith(
                      color: context.colour.outline,
                    ),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                  ),
                  const Gap(30),
                ] else
                  const SizedBox.shrink(),
                _ProviderTile(
                  provider: backupProviders[0],
                  onTap: () => context.read<RecoverWalletBloc>().add(
                        const SelectGoogleDriveRecovery(),
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
                  onTap: () => context.read<RecoverWalletBloc>().add(
                        const SelectFileSystemRecovery(),
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProviderTile extends StatefulWidget {
  final BackupProviderEntity provider;
  final VoidCallback onTap;

  const _ProviderTile({
    required this.provider,
    required this.onTap,
  });

  @override
  State<_ProviderTile> createState() => _ProviderTileState();
}

class _ProviderTileState extends State<_ProviderTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) => _controller.reverse(),
          onTapCancel: () => _controller.reverse(),
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            decoration: BoxDecoration(
              color: context.colour.onPrimary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Image.asset(
                      widget.provider.iconPath,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BBText(
                          widget.provider.name,
                          style: context.font.headlineMedium,
                        ),
                        const Gap(10),
                        OptionsTag(text: widget.provider.description),
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
          ),
        ),
      ),
    );
  }
}
