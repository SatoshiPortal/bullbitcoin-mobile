import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/labels/domain/label_error.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';

extension LabelErrorTranslation on LabelError {
  String toTranslated(BuildContext context) => when(
    notFound: (label) => context.loc.labelErrorNotFound(label),
    unsupportedType: (type) =>
        context.loc.labelErrorUnsupportedType(type.toString()),
    unexpected: (message) =>
        message != null ? context.loc.labelErrorUnexpected(message) : '',
    systemLabelCannotBeDeleted: () => context.loc.labelErrorSystemCannotDelete,
  );
}

class LabelsWidget extends StatefulWidget {
  const LabelsWidget({super.key, required this.labels, this.onDelete});

  final List<Label> labels;
  final Future<void> Function(Label)? onDelete;

  @override
  State<LabelsWidget> createState() => _LabelsWidgetState();
}

class _LabelsWidgetState extends State<LabelsWidget> {
  final _labelsFacade = locator<LabelsFacade>();
  final Set<Label> _deletingLabels = {};

  Future<void> _deleteLabel(Label label) async {
    if (_deletingLabels.contains(label)) return;

    setState(() {
      _deletingLabels.add(label);
    });

    try {
      if (widget.onDelete != null) {
        await widget.onDelete!(label);
      } else {
        await _labelsFacade.trash(label.id);
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
          context.loc.labelDeleteFailed(label.label),
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
          label: label.label,
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
    final radius = BorderRadius.circular(8);

    final body = Container(
      padding: EdgeInsets.symmetric(
        horizontal: Device.screen.width * 0.03,
        vertical: Device.screen.height * 0.01,
      ),
      decoration: BoxDecoration(
        color: context.appColors.onSecondary,
        borderRadius: radius,
        border: Border.all(color: context.appColors.secondaryFixedDim),
      ),
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: LabelText(
              label,
              style: context.font.bodyLarge?.copyWith(
                color: context.appColors.secondary,
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

    if (onTap != null) {
      return InkWell(onTap: onTap, borderRadius: radius, child: body);
    }
    return body;
  }
}
