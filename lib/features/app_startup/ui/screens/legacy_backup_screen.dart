import 'package:screen_privacy/screen_privacy.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:secrets/secrets.dart';
import 'package:bull_ui/bull_ui.dart' show BullShapesX, Gap;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Blocking backup gate for read-only Android legacy storage. The user writes down their recovery phrase(s), deletes
/// the app and reinstalls it, then recovers. The screen is terminal on
/// purpose — there is no navigation away.
class LegacyBackupScreen extends StatefulWidget {
  const LegacyBackupScreen({super.key, required this.secrets});

  final List<Secret>? secrets;

  @override
  State<LegacyBackupScreen> createState() => _LegacyBackupScreenState();
}

class _LegacyBackupScreenState extends State<LegacyBackupScreen>
    with PrivacyScreen {
  // Gate rendering on the privacy future: the words must never be on screen
  // before screenshot blocking is active.
  late final Future<bool> _privacyFuture = enableScreenPrivacy();

  @override
  void dispose() {
    disableScreenPrivacy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: _privacyFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const _ContactSupportCard();
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data != true) return const _ContactSupportCard();
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Gap(24),
                Icon(
                  Icons.warning_amber_rounded,
                  size: 48,
                  color: context.appColors.error,
                ),
                const Gap(16),
                BBText(
                  context.loc.legacyBackupTitle,
                  style: context.font.headlineLarge,
                  textAlign: .center,
                ),
                const Gap(16),
                BBText(
                  context.loc.legacyBackupMessage,
                  style: context.font.bodyMedium,
                  textAlign: .center,
                ),
                const Gap(24),
                _SealedLegacySeedsBackup(secrets: widget.secrets),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Sealed secret display (the MnemonicView pattern): reads the legacy seeds
/// itself and never returns them — no key material in bloc state, none handed
/// to a caller. Also owns the confirmation flow, which is local widget state.
class _SealedLegacySeedsBackup extends StatefulWidget {
  const _SealedLegacySeedsBackup({required this.secrets});

  final List<Secret>? secrets;

  @override
  State<_SealedLegacySeedsBackup> createState() =>
      _SealedLegacySeedsBackupState();
}

class _SealedLegacySeedsBackupState extends State<_SealedLegacySeedsBackup> {
  bool _confirmed = false;
  bool _failed = false;
  final Set<String> _revealed = {};

  @override
  Widget build(BuildContext context) {
    final seeds = widget.secrets;
    if (seeds == null || seeds.isEmpty) return const _ContactSupportCard();
    return Column(
      children: [
        for (final seed in seeds) ...[
          _LegacySeedCard(
            seed: seed,
            onRevealed: () => setState(() => _revealed.add(seed.id.hex)),
            onFailure: () => WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_failed) setState(() => _failed = true);
            }),
          ),
          const Gap(16),
        ],
        const Gap(8),
        CheckboxListTile(
          value: _confirmed,
          onChanged: !_failed && _revealed.length == seeds.length
              ? (value) => setState(() => _confirmed = value ?? false)
              : null,
          controlAffinity: .leading,
          title: BBText(
            context.loc.legacyBackupConfirm,
            style: context.font.bodyMedium,
          ),
        ),
        if (_confirmed && !_failed) ...[
          const Gap(16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.appColors.surface,
              borderRadius: BorderRadius.circular(context.bullShapes.card),
              border: Border.all(color: context.appColors.border),
            ),
            child: Column(
              children: [
                BBText(
                  context.loc.legacyBackupReinstallTitle,
                  style: context.font.headlineMedium,
                ),
                const Gap(8),
                BBText(
                  context.loc.legacyBackupReinstallMessage,
                  style: context.font.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ContactSupportCard extends StatelessWidget {
  const _ContactSupportCard();

  @override
  Widget build(BuildContext context) {
    // The marker says legacy but no seed could be read — deleting the app
    // could strand funds, so point to support instead.
    return Column(
      children: [
        BBText(
          context.loc.legacyBackupNoSeedsMessage,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.error,
          ),
          textAlign: .center,
        ),
        const Gap(16),
        TextButton(
          onPressed: () {
            final url = Uri.parse(SettingsConstants.webSupportLink);
            launchUrl(url, mode: LaunchMode.externalApplication);
          },
          child: BBText(
            context.loc.appStartupContactSupportButton,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _LegacySeedCard extends StatelessWidget {
  final Secret seed;
  final VoidCallback onRevealed;
  final VoidCallback onFailure;

  const _LegacySeedCard({
    required this.seed,
    required this.onRevealed,
    required this.onFailure,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          context.loc.legacyBackupWalletLabel,
          style: context.font.labelSmall,
        ),
        BBText(seed.id.hex, style: context.font.bodySmall),
        const Gap(16),
        seed.widgets.mnemonicView(
          onRevealed: onRevealed,
          style: context.font.bodyMedium,
          passphraseLabel: context.loc.legacyBackupPassphraseLabel,
          placeholder: const CircularProgressIndicator(),
          failureBuilder: (context, failure, retry) {
            onFailure();
            return const _ContactSupportCard();
          },
        ),
      ],
    ),
  );
}
