import 'package:bull_recoverbull/src/domain/entities/vault_provider.dart';
import 'package:flutter/material.dart';
import 'package:bull_recoverbull/src/ui/support.dart';
import 'package:flutter/services.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:bull_recoverbull/src/l10n/context_localizations.dart';

class ProviderCard extends StatefulWidget {
  final VaultProvider provider;
  final VoidCallback onTap;
  final bool enabled;

  const ProviderCard({
    super.key,
    required this.provider,
    required this.onTap,
    this.enabled = true,
  });

  @override
  State<ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends State<ProviderCard>
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
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
        color: context.appColors.transparent,
        child: InkWell(
          onTapDown: widget.enabled ? (_) => _controller.forward() : null,
          onTapUp: widget.enabled ? (_) => _controller.reverse() : null,
          onTapCancel: () => _controller.reverse(),
          onTap: widget.enabled
              ? () {
                  HapticFeedback.lightImpact();
                  widget.onTap();
                }
              : null,
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            decoration: BoxDecoration(
              color: context.appColors.surface,
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
                      package: 'bull_recoverbull',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        BBText(
                          _providerName(context),
                          style: context.font.headlineMedium?.copyWith(
                            color: widget.enabled
                                ? context.appColors.onSurface
                                : context.appColors.textMuted,
                          ),
                        ),
                        const Gap(10),
                        OptionsTag(text: _providerDescription(context)),
                      ],
                    ),
                  ),
                  const Gap(8),
                  Icon(Icons.arrow_forward, color: context.appColors.onSurface),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _providerName(BuildContext context) => switch (widget.provider) {
    VaultProvider.googleDrive => context.loc.recoverbullSelectGoogleDrive,
    VaultProvider.iCloud => context.loc.recoverbullSelectAppleIcloud,
    VaultProvider.customLocation =>
      context.loc.recoverbullSelectCustomLocationProvider,
  };

  String _providerDescription(BuildContext context) =>
      widget.provider == VaultProvider.customLocation
      ? context.loc.recoverbullSelectTakeYourTime
      : context.loc.recoverbullSelectQuickAndEasy;
}
