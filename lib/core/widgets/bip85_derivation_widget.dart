import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/utils/bip85_utils.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
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
    final data = Bip85Utils.getDerivedData(
      derivation: widget.derivation,
      xprvBase58: widget.xprvBase58,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: context.theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.derivation.path),
              Text(widget.derivation.application.name),
              Text(widget.derivation.status.name),
            ],
          ),
          Text(widget.derivation.alias ?? ''),
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
