import 'dart:math' as math;

import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gif/gif.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/entities/vault_provider.dart';
import '../../l10n/context_localizations.dart';
import '../../presentation/vault_flow_cubit.dart';
import '../recoverbull_flow_navigator.dart';

const _package = 'bull_recoverbull';

AssetImage recoverBullAsset(String name) =>
    AssetImage('assets/$name', package: _package);

/// Looping cubes shown while a vault operation is in flight.
class RecoverBullProgress extends StatelessWidget {
  final String? title;
  final String? description;
  final bool isLoading;

  const RecoverBullProgress({
    super.key,
    this.isLoading = true,
    this.title,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisAlignment: .center,
        children: [
          if (isLoading)
            Center(
              child: Gif(
                autostart: Autostart.loop,
                width: 200,
                height: 200,
                image: recoverBullAsset('cubes_loading.gif'),
              ),
            ),
          if (title case final title?) ...[
            const Gap(16),
            BullText(
              title,
              textAlign: .center,
              style: context.bullText.headlineLarge?.copyWith(
                fontWeight: .bold,
              ),
            ),
          ],
          if (description case final description?) ...[
            const Gap(16),
            BullText(
              description,
              textAlign: .center,
              style: context.bullText.bodySmall,
              maxLines: 3,
            ),
          ],
        ],
      ),
    );
  }
}

/// A finished step with one call to action at the bottom.
class RecoverBullStatusScreen extends StatelessWidget {
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback onTap;
  final List<Widget> extras;

  const RecoverBullStatusScreen({
    super.key,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onTap,
    this.extras = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bull.surface,
      body: BullStackedPage(
        bottomChild: BullButton.big(
          label: buttonText,
          onPressed: onTap,
          textColor: context.bull.onSecondary,
          bgColor: context.bull.secondary,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  RecoverBullProgress(
                    isLoading: false,
                    title: title,
                    description: description,
                  ),
                  if (extras.isNotEmpty) ...[const Gap(16), ...extras],
                  const Gap(30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The animated tick closing a successful test or recovery.
class RecoverBullSuccessScreen extends StatelessWidget {
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;
  final List<Widget> extras;

  const RecoverBullSuccessScreen({
    super.key,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
    this.extras = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: .spaceBetween,
          children: [
            const Spacer(),
            Column(
              children: [
                SizedBox(
                  height: 200,
                  width: 200,
                  child: Gif(
                    image: recoverBullAsset('success_tick.gif'),
                    autostart: Autostart.once,
                    height: 200,
                    width: 200,
                  ),
                ),
                const Gap(8),
                BullText(title, style: context.bullText.headlineLarge),
                const Gap(8),
                BullText(
                  message,
                  style: context.bullText.bodyMedium,
                  textAlign: .center,
                ),
                ...extras,
              ],
            ),
            const Spacer(flex: 2),
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height * 0.05,
              ),
              child: BullButton.big(
                label: buttonLabel,
                bgColor: context.bull.secondary,
                textColor: context.bull.onSecondary,
                onPressed: onPressed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Key-server reachability in the app bar; tapping it probes again.
class KeyServerStatusWidget extends StatelessWidget {
  const KeyServerStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<VaultFlowCubit>().state.keyServer;
    return GestureDetector(
      onTap: () => context.read<VaultFlowCubit>().connect(),
      child: Column(
        mainAxisAlignment: .center,
        children: [
          if (status == KeyServerStatus.connecting)
            Gif(
              image: recoverBullAsset('cubes_loading.gif'),
              autostart: Autostart.loop,
              height: 55,
              width: 55,
            )
          else
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: context.loc.recoverbullKeyServer,
                    style: context.bullType.caption.copyWith(
                      fontWeight: FontWeight.w500,
                      color: context.bull.onSurface,
                    ),
                  ),
                  WidgetSpan(
                    child: Icon(
                      Icons.circle,
                      size: 12,
                      color: switch (status) {
                        KeyServerStatus.online => context.bull.success,
                        KeyServerStatus.offline => context.bull.error,
                        KeyServerStatus.connecting ||
                        KeyServerStatus.unknown => context.bull.textMuted,
                      },
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

/// The app bar shared by the flow's pages, with the key-server indicator.
class RecoverBullAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showKeyServer;

  const RecoverBullAppBar({
    super.key,
    required this.title,
    this.showKeyServer = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      forceMaterialTransparency: true,
      leading: IconButton(
        onPressed: () => recoverBullBack(context),
        icon: const Icon(Icons.arrow_back),
      ),
      title: BullText(
        title,
        style: context.bullText.headlineMedium,
        color: context.bull.onSurface,
      ),
      centerTitle: true,
      actions: [
        if (showKeyServer)
          const Padding(
            padding: EdgeInsets.only(right: 20),
            child: KeyServerStatusWidget(),
          ),
      ],
    );
  }
}

enum TorBullState { idle, direct, filtered, snowflake, ready, failed }

class TorBullMascot extends StatefulWidget {
  final TorBullState state;
  final String semanticLabel;

  const TorBullMascot({
    required this.state,
    required this.semanticLabel,
    super.key,
  });

  @override
  State<TorBullMascot> createState() => _TorBullMascotState();
}

class _TorBullMascotState extends State<TorBullMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _moves => switch (widget.state) {
    TorBullState.direct ||
    TorBullState.filtered ||
    TorBullState.snowflake => true,
    TorBullState.idle || TorBullState.ready || TorBullState.failed => false,
  };

  String get _asset => switch (widget.state) {
    TorBullState.idle || TorBullState.direct => 'tor_bull_searching.png',
    TorBullState.filtered => 'tor_bull_filtered.png',
    TorBullState.snowflake => 'tor_bull_snowflake.png',
    TorBullState.ready => 'tor_bull_ready.png',
    TorBullState.failed => 'tor_bull_failed.png',
  };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimation();
  }

  @override
  void didUpdateWidget(TorBullMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _updateAnimation();
  }

  void _updateAnimation() {
    if (_moves && !MediaQuery.disableAnimationsOf(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: widget.semanticLabel,
    child: SizedBox(
      key: ValueKey('tor-bull-${widget.state.name}'),
      width: 220,
      height: 190,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final wave = math.sin(_controller.value * math.pi * 2);
          final floats =
              widget.state == TorBullState.direct ||
              widget.state == TorBullState.snowflake;
          final lift = floats ? 5 + wave * 3 : 0.0;
          final shake = widget.state == TorBullState.filtered
              ? math.sin(_controller.value * math.pi * 8) * 2.5
              : 0.0;
          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                bottom: 2,
                child: Transform.scale(
                  scaleX: 1 - lift / 70,
                  child: Container(
                    width: 70,
                    height: 9,
                    decoration: BoxDecoration(
                      color: context.bull.scrim.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(
                        context.bullShapes.dot,
                      ),
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(shake, -lift),
                child: Opacity(
                  opacity: widget.state == TorBullState.idle ? 0.58 : 1,
                  child: Image(
                    image: recoverBullAsset(_asset),
                    key: ValueKey(_asset),
                    width: 220,
                    height: 190,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

extension VaultProviderPresentation on VaultProvider {
  String displayName(BuildContext context) => switch (this) {
    VaultProvider.googleDrive => context.loc.recoverbullSelectGoogleDrive,
    VaultProvider.iCloud => context.loc.recoverbullSelectAppleIcloud,
    VaultProvider.customLocation =>
      context.loc.recoverbullSelectCustomLocationProvider,
  };

  String get iconAsset => switch (this) {
    VaultProvider.googleDrive => 'google_drive.png',
    VaultProvider.iCloud => 'icloud.png',
    VaultProvider.customLocation => 'custom_location.png',
  };

  String description(BuildContext context) => switch (this) {
    VaultProvider.googleDrive ||
    VaultProvider.iCloud => context.loc.recoverbullSelectQuickAndEasy,
    VaultProvider.customLocation => context.loc.recoverbullSelectTakeYourTime,
  };
}

/// Google Drive and custom location cards; iCloud is not offered.
class VaultProviderSelector extends StatelessWidget {
  final void Function(VaultProvider provider) onProviderSelected;

  const VaultProviderSelector({super.key, required this.onProviderSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        for (final provider in VaultProvider.values.where(
          (p) => p != VaultProvider.iCloud,
        )) ...[
          _ProviderCard(
            provider: provider,
            onTap: () => onProviderSelected(provider),
          ),
          const Gap(12),
        ],
      ],
    );
  }
}

class _ProviderCard extends StatefulWidget {
  final VaultProvider provider;
  final VoidCallback onTap;

  const _ProviderCard({required this.provider, required this.onTap});

  @override
  State<_ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends State<_ProviderCard>
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
      begin: 1,
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
        color: context.bull.transparent,
        child: InkWell(
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) => _controller.reverse(),
          onTapCancel: () => _controller.reverse(),
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          borderRadius: BorderRadius.circular(context.bullShapes.card),
          child: Ink(
            decoration: BoxDecoration(
              color: context.bull.surface,
              borderRadius: BorderRadius.circular(context.bullShapes.card),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Image(
                      image: recoverBullAsset(widget.provider.iconAsset),
                      fit: BoxFit.cover,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        BullText(
                          widget.provider.displayName(context),
                          style: context.bullText.headlineMedium,
                        ),
                        const Gap(10),
                        BullOptionsTag(
                          text: widget.provider.description(context),
                        ),
                      ],
                    ),
                  ),
                  const Gap(8),
                  Icon(Icons.arrow_forward, color: context.bull.onSurface),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reminds where the vault key must not be kept before it is revealed.
class ViewVaultKeyWarningSheet extends StatelessWidget {
  const ViewVaultKeyWarningSheet({super.key});

  static Future<bool?> show(BuildContext context) => BullBottomSheet.show<bool>(
    context: context,
    child: const ViewVaultKeyWarningSheet(),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            children: [
              const Gap(20),
              Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  const Gap(24),
                  BullText(
                    context.loc.backupSettingsSecurityWarning,
                    style: context.bullText.headlineMedium,
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: const Icon(Icons.close),
                  ),
                ],
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  BullText(
                    context.loc.backupKeyWarningMessage,
                    style: context.bullText.bodyMedium?.copyWith(
                      color: context.bull.secondary,
                      fontWeight: .bold,
                    ),
                    maxLines: 4,
                  ),
                  const Gap(24),
                  BullText(
                    context.loc.backupKeySeparationWarning,
                    maxLines: 4,
                    style: context.bullText.bodyMedium,
                  ),
                  const Gap(16),
                  BullText(
                    context.loc.backupKeyExampleWarning,
                    maxLines: 3,
                    style: context.bullText.bodyMedium,
                  ),
                  const Gap(32),
                  Row(
                    children: [
                      Expanded(
                        child: BullButton.big(
                          label: context.loc.recoverbullSettingsCancel,
                          onPressed: () => Navigator.of(context).pop(false),
                          bgColor: context.bull.transparent,
                          outlined: true,
                          textStyle: context.bullText.headlineLarge,
                          textColor: context.bull.secondary,
                        ),
                      ),
                      const Gap(16),
                      Expanded(
                        child: BullButton.big(
                          label: context.loc.recoverbullContinue,
                          onPressed: () => Navigator.of(context).pop(true),
                          bgColor: context.bull.secondary,
                          textStyle: context.bullText.headlineLarge,
                          textColor: context.bull.onSecondary,
                        ),
                      ),
                    ],
                  ),
                  const Gap(30),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
