import 'package:bb_mobile/core/mixins/privacy_screen.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/app_startup/domain/legacy_seed.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/get_legacy_seeds_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Blocking gate for pre-v5 (2023–2024 "BULL") installs: those builds are no
/// longer migrated. The user writes down their recovery phrase(s), deletes
/// the app and reinstalls it, then recovers. The screen is terminal on
/// purpose — there is no navigation away.
class LegacyBackupScreen extends StatefulWidget {
  const LegacyBackupScreen({super.key});

  @override
  State<LegacyBackupScreen> createState() => _LegacyBackupScreenState();
}

class _LegacyBackupScreenState extends State<LegacyBackupScreen>
    with PrivacyScreen {
  // Gate rendering on the privacy future: the words must never be on screen
  // before screenshot blocking is active.
  late final Future<void> _privacyFuture = enableScreenPrivacy();

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
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
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
                const _SealedLegacySeedsBackup(),
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
  const _SealedLegacySeedsBackup();

  @override
  State<_SealedLegacySeedsBackup> createState() =>
      _SealedLegacySeedsBackupState();
}

class _SealedLegacySeedsBackupState extends State<_SealedLegacySeedsBackup> {
  late final Future<List<LegacySeed>> _seeds = locator<GetLegacySeedsUsecase>()
      .execute();
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LegacySeed>>(
      future: _seeds,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Reading secure storage failed on exactly the kind of old install
          // this screen targets — same recourse as the no-seeds case.
          return const _ContactSupportCard();
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final seeds = snapshot.data!;
        if (seeds.isEmpty) {
          return const _ContactSupportCard();
        }

        return Column(
          children: [
            for (final seed in seeds) ...[
              _LegacySeedCard(seed: seed),
              const Gap(16),
            ],
            const Gap(8),
            CheckboxListTile(
              value: _confirmed,
              onChanged: (value) => setState(() => _confirmed = value ?? false),
              controlAffinity: .leading,
              title: BBText(
                context.loc.legacyBackupConfirm,
                style: context.font.bodyMedium,
              ),
            ),
            if (_confirmed) ...[
              const Gap(16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.appColors.surface,
                  borderRadius: BorderRadius.circular(4),
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
      },
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
            // ignore: deprecated_member_use
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
  final LegacySeed seed;

  const _LegacySeedCard({required this.seed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: context.appColors.border),
      ),
      // Secrets stay out of the semantics/accessibility tree.
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: .start,
          children: [
            BBText(
              context.loc.legacyBackupWalletLabel,
              style: context.font.labelSmall?.copyWith(
                color: context.appColors.secondary,
              ),
            ),
            BBText(seed.fingerprint, style: context.font.bodySmall),
            const Gap(16),
            _WordsGrid(words: seed.words),
            if (seed.passphrases.isNotEmpty) ...[
              const Gap(16),
              for (final passphrase in seed.passphrases) ...[
                Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: context.appColors.secondary,
                    ),
                    const Gap(8),
                    BBText(
                      context.loc.legacyBackupPassphraseLabel,
                      style: context.font.labelSmall?.copyWith(
                        color: context.appColors.secondary,
                      ),
                    ),
                  ],
                ),
                const Gap(4),
                BBText(passphrase, style: context.font.bodyMedium),
                const Gap(8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _WordsGrid extends StatelessWidget {
  static const int _columns = 2;

  final List<String> words;

  const _WordsGrid({required this.words});

  @override
  Widget build(BuildContext context) {
    final splitIndex = (words.length / _columns).ceil();
    final columns = [
      (start: 0, end: splitIndex),
      (start: splitIndex, end: words.length),
    ];

    return Row(
      crossAxisAlignment: .start,
      spacing: 16,
      children: [
        for (final column in columns)
          Expanded(
            child: Column(
              spacing: 8,
              children: [
                for (var i = column.start; i < column.end; i++)
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: BBText(
                          '${i + 1}.',
                          style: context.font.bodySmall?.copyWith(
                            color: context.appColors.secondary,
                          ),
                          textAlign: .right,
                        ),
                      ),
                      const Gap(8),
                      Expanded(
                        child: BBText(
                          words[i],
                          style: context.font.bodyMedium?.copyWith(
                            fontWeight: .w600,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
