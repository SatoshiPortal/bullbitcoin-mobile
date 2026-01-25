import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

class DetailsTableItem extends StatefulWidget {
  const DetailsTableItem({
    super.key,
    required this.label,
    this.displayValue,
    this.copyValue,
    this.isUnderline = false,
    this.expandableChild,
    this.displayWidget,
  });

  final String label;
  final String? displayValue;
  final String? copyValue;
  final bool isUnderline;
  final Widget? expandableChild;
  final Widget? displayWidget;

  @override
  State<DetailsTableItem> createState() => _DetailsTableItemState();
}

class _DetailsTableItemState extends State<DetailsTableItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  widget.label,
                  style: context.font.bodySmall?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child:
                          widget.displayWidget ??
                          (widget.displayValue != null
                              ? Text(
                                  widget.displayValue!,
                                  textAlign: TextAlign.end,
                                  overflow: TextOverflow.clip,
                                  style: context.font.bodyMedium?.copyWith(
                                    color: context.appColors.text,
                                    decoration: widget.isUnderline
                                        ? TextDecoration.underline
                                        : TextDecoration.none,
                                  ),
                                )
                              : const LoadingLineContent()),
                    ),
                    if (widget.copyValue != null &&
                        widget.copyValue!.isNotEmpty) ...[
                      const Gap(6),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(text: widget.copyValue!),
                          );
                          SnackBarUtils.showCopiedSnackBar(context);
                        },
                        child: Icon(
                          Icons.copy_outlined,
                          size: 14,
                          color: context.appColors.primary,
                        ),
                      ),
                    ],
                    if (widget.expandableChild != null) ...[
                      const Gap(6),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _expanded = !_expanded;
                          });
                        },
                        child: Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          size: 16,
                          color: context.appColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_expanded && widget.expandableChild != null)
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            child: widget.expandableChild,
          ),
      ],
    );
  }
}
