import 'package:bb_mobile/core/labels/domain/delete_label_usecase.dart';
import 'package:bb_mobile/core/labels/domain/label.dart';
import 'package:bb_mobile/core/labels/domain/label_error.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/label_text.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';

class LabelsWidget extends StatefulWidget {
  const LabelsWidget({super.key, required this.labels, this.onDelete});

  final List<Label> labels;
  final Future<void> Function(Label)? onDelete;

  @override
  State<LabelsWidget> createState() => _LabelsWidgetState();
}

class _LabelsWidgetState extends State<LabelsWidget> {
  final _deleteLabelUsecase = locator<DeleteLabelUsecase>();
  final Set<String> _deletingLabels = {};

  Future<void> _deleteLabel(Label label) async {
    if (_deletingLabels.contains(label.label)) return;

    setState(() {
      _deletingLabels.add(label.label);
    });

    try {
      if (widget.onDelete != null) {
        await widget.onDelete!(label);
      } else {
        await _deleteLabelUsecase.execute(label);
      }
      if (mounted) {
        setState(() => _deletingLabels.remove(label.label));
      }
    } on LabelError catch (e) {
      if (mounted) {
        setState(() => _deletingLabels.remove(label.label));
        SnackBarUtils.showSnackBar(context, e.toTranslated(context));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deletingLabels.remove(label.label));
        SnackBarUtils.showSnackBar(
          context,
          context.loc.labelDeleteFailed(label.label),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.labels.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.labels.map((label) {
        final isDeleting = _deletingLabels.contains(label.label);
        return LabelChip(
          label: label,
          isDeleting: isDeleting,
          onDelete: () => _deleteLabel(label),
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

  final Label label;
  final VoidCallback onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth * 0.8;

    return Container(
      decoration: BoxDecoration(
        color: context.appColors.onPrimary,
        border: Border.all(color: context.appColors.surface),
        borderRadius: BorderRadius.circular(3),
      ),
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: .min,
          children: [
            Flexible(
              child: GestureDetector(
                child: LabelText(
                  label,
                  style: context.font.bodySmall?.copyWith(
                    color: context.appColors.outlineVariant,
                  ),
                ),
              ),
            ),
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
        ),
      ),
    );
  }
}
