import 'package:bb_mobile/core/recoverbull/data/constants/backup_providers.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/backup_provider.dart';
import 'package:bb_mobile/ui/components/cards/tag_card.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

class VaultLocations extends StatelessWidget {
  final void Function(BackupProviderEntity provider) onProviderSelected;
  final String? description;

  const VaultLocations({
    super.key,
    required this.onProviderSelected,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (description != null) ...[
          BBText(
            description!,
            style: context.font.bodySmall,
          ),
          const Gap(20),
        ],
        for (final provider in backupProviders) ...[
          _ProviderTile(
            provider: provider,
            onTap: () => onProviderSelected(provider),
          ),
          if (provider != backupProviders.last) const Gap(16),
        ],
      ],
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
