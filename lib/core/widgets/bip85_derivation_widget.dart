import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Bip85DerivationWidget extends StatefulWidget {
  final Bip85DerivationEntity derivation;
  final String entropy;
  final Future<void> Function(Bip85DerivationEntity, String)? onAliasChanged;
  final Future<void> Function(Bip85DerivationEntity)? onDerivationRevoked;
  final Future<void> Function(Bip85DerivationEntity)? onDerivationActivated;

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
  late TextEditingController _aliasController;

  @override
  void initState() {
    super.initState();
    _aliasController = TextEditingController(
      text: widget.derivation.alias ?? '',
    );
  }

  @override
  void didUpdateWidget(Bip85DerivationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.derivation.alias != oldWidget.derivation.alias) {
      _aliasController.text = widget.derivation.alias ?? '';
    }
  }

  @override
  void dispose() {
    _aliasController.dispose();
    super.dispose();
  }

  Future<void> _saveAlias() async {
    if (widget.onAliasChanged != null) {
      await widget.onAliasChanged!(widget.derivation, _aliasController.text);
      setState(() => _isEditingAlias = false);
    }
  }

  Future<void> _revokeDerivation() async {
    if (widget.onDerivationRevoked != null) {
      await widget.onDerivationRevoked!(widget.derivation);
    }
  }

  Future<void> _activateDerivation() async {
    if (widget.onDerivationActivated != null) {
      await widget.onDerivationActivated!(widget.derivation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRevoked = widget.derivation.status == Bip85Status.revoked;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: context.appColors.border),
        borderRadius: BorderRadius.circular(8),
        color: context.appColors.surface,
      ),

      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              Text(
                widget.derivation.path,
                style: TextStyle(color: context.appColors.text),
              ),
              Text(
                widget.derivation.application.name,
                style: TextStyle(color: context.appColors.text),
              ),
              Text(
                widget.derivation.status.name,
                style: TextStyle(color: context.appColors.text),
              ),
              if (isRevoked && widget.onDerivationActivated != null)
                IconButton(
                  icon: Icon(Icons.replay, color: context.appColors.success),
                  onPressed: _activateDerivation,
                )
              else if (widget.onDerivationRevoked != null && !isRevoked)
                IconButton(
                  icon: Icon(Icons.block, color: context.appColors.error),
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
                          style: TextStyle(color: context.appColors.text),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: context.appColors.border,
                              ),
                            ),
                          ),
                        )
                      : Text(
                          widget.derivation.alias ?? '',
                          style: TextStyle(color: context.appColors.text),
                        ),
                ),
                if (widget.onAliasChanged != null)
                  if (_isEditingAlias)
                    IconButton(
                      icon: Icon(
                        Icons.check,
                        color: context.appColors.onSurface,
                      ),
                      onPressed: _saveAlias,
                    )
                  else
                    IconButton(
                      icon: Icon(
                        Icons.edit,
                        color: context.appColors.onSurface,
                      ),
                      onPressed: () => setState(() => _isEditingAlias = true),
                    ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: widget.entropy),
                    obscureText: _isObscured,
                    readOnly: true,
                    decoration: const InputDecoration(border: InputBorder.none),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isObscured ? Icons.visibility : Icons.visibility_off,
                    color: context.appColors.onSurface,
                  ),
                  onPressed: () => setState(() => _isObscured = !_isObscured),
                ),
                IconButton(
                  icon: Icon(Icons.copy, color: context.appColors.onSurface),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.entropy));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied to clipboard'),
                        duration: Duration(seconds: 1),
                      ),
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
