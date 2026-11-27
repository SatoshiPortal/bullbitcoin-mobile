import 'package:bull_ui/bull_ui.dart'
    show BullShapesX, BullSnackBar, BullThemeX, BullTypographyX;
import 'package:labels/labels.dart';
import 'package:material_ui/material_ui.dart';

import '../label_editor_l10n.dart';
import 'label_text.dart';

class LabelsWidget extends StatefulWidget {
  const LabelsWidget({
    super.key,
    required this.labels,
    this.onDelete,
    this.maxCharacters,
  });

  final List<Label> labels;
  final Future<void> Function(Label)? onDelete;

  /// Shortens each label to this many characters, with an ellipsis.
  final int? maxCharacters;

  String _shown(String label) {
    final max = maxCharacters;
    if (max == null || label.characters.length <= max) return label;
    return '${label.characters.take(max)}…';
  }

  @override
  State<LabelsWidget> createState() => _LabelsWidgetState();
}

class _LabelsWidgetState extends State<LabelsWidget> {
  final Set<Label> _deletingLabels = {};

  Future<void> _deleteLabel(Label label) async {
    final onDelete = widget.onDelete;
    if (onDelete == null || _deletingLabels.contains(label)) return;

    setState(() {
      _deletingLabels.add(label);
    });

    try {
      await onDelete(label);
    } catch (_) {
      if (mounted) {
        BullSnackBar.show(
          context,
          message: context.labelLoc.labelDeleteFailed(label.label),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingLabels.remove(label));
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
          label: widget._shown(label.label),
          isDeleting: isDeleting,
          onDelete: widget.onDelete != null ? () => _deleteLabel(label) : null,
        );
      }).toList(),
    );
  }
}

/// Compact chip rendering a single label string.
///
/// - Provide [onDelete] to render an X affordance (system labels are never
///   deletable). Pass `isDeleting: true` to swap the X for a spinner.
/// - Provide [onTap] to make the whole chip tappable (used for suggestion
///   chips that fill an input on tap). [onTap] and [onDelete] may coexist.
class LabelChip extends StatelessWidget {
  const LabelChip({
    super.key,
    required this.label,
    this.onDelete,
    this.onTap,
    this.isDeleting = false,
  });

  final String label;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.8;
    final isSystemLabel = LabelSystem.isSystemLabel(label);
    final radius = BorderRadius.circular(context.bullShapes.chip);

    final body = Container(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width * 0.03,
        vertical: MediaQuery.sizeOf(context).height * 0.01,
      ),
      decoration: BoxDecoration(
        color: context.bull.onSecondary,
        borderRadius: radius,
        border: Border.all(color: context.bull.secondaryFixedDim),
      ),
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: LabelText(
              label,
              style: context.bullType.body
                  .copyWith(fontWeight: FontWeight.w500)
                  .copyWith(color: context.bull.secondary),
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
                    context.bull.primary,
                  ),
                ),
              )
            else
              Semantics(
                container: true,
                button: true,
                label: MaterialLocalizations.of(context).deleteButtonTooltip,
                child: GestureDetector(
                  onTap: onDelete,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox.square(
                    dimension: 48,
                    child: Center(
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: context.bull.primary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: body,
          ),
        ),
      );
    }
    return body;
  }
}
