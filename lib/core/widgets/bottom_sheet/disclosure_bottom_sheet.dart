import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class DisclosureLink extends StatelessWidget {
  const DisclosureLink({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.title,
    required this.body,
  });

  final String label;
  final String semanticLabel;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final color = context.appColors.onSurfaceVariant;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () =>
              DisclosureBottomSheet.show(context, title: title, body: body),
          borderRadius: BorderRadius.circular(2),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 16, color: color),
                const Gap(6),
                Flexible(
                  child: BBText(
                    label,
                    style: context.font.labelSmall,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DisclosureBottomSheet extends StatelessWidget {
  const DisclosureBottomSheet({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    return BlurredBottomSheet.show(
      context: context,
      child: DisclosureBottomSheet(title: title, body: body),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: BBText(title, style: context.font.headlineMedium),
                ),
                IconButton(
                  tooltip: context.loc.closeDialogButton,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: _DisclosureBody(body),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisclosureBody extends StatelessWidget {
  const _DisclosureBody(this.body);

  final String body;

  @override
  Widget build(BuildContext context) {
    final blocks = body.trim().split(RegExp(r'\n\s*\n'));
    final children = <Widget>[];

    for (final block in blocks) {
      if (block.trim().isEmpty) continue;
      if (children.isNotEmpty) {
        children.add(Gap(_spacingBefore(block)));
      }
      children.add(_buildBlock(context, block.trim()));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  double _spacingBefore(String block) {
    if (block.startsWith('## ')) return 24;
    if (block.startsWith('### ') || block.startsWith('> ')) return 16;
    return 12;
  }

  Widget _buildBlock(BuildContext context, String block) {
    if (block.startsWith('## ')) {
      return Semantics(
        header: true,
        child: BBText(
          block.substring(3),
          style: context.font.titleMedium?.copyWith(fontWeight: .w600),
          color: context.appColors.text,
        ),
      );
    }

    if (block.startsWith('### ')) {
      return Semantics(
        header: true,
        child: BBText(
          block.substring(4),
          style: context.font.bodyLarge?.copyWith(fontWeight: .w600),
          color: context.appColors.text,
        ),
      );
    }

    final lines = block.split('\n');
    if (lines.every((line) => line.startsWith('> '))) {
      return _buildCallout(
        context,
        title: lines.first.substring(2),
        body: lines.skip(1).map((line) => line.substring(2)).join('\n'),
      );
    }

    if (lines.every((line) => line.startsWith('- '))) {
      return _buildBulletList(
        context,
        lines.map((line) => line.substring(2)).toList(),
      );
    }

    return BBText(
      block,
      style: context.font.bodyMedium,
      color: context.appColors.text,
    );
  }

  Widget _buildCallout(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.warningContainer,
        border: Border.all(color: context.appColors.warning),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 22,
            color: context.appColors.warning,
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText(
                  title,
                  style: context.font.bodyLarge?.copyWith(fontWeight: .w600),
                  color: context.appColors.text,
                ),
                const Gap(6),
                BBText(
                  body,
                  style: context.font.bodyMedium,
                  color: context.appColors.text,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletList(BuildContext context, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const Gap(8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 18,
                child: BBText(
                  '•',
                  style: context.font.bodyMedium,
                  color: context.appColors.text,
                ),
              ),
              Expanded(child: _buildBulletText(context, items[index])),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBulletText(BuildContext context, String item) {
    final style = context.font.bodyMedium?.copyWith(
      color: context.appColors.text,
    );
    final match = RegExp(r'^\*\*(.+?)\*\*(.*)$').firstMatch(item);

    if (match == null) return Text(item, style: style);

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(
            text: match.group(1),
            style: style?.copyWith(fontWeight: .w600),
          ),
          TextSpan(text: match.group(2)),
        ],
      ),
    );
  }
}
