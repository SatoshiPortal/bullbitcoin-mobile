import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';

class UtxoLabelSection extends StatelessWidget {
  const UtxoLabelSection({
    super.key,
    required this.labels,
    required this.onAddLabel,
  });

  final List<String> labels;
  final VoidCallback onAddLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.0,
      children: [
        ...labels.map(
          (label) => Chip(
            label: Text(label),
            backgroundColor: Colors.transparent,
            deleteIcon: const IconButton(
              icon: Icon(Icons.close, size: 18.0),
              onPressed: null,
            ),
          ),
        ),
        if (labels.isEmpty)
          ActionChip(
            label: const Icon(Icons.add, size: 16),
            onPressed: onAddLabel,
            side: BorderSide(
              color: context.theme.colorScheme.onSurface.withAlpha(128),
              style: BorderStyle.solid,
            ),
            backgroundColor: Colors.transparent,
          ),
      ],
    );
  }
}
