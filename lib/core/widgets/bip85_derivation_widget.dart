import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:flutter/material.dart';

class Bip85DerivationWidget extends StatefulWidget {
  final String xprvBase58;
  final Bip85DerivationEntity derivation;

  const Bip85DerivationWidget({
    super.key,
    required this.derivation,
    required this.xprvBase58,
  });

  @override
  State<Bip85DerivationWidget> createState() => _Bip85DerivationWidgetState();
}

class _Bip85DerivationWidgetState extends State<Bip85DerivationWidget> {
  bool _isObscured = true;

  @override
  Widget build(BuildContext context) {
    final data = bip85.Bip85Entropy.deriveFromHardenedPath(
      xprvBase58: widget.xprvBase58,
      path: bip85.Bip85HardenedPath(widget.derivation.path),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            ],
          ),
          Text(
            widget.derivation.alias ?? '',
            style: TextStyle(color: context.appColors.text),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: data),
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
            ],
          ),
        ],
      ),
    );
  }
}
