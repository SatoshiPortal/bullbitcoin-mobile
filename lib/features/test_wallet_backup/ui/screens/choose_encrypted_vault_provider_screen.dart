import 'package:bb_mobile/core/recoverbull/data/constants/backup_providers.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/backup_provider.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/test_wallet_backup_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/ui/components/cards/tag_card.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart'
    show BlocConsumer, BlocProvider, ReadContext;
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ChooseVaultProviderScreen extends StatefulWidget {
  const ChooseVaultProviderScreen({
    super.key,
  });

  @override
  State<ChooseVaultProviderScreen> createState() =>
      _ChooseVaultProviderScreenState();
}

class _ChooseVaultProviderScreenState extends State<ChooseVaultProviderScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider<TestWalletBackupBloc>(
      create: (_) => locator<TestWalletBackupBloc>(),
      child: const _Screen(),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  void _handleProviderTap(BuildContext context, BackupProviderEntity provider) {
    if (provider == backupProviders[0]) {
      context
          .read<TestWalletBackupBloc>()
          .add(const SelectGoogleDriveBackupTest());
    } else if (provider == backupProviders[2]) {
      context
          .read<TestWalletBackupBloc>()
          .add(const SelectGoogleDriveBackupTest());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TestWalletBackupBloc, TestWalletBackupState>(
      listenWhen: (previous, current) =>
          previous.isLoading != current.isLoading ||
          previous.backupInfo != current.backupInfo ||
          previous.error != current.error ||
          previous.isSuccess != current.isSuccess,
      listener: (context, state) {
        if (!state.backupInfo.isCorrupted &&
            !state.isLoading &&
            state.isSuccess &&
            state.error.isEmpty) {
          context.pushNamed(
            TestWalletBackupSubroute.testBackupInfo.name,
            extra: state.backupInfo,
          );
        }
      },
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: TopBar(
            onBack: () => context.pop(),
            title: 'Choose vault location',
          ),
        ),
        body: state.isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: context.colour.primary,
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    BBText(
                      'Test to make sure you can retrieve your encrypted vault.',
                      style: context.font.bodySmall,
                    ),
                    const Gap(20),
                    for (final provider in backupProviders) ...[
                      _ProviderTile(
                        provider: provider,
                        onTap: () => _handleProviderTap(context, provider),
                      ),
                      if (provider != backupProviders.last) const Gap(16),
                    ],
                  ],
                ),
              ),
      ),
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
