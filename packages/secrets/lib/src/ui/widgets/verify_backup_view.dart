import 'package:bull_ui/bull_ui.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/secrets_api.dart';
import 'package:secrets/src/ui/mnemonic_reader.dart';
import 'package:secrets/src/ui/privacy_guard.dart';

/// SEALED physical-backup verification. Reads the stored mnemonic internally,
/// shows the words shuffled, and asks the user to tap them back in order. The
/// comparison happens in-package; only the boolean outcome leaves via
/// [onResult]. The words are never exposed.
class VerifyBackupView extends StatefulWidget {
  const VerifyBackupView({
    super.key,
    required this.seed,
    required this.onResult,
    required this.unavailableMessage,
    @visibleForTesting this.reader,
  });

  final Fingerprint seed;
  final ValueChanged<bool> onResult;

  /// Caller-supplied (localized) copy shown when the seed can't be verified
  /// right now — a locked keychain, a missing seed, or a bytes-only seed with
  /// no words to verify. The package can't import the app's `AppLocalizations`,
  /// so the consumer passes a localized string in.
  final String unavailableMessage;

  @visibleForTesting
  final MnemonicReader? reader;

  @override
  State<VerifyBackupView> createState() => _VerifyBackupViewState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('seed', seed.hex));
  }
}

class _VerifyBackupViewState extends State<VerifyBackupView> {
  List<String> _correct = const [];
  List<String> _shuffled = const [];
  final List<int> _picked = [];
  bool _loading = true;
  bool _unavailable = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(VerifyBackupView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-fetch if the parent swapped in a different seed/reader without changing
    // the key — otherwise the old seed's words would stay on screen (same
    // stale-secret guard SecretRevealer uses).
    if (oldWidget.seed != widget.seed || oldWidget.reader != widget.reader) {
      _load();
    }
  }

  void _load() {
    // Reset to the loading state so a swap never leaves stale words/picks.
    _correct = const [];
    _shuffled = const [];
    _picked.clear();
    _loading = true;
    _unavailable = false;
    _done = false;
    final reader = widget.reader ?? Secrets.mnemonicReader;
    reader.read(widget.seed).then((data) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // A locked keychain / missing seed, or a bytes-only seed (no words to
        // verify), must surface — never hang on a spinner.
        if (data.words.isEmpty) {
          _unavailable = true;
          return;
        }
        _correct = data.words;
        _shuffled = [...data.words]..shuffle();
      });
    }).catchError((Object _) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _unavailable = true;
      });
    });
  }

  void _pick(int shuffledIndex) {
    if (_done) return; // result already reported — ignore further taps
    setState(() {
      if (_picked.contains(shuffledIndex)) {
        _picked.remove(shuffledIndex); // tap again to DESELECT (retry)
      } else {
        _picked.add(shuffledIndex);
      }
    });
    if (_picked.length == _correct.length) {
      final reconstructed = _picked.map((i) => _shuffled[i]).toList();
      // Constant-time-ish compare: visit EVERY word (no early break) so the
      // verify-tap timing doesn't leak how many leading words were correct.
      var mismatch = 0;
      for (var i = 0; i < _correct.length; i++) {
        if (reconstructed[i] != _correct[i]) mismatch |= 1;
      }
      _done = true; // onResult fires exactly once
      widget.onResult(mismatch == 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unavailable) {
      return BullSeedWarningCard(message: widget.unavailableMessage);
    }
    if (_loading || _shuffled.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return PrivacyGuard(
      child: Wrap(
        spacing: BullSpacing.xs,
        runSpacing: BullSpacing.xs,
        children: [
          for (var i = 0; i < _shuffled.length; i++)
            GestureDetector(
              onTap: () => _pick(i),
              child: BullText(
                _shuffled[i],
                style: Theme.of(context).textTheme.bodyLarge,
                color: _picked.contains(i)
                    ? context.bull.textMuted
                    : context.bull.onSurface,
              ),
            ),
        ],
      ),
    );
  }
}
