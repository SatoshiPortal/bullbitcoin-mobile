import 'dart:async';

import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';
import 'package:screen_privacy/screen_privacy.dart';
import 'package:secrets/secrets.dart'
    show MnemonicTile, Secret, SecretExtension;

import 'physical_backup_session.dart';

typedef PhysicalBackupLabels = ({
  String privacyUnavailable,
  String retry,
  String instruction,
  String Function(int) wordNumber,
  String allWordsSelected,
  String incorrectOrder,
  String unavailable,
  String passphrasePrompt,
  String passphraseLabel,
  String showPassphrase,
  String hidePassphrase,
  String whitespaceWarning,
  String incorrectPassphrase,
  String continueLabel,
});

/// An in-process UI verdict, not a grant or a cryptographic proof of ownership.
/// The fingerprint identifies the selection without retaining recovery material.
final class PhysicalBackupProof {
  final Fingerprint fingerprint;

  const PhysicalBackupProof._(this.fingerprint);
}

/// Verifies a physical backup without displaying or returning stored material.
/// The host owns selection, navigation and any persistence of the verdict.
/// Embed it in a bounded viewport; it scrolls its own content.
class PhysicalBackupChallenge extends StatefulWidget {
  final Secret secret;
  final PhysicalBackupLabels labels;
  final void Function(PhysicalBackupProof) onVerified;

  const PhysicalBackupChallenge({
    super.key,
    required this.secret,
    required this.labels,
    required this.onVerified,
  });

  @override
  State<PhysicalBackupChallenge> createState() =>
      _PhysicalBackupChallengeState();
}

enum _PassphraseFailure { incorrect, unavailable }

class _PhysicalBackupChallengeState extends State<PhysicalBackupChallenge>
    with PrivacyScreen, WidgetsBindingObserver {
  late Future<bool> _protection = enableScreenPrivacy();
  final _session = PhysicalBackupSession();
  String _candidate = '';
  _PassphraseFailure? _failure;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _session.foreground =
        lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didUpdateWidget(covariant PhysicalBackupChallenge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.secret, widget.secret)) return;
    _session.replace();
    _candidate = '';
    _failure = null;
  }

  void _clearCandidate() {
    _candidate = '';
    _failure = null;
    _session.clearInput();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _session.foreground) return;
    setState(() {
      _session.setForeground(foreground);
      if (!foreground) {
        _candidate = '';
        _failure = null;
      }
    });
  }

  void _wordsVerified(int epoch) {
    if (!mounted) return;
    var report = false;
    setState(() {
      report = _session.wordsSolved(
        epoch,
        hasPassphrase: widget.secret.info.hasPassphrase,
      );
    });
    if (report) _report(widget.secret);
  }

  Future<void> _verifyPassphrase() async {
    if (!_session.beginVerification()) return;
    final secret = widget.secret;
    final epoch = _session.passphraseEpoch;
    setState(() {
      _failure = null;
    });
    final result = await secret.verify.passphrase(_candidate);
    if (!mounted ||
        !identical(secret, widget.secret) ||
        !_session.acceptsVerification(epoch)) {
      return;
    }
    setState(() {
      _session.finishVerification(
        verified: switch (result) {
          Ok(value: true) => true,
          _ => false,
        },
      );
      _failure = switch (result) {
        Ok(value: false) => _PassphraseFailure.incorrect,
        Err() => _PassphraseFailure.unavailable,
        _ => null,
      };
    });
    if (result case Ok(value: true)) {
      setState(_clearCandidate);
      _report(secret);
    }
  }

  void _report(Secret secret) {
    widget.onVerified(PhysicalBackupProof._(secret.id));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clearCandidate();
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    return BullScreenPrivacyGate(
      protection: _protection,
      unavailableMessage: labels.privacyUnavailable,
      retryLabel: labels.retry,
      onRetry: () => setState(() => _protection = enableScreenPrivacy()),
      builder: (context) =>
          SingleChildScrollView(child: _content(context, labels)),
    );
  }

  Widget _content(BuildContext context, PhysicalBackupLabels labels) => Column(
    crossAxisAlignment: .stretch,
    children: [
      BullText(
        labels.instruction,
        textAlign: .center,
        maxLines: 2,
        style: context.bullType.body.copyWith(
          fontWeight: .w700,
          letterSpacing: 0,
        ),
      ),
      const Gap(20),
      BullText(
        _session.total == 0 || _session.placed < _session.total
            ? labels.wordNumber(_session.placed + 1)
            : labels.allWordsSelected,
        textAlign: .center,
        style: context.bullType.caption.copyWith(
          fontWeight: .w700,
          color: context.bull.outline,
          letterSpacing: 0,
        ),
      ),
      const Gap(20),
      if (_session.needsPassphrase) ...[
        BullText(labels.passphrasePrompt, style: context.bullType.body),
        BullSecretTextInput(
          key: ValueKey(_session.passphraseEpoch),
          label: labels.passphraseLabel,
          showLabel: labels.showPassphrase,
          hideLabel: labels.hidePassphrase,
          onChanged: (value) => setState(() => _candidate = value),
        ),
        if (_candidate != _candidate.trim())
          BullText(labels.whitespaceWarning, style: context.bullType.body),
        if (_failure case final failure?)
          BullText(
            switch (failure) {
              _PassphraseFailure.incorrect => labels.incorrectPassphrase,
              _PassphraseFailure.unavailable => labels.unavailable,
            },
            style: context.bullType.body,
            color: context.bull.error,
          ),
        const Gap(16),
        BullButton.primary(
          size: BullButtonSize.small,
          label: labels.continueLabel,
          onPressed: _session.canVerify ? _verifyPassphrase : null,
        ),
      ] else if (_session.foreground)
        _wordsChallenge(context, _session.challengeEpoch),
    ],
  );

  Widget _wordsChallenge(BuildContext context, int epoch) {
    final labels = widget.labels;
    return KeyedSubtree(
      key: ValueKey(epoch),
      child: widget.secret.widgets.mnemonicChallenge(
        style: context.bullType.label.copyWith(
          fontWeight: .w700,
          color: context.bull.secondary,
        ),
        placeholder: const Center(child: CircularProgressIndicator()),
        failureBuilder: (context, _, retry) => Column(
          mainAxisSize: .min,
          children: [
            BullText(
              labels.unavailable,
              textAlign: .center,
              style: context.bullType.body.copyWith(
                fontWeight: .w500,
                color: context.bull.error,
              ),
            ),
            const Gap(16),
            BullButton.secondary(
              size: BullButtonSize.small,
              label: labels.retry,
              onPressed: retry,
            ),
          ],
        ),
        onProgress: (placed, total) {
          if (!mounted || !_session.acceptsWords(epoch)) return;
          setState(() {
            _session.placed = placed;
            _session.total = total;
          });
        },
        onSolved: () => _wordsVerified(epoch),
        onMistake: () =>
            BullSnackBar.show(context, message: labels.incorrectOrder),
        tileBuilder: (context, tile) => Expanded(child: _Tile(tile: tile)),
        layoutBuilder: (context, tiles) => Column(
          children: [
            for (var i = 0; i < (tiles.length + 1) ~/ 2; i++)
              Row(
                children: [
                  tiles[i],
                  if (i + (tiles.length + 1) ~/ 2 < tiles.length)
                    tiles[i + (tiles.length + 1) ~/ 2]
                  else
                    const Expanded(child: SizedBox()),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final MnemonicTile tile;

  const _Tile({required this.tile});

  @override
  Widget build(BuildContext context) {
    final color = tile.isPlaced ? context.bull.primary : context.bull.textMuted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 13),
      child: InkWell(
        onTap: tile.onTap,
        splashColor: context.bull.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: context.bull.surface,
            borderRadius: BorderRadius.circular(context.bullShapes.card),
            border: Border.all(color: context.bull.border, width: 0.69),
            boxShadow: [
              BoxShadow(
                color: context.bull.border.withValues(alpha: 0.3),
                offset: const Offset(0, 2),
              ),
            ],
          ),
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Row(
            mainAxisSize: .min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Container(
                  key: ValueKey(tile.isPlaced),
                  width: 34.48,
                  height: 34.48,
                  decoration: BoxDecoration(
                    color: color,
                    border: Border.all(color: color, width: 0.82),
                    borderRadius: BorderRadius.circular(
                      context.bullShapes.badge,
                    ),
                  ),
                  child: Center(
                    child: BullText(
                      tile.position?.toString() ?? '00',
                      style: context.bullType.body.copyWith(
                        fontWeight: .w700,
                        letterSpacing: 0.15,
                        color: context.bull.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const Gap(12),
              tile.word,
            ],
          ),
        ),
      ),
    );
  }
}
