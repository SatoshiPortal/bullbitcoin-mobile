import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/ui/mnemonic_reader.dart';
import 'package:secrets/src/ui/privacy_guard.dart';

/// SEALED display of a stored mnemonic. Takes only a [Fingerprint]; reads the
/// words internally and renders them — they are never exposed via a getter.
/// Screen-capture-guarded, excluded from semantics, and redacted in
/// `debugFillProperties`.
class MnemonicView extends StatefulWidget {
  const MnemonicView({
    super.key,
    required this.seed,
    this.showPassphrase = false,
    @visibleForTesting this.reader,
  });

  final Fingerprint seed;
  final bool showPassphrase;

  /// Test seam only — production resolves the reader from the locator.
  @visibleForTesting
  final MnemonicReader? reader;

  @override
  State<MnemonicView> createState() => _MnemonicViewState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    // Redacted: expose the public handle, NEVER the words.
    properties.add(StringProperty('seed', seed.hex));
    properties.add(FlagProperty('showPassphrase',
        value: showPassphrase, ifTrue: 'showPassphrase'));
  }
}

class _MnemonicViewState extends State<MnemonicView> {
  late Future<({List<String> words, String? passphrase})> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MnemonicView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-fetch if the parent swapped in a different seed — otherwise the old
    // seed's words would stay on screen (a stale-secret display bug).
    if (oldWidget.seed != widget.seed || oldWidget.reader != widget.reader) {
      _load();
    }
  }

  void _load() {
    try {
      final reader = widget.reader ?? GetIt.instance<MnemonicReader>();
      _future = reader.read(widget.seed);
    } catch (e) {
      // e.g. SecretsLocator.registerDatasources was never called. Route to the
      // FutureBuilder error path (warning card) instead of crashing initState.
      _future = Future.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrivacyGuard(
      child: FutureBuilder<({List<String> words, String? passphrase})>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            // A locked keychain / missing seed must surface, not spin forever.
            return const BullSeedWarningCard(
              message: 'Unable to load this wallet right now.',
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;
          if (data.words.isEmpty) {
            // Bytes-only (non-mnemonic) seed — there is no phrase to show.
            return const BullSeedWarningCard(
              message: 'This wallet has no recovery phrase to display.',
            );
          }
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BullMnemonicGrid(words: data.words),
                if (widget.showPassphrase &&
                    (data.passphrase?.isNotEmpty ?? false)) ...[
                  const Gap(BullSpacing.md),
                  BullText(
                    data.passphrase!,
                    style: Theme.of(context).textTheme.bodyLarge,
                    color: context.bull.onSurface,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
