import 'dart:async';

import 'package:bull_ui/bull_ui.dart';
import 'package:screen_privacy/screen_privacy.dart';
import 'package:secrets/secrets.dart' show VaultKey;

import '../../l10n/context_localizations.dart';
import '../../presentation/sensitive_clipboard.dart';

class ViewVaultKeyPage extends StatefulWidget {
  final VaultKey vaultKey;
  final String copiedMessage;

  const ViewVaultKeyPage({
    super.key,
    required this.vaultKey,
    required this.copiedMessage,
  });

  @override
  State<ViewVaultKeyPage> createState() => _ViewVaultKeyPageState();
}

class _ViewVaultKeyPageState extends State<ViewVaultKeyPage>
    with PrivacyScreen {
  final _clipboard = SensitiveClipboard();
  bool _revealed = false;
  bool? _protected;
  late Future<bool> _protection;
  int _privacyGeneration = 0;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state == AppLifecycleState.resumed) {
          _acquirePrivacy();
        } else {
          _privacyGeneration++;
          setState(() {
            _protected = null;
            _protection = Completer<bool>().future;
            _revealed = false;
          });
        }
      },
    );
    _acquirePrivacy();
  }

  Future<void> _acquirePrivacy() async {
    final generation = ++_privacyGeneration;
    setState(() {
      _protected = null;
      _protection = enableScreenPrivacy();
    });
    final protected = await _protection;
    if (mounted && generation == _privacyGeneration) {
      setState(() => _protected = protected);
    }
  }

  @override
  void dispose() {
    _privacyGeneration++;
    _lifecycle.dispose();
    _clipboard.dispose();
    disableScreenPrivacy();
    super.dispose();
  }

  Future<void> _copy() async {
    if (_protected != true) return;
    final copied = await _clipboard.copy(widget.vaultKey.hex);
    if (copied && mounted) {
      BullSnackBar.show(context, message: widget.copiedMessage);
    }
  }

  @override
  Widget build(BuildContext context) => BullScreenPrivacyGate(
    protection: _protection,
    unavailableMessage: context.loc.recoverbullUnexpectedError,
    retryLabel: context.loc.recoverbullRetry,
    onRetry: _acquirePrivacy,
    builder: _buildProtected,
  );

  Widget _buildProtected(BuildContext context) => BullScaffold(
    body: SafeArea(
      child: Column(
        children: [
          BullTopBar(
            title: context.loc.recoverbullVaultKey,
            onBack: () => Navigator.of(context).pop(),
          ),
          if (_protected != true)
            BullText(
              _protected == null
                  ? context.loc.recoverbullPleaseWait
                  : context.loc.recoverbullUnexpectedError,
              style: context.bullText.bodyLarge,
            )
          else ...[
            Padding(
              padding: const EdgeInsets.all(BullSpacing.lg),
              child: ExcludeSemantics(
                child: BullCopyField(
                  text: _revealed ? widget.vaultKey.hex : '*' * 64,
                  copiedMessage: widget.copiedMessage,
                  onCopy: _copy,
                ),
              ),
            ),
            BullButton.small(
              label: context.loc.recoverbullVaultKey,
              onPressed: () => setState(() => _revealed = !_revealed),
              bgColor: context.bull.primary,
              textColor: context.bull.onPrimary,
            ),
          ],
        ],
      ),
    ),
  );
}
