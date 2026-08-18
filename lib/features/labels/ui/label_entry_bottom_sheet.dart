import 'dart:math' as math;

import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/note_validator.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

/// Shared bottom-sheet editor for user-entered annotations on payment
/// entities. Two distinct semantic modes are exposed via static factories:
///
/// - [LabelEntryBottomSheet.note] — the value is **counterparty-visible**
///   (BIP21 `message=`, lightning swap description, etc.). Always renders
///   a privacy disclosure so the user knows the value will leave the device.
/// - [LabelEntryBottomSheet.label] — the value is a **private local
///   annotation** (transaction tag, address bookmark). No disclosure.
///
/// Both factories return the trimmed string when the user saves, or `null`
/// on dismiss/cancel. Caller is responsible for persisting the result
/// (typically via a bloc/cubit that calls `LabelsFacade.store`).
class LabelEntryBottomSheet extends StatefulWidget {
  const LabelEntryBottomSheet._({
    required this.title,
    this.initialValue,
    this.suggestionsFuture,
    this.hint,
    this.disclosure,
    this.allowEmpty = false,
  });

  final String title;
  final String? initialValue;
  final Future<Set<String>>? suggestionsFuture;
  final String? hint;

  /// Privacy notice rendered under the title when non-null.
  /// Set by [LabelEntryBottomSheet.note]; null for [LabelEntryBottomSheet.label].
  final String? disclosure;
  final bool allowEmpty;

  /// Open the sheet for a counterparty-visible note. The disclosure copy is
  /// resolved from `context.loc.noteVisibleToSenderNotice`.
  static Future<String?> note(
    BuildContext context, {
    required String title,
    String? initialValue,
    Future<Set<String>>? suggestionsFuture,
    String? hint,
  }) {
    return _show(
      context,
      title: title,
      initialValue: initialValue,
      suggestionsFuture: suggestionsFuture,
      hint: hint,
      disclosure: context.loc.noteVisibleToSenderNotice,
      allowEmpty: true,
    );
  }

  /// Open the sheet for a private local label. No disclosure is shown.
  static Future<String?> label(
    BuildContext context, {
    required String title,
    String? initialValue,
    Future<Set<String>>? suggestionsFuture,
    String? hint,
  }) {
    return _show(
      context,
      title: title,
      initialValue: initialValue,
      suggestionsFuture: suggestionsFuture,
      hint: hint,
      disclosure: null,
      allowEmpty: false,
    );
  }

  static Future<String?> _show(
    BuildContext context, {
    required String title,
    String? initialValue,
    Future<Set<String>>? suggestionsFuture,
    String? hint,
    String? disclosure,
    required bool allowEmpty,
  }) {
    return BlurredBottomSheet.show<String>(
      context: context,
      child: LabelEntryBottomSheet._(
        title: title,
        initialValue: initialValue,
        suggestionsFuture: suggestionsFuture,
        hint: hint,
        disclosure: disclosure,
        allowEmpty: allowEmpty,
      ),
    );
  }

  @override
  State<LabelEntryBottomSheet> createState() => _LabelEntryBottomSheetState();
}

class _LabelEntryBottomSheetState extends State<LabelEntryBottomSheet> {
  late final TextEditingController _controller;
  String? _errorMessage;

  String get _trimmed => _controller.text.trim();
  bool get _canSave =>
      _errorMessage == null && (widget.allowEmpty || _trimmed.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
    _controller.addListener(_revalidate);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _revalidate() {
    final result = NoteValidator.validate(_controller.text);
    setState(() {
      _errorMessage = result.isValid ? null : result.errorMessage;
    });
  }

  void _save() {
    if (!_canSave) return;
    context.pop(_trimmed);
  }

  void _applySuggestion(String suggestion) {
    _controller.value = TextEditingValue(
      text: suggestion,
      selection: TextSelection.collapsed(offset: suggestion.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tightGap = Device.screen.height * 0.01;
    final gap = Device.screen.height * 0.02;
    final hPad = Device.screen.width * 0.04;

    return Padding(
      // max(): the keyboard inset already covers the home-indicator area
      // when open; when closed, the indicator inset keeps the save button
      // off the screen edge.
      padding: EdgeInsets.fromLTRB(
        hPad,
        0,
        hPad,
        math.max(
          MediaQuery.of(context).viewInsets.bottom,
          MediaQuery.of(context).viewPadding.bottom,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Gap(gap),
          Row(
            children: [
              const Spacer(),
              BullText(
                widget.title,
                style: context.bullText.headlineMedium,
                color: context.bull.secondary,
              ),
              const Spacer(),
              IconButton(
                onPressed: () => context.pop(),
                color: context.bull.secondary,
                icon: const BullIcon(BullIcons.close),
              ),
            ],
          ),
          if (widget.disclosure != null) ...[
            Gap(tightGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BullIcon(
                  BullIcons.accountTree,
                  size: Device.screen.height * 0.02,
                  color: context.bull.textMuted,
                ),
                Gap(Device.screen.width * 0.02),
                Expanded(
                  child: BullText(
                    widget.disclosure!,
                    style: context.bullText.bodySmall,
                    color: context.bull.textMuted,
                    maxLines: 3,
                  ),
                ),
              ],
            ),
          ],
          if (widget.suggestionsFuture != null) _buildSuggestionsBlock(),
          Gap(gap),
          BullBorderedTile(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BullText(
                  widget.title,
                  style: context.bullText.bodyLarge,
                  color: context.bull.secondary,
                ),
                const Gap(4),
                TextFormField(
                  controller: _controller,
                  autofocus: true,
                  maxLength: NoteValidator.maxNoteLength,
                  maxLines: 1,
                  inputFormatters: [
                    // Strip newline / tab / carriage return on type or paste.
                    FilteringTextInputFormatter.deny(RegExp(r'[\n\t\r]')),
                  ],
                  style: context.bullText.bodyMedium?.copyWith(
                    color: context.bull.secondary,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: widget.hint ?? context.loc.receiveEnterHere,
                    hintStyle: context.bullText.bodyMedium?.copyWith(
                      color: context.bull.textMuted,
                    ),
                    counterText: '',
                  ),
                ),
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            Gap(tightGap),
            BullText(
              _errorMessage!,
              style: context.bullText.bodySmall,
              color: context.bull.error,
            ),
          ],
          Gap(gap),
          BullButton.primary(
            label: context.loc.receiveSave,
            disabled: !_canSave,
            onPressed: _save,
          ),
          Gap(gap),
        ],
      ),
    );
  }

  /// Renders the suggestion strip when there are matching chips (or while
  /// the future is still loading). Returns `SizedBox.shrink()` when nothing
  /// would be visible — the parent always renders its own trailing gap
  /// before the input so this widget never needs to reserve vertical space.
  Widget _buildSuggestionsBlock() {
    return FutureBuilder<Set<String>>(
      future: widget.suggestionsFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final query = _trimmed.toLowerCase();
        final filtered = (snapshot.data ?? const <String>{})
            .where((l) => !LabelSystem.isSystemLabel(l))
            .where((l) => l.toLowerCase().startsWith(query))
            .toList();
        final exactSingle =
            filtered.length == 1 && filtered.first.toLowerCase() == query;
        final showChips = filtered.isNotEmpty && !exactSingle;

        if (!loading && !showChips) return const SizedBox.shrink();

        final tightGap = Device.screen.height * 0.01;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Gap(tightGap),
            if (loading) const BullFadingLinearProgress(trigger: true),
            if (showChips) ...[
              if (loading) Gap(tightGap),
              SizedBox(
                height: Device.screen.height * 0.05,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      SizedBox(width: Device.screen.width * 0.01),
                  itemBuilder: (context, index) {
                    final suggestion = filtered[index];
                    return LabelChip(
                      label: suggestion,
                      onTap: () => _applySuggestion(suggestion),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
