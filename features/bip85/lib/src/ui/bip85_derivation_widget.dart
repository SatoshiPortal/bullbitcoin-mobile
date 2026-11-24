import 'package:bip85/src/presentation/bip85_l10n.dart';
import 'package:secrets/bip85.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bip85/src/presentation/bip85_clipboard.dart';

import 'package:bull_ui/bull_ui.dart'
    show BullThemeX, BullShapesX, BullSnackBar;

class Bip85DerivationWidget extends StatefulWidget {
  final Bip85Derivation derivation;
  final String entropy;
  final Future<void> Function(Bip85Derivation, String)? onAliasChanged;
  final Future<void> Function(Bip85Derivation)? onDerivationRevoked;
  final Future<void> Function(Bip85Derivation)? onDerivationActivated;

  const Bip85DerivationWidget({
    super.key,
    required this.derivation,
    required this.entropy,
    this.onAliasChanged,
    this.onDerivationRevoked,
    this.onDerivationActivated,
  });

  @override
  State<Bip85DerivationWidget> createState() => _Bip85DerivationWidgetState();
}

class _Bip85DerivationWidgetState extends State<Bip85DerivationWidget> {
  bool _isObscured = true;
  bool _isEditingAlias = false;
  late final TextEditingController _aliasController;
  late final TextEditingController _entropyController;

  @override
  void initState() {
    super.initState();
    _entropyController = TextEditingController(text: widget.entropy);
    _aliasController = TextEditingController(
      text: widget.derivation.alias ?? '',
    );
  }

  @override
  void didUpdateWidget(Bip85DerivationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entropy != oldWidget.entropy) {
      _entropyController.text = widget.entropy;
      _isObscured = true;
    }
    if (widget.derivation.alias != oldWidget.derivation.alias) {
      _aliasController.text = widget.derivation.alias ?? '';
    }
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _entropyController.dispose();
    super.dispose();
  }

  Future<void> _saveAlias() async {
    final onChanged = widget.onAliasChanged;
    if (onChanged != null) {
      await onChanged(widget.derivation, _aliasController.text);
      if (!mounted) return;
      setState(() => _isEditingAlias = false);
    }
  }

  Future<void> _revokeDerivation() async {
    final onRevoked = widget.onDerivationRevoked;
    if (onRevoked != null) {
      await onRevoked(widget.derivation);
    }
  }

  Future<void> _activateDerivation() async {
    final onActivated = widget.onDerivationActivated;
    if (onActivated != null) {
      await onActivated(widget.derivation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRevoked = widget.derivation.status == Bip85Status.revoked;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: context.bull.border),
        borderRadius: BorderRadius.circular(context.bullShapes.card),
        color: context.bull.surface,
      ),

      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              Text(
                widget.derivation.path,
                style: TextStyle(color: context.bull.text),
              ),
              Text(
                widget.derivation.application.name,
                style: TextStyle(color: context.bull.text),
              ),
              Text(
                widget.derivation.status.name,
                style: TextStyle(color: context.bull.text),
              ),
              if (isRevoked && widget.onDerivationActivated != null)
                IconButton(
                  icon: Icon(Icons.replay, color: context.bull.success),
                  onPressed: _activateDerivation,
                )
              else if (widget.onDerivationRevoked != null && !isRevoked)
                IconButton(
                  icon: Icon(Icons.block, color: context.bull.error),
                  onPressed: _revokeDerivation,
                ),
            ],
          ),
          if (!isRevoked) ...[
            Row(
              children: [
                Expanded(
                  child: _isEditingAlias
                      ? TextField(
                          controller: _aliasController,
                          autofocus: true,
                          style: TextStyle(color: context.bull.text),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: context.bull.border,
                              ),
                            ),
                          ),
                        )
                      : Text(
                          widget.derivation.alias ?? '',
                          style: TextStyle(color: context.bull.text),
                        ),
                ),
                if (widget.onAliasChanged != null)
                  if (_isEditingAlias)
                    IconButton(
                      icon: Icon(Icons.check, color: context.bull.onSurface),
                      onPressed: _saveAlias,
                    )
                  else
                    IconButton(
                      icon: Icon(Icons.edit, color: context.bull.onSurface),
                      onPressed: () => setState(() => _isEditingAlias = true),
                    ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    excludeSemantics: true,
                    child: TextField(
                      controller: _entropyController,
                      obscureText: _isObscured,
                      readOnly: true,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isObscured ? Icons.visibility : Icons.visibility_off,
                    color: context.bull.onSurface,
                  ),
                  onPressed: () => setState(() => _isObscured = !_isObscured),
                ),
                IconButton(
                  icon: Icon(Icons.copy, color: context.bull.onSurface),
                  onPressed: () async {
                    await Bip85Clipboard.copy(widget.entropy);
                    if (!context.mounted) return;
                    BullSnackBar.show(
                      context,
                      message: context.bip85Loc.copiedToClipboard,
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
