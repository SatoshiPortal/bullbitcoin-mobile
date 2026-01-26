import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/labels/domain/label_error.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/label_text.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:bb_mobile/core/infra/di/core_dependencies.dart';

class LabelsWidget extends StatefulWidget {
  const LabelsWidget({
    super.key,
    required this.labels,
    required this.reference,
    this.onDelete,
  });

  final List<String> labels;
  final String reference;
  final Future<void> Function(String)? onDelete;

  @override
  State<LabelsWidget> createState() => _LabelsWidgetState();
}

class _LabelsWidgetState extends State<LabelsWidget> {
  final _labelsFacade = sl<LabelsFacade>();
  final Set<String> _deletingLabels = {};

  Future<void> _deleteLabel(String label) async {
    if (_deletingLabels.contains(label)) return;

    setState(() {
      _deletingLabels.add(label);
    });

    try {
      if (widget.onDelete != null) {
        await widget.onDelete!(label);
      } else {
        await _labelsFacade.delete(label: label, reference: widget.reference);
      }
      if (mounted) {
        setState(() => _deletingLabels.remove(label));
      }
    } on LabelError catch (e) {
      if (mounted) {
        setState(() => _deletingLabels.remove(label));
        SnackBarUtils.showSnackBar(context, e.toTranslated(context));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deletingLabels.remove(label));
        SnackBarUtils.showSnackBar(
          context,
          context.loc.labelDeleteFailed(label),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.labels.isEmpty) return const SizedBox.shrink();

    final distinctLabels = widget.labels.toSet().toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: distinctLabels.map((label) {
        final isDeleting = _deletingLabels.contains(label);
        return LabelChip(
          label: label,
          isDeleting: isDeleting,
          onDelete: widget.onDelete != null ? () => _deleteLabel(label) : null,
        );
      }).toList(),
    );
  }
}

class LabelChip extends StatelessWidget {
  const LabelChip({
    super.key,
    required this.label,
    required this.onDelete,
    this.isDeleting = false,
  });

  final String label;
  final VoidCallback? onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth * 0.8;
    final isSystemLabel = LabelSystem.isSystemLabel(label);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: context.appColors.border,
        borderRadius: BorderRadius.circular(2.0),
      ),
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Row(
        mainAxisSize: .min,
        children: [
          Flexible(
            child: LabelText(
              label,
              style: context.font.labelSmall?.copyWith(
                color: context.appColors.onSurface,
              ),
            ),
          ),
          if (!isSystemLabel && onDelete != null) ...[
            const SizedBox(width: 4),
            if (isDeleting)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    context.appColors.primary,
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: onDelete,
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: context.appColors.primary,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
