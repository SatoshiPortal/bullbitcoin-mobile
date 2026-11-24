import 'dart:math' as math;

import 'package:bull_ui/bull_ui.dart'
    show
        BullBorderedTile,
        BullBottomSheet,
        BullButton,
        BullFadingLinearProgress,
        BullText,
        BullThemeX,
        BullTypographyX,
        Gap;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:label_editor/src/domain/note_violation_to_label_failure.dart';
import 'package:labels/labels.dart';
import 'package:material_ui/material_ui.dart';

import '../label_editor_feature.dart' show labelEditorRouteName;
import '../label_editor_l10n.dart';
import '../presentation/label_failure_l10n.dart';
import 'labels_widget.dart';

/// Shared bottom-sheet editor for user-entered annotations on payment
/// entities. Two distinct semantic modes are exposed via static factories:
///
/// - [LabelEditor.note] — the value is **counterparty-visible**
///   (BIP21 `message=`, lightning swap description, etc.). Always renders
///   a privacy disclosure so the user knows the value will leave the device.
/// - [LabelEditor.label] — the value is a **private local
///   annotation** (transaction tag, address bookmark). No disclosure.
///
/// Both factories return the trimmed string when the user saves, or `null`
/// on dismiss/cancel. Caller is responsible for persisting the result
/// (typically via a bloc/cubit that calls `Labels.store`).
abstract final class LabelEditor {
  /// Opens the BIP-329 label management page.
  static Future<void> open(BuildContext context) =>
      context.pushNamed<void>(labelEditorRouteName);

  /// The localized validation error for an inline note, or null if valid.
  static String? validateNote(BuildContext context, String value) =>
      _validateNote(value)?.toTranslated(context);

  /// Open the sheet for a counterparty-visible note. The disclosure copy is
  /// resolved from `context.labelLoc.noteVisibleToSenderNotice`.
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
      disclosure: context.labelLoc.noteVisibleToSenderNotice,
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
    return BullBottomSheet.show<String>(
      context: context,
      child: _LabelEntryBottomSheet(
        title: title,
        initialValue: initialValue,
        suggestionsFuture: suggestionsFuture,
        hint: hint,
        disclosure: disclosure,
        allowEmpty: allowEmpty,
      ),
    );
  }
}

class _LabelEntryBottomSheet extends StatefulWidget {
  const _LabelEntryBottomSheet({
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
  /// Set by [LabelEditor.note]; null for [LabelEditor.label].
  final String? disclosure;
  final bool allowEmpty;

  @override
  State<_LabelEntryBottomSheet> createState() => _LabelEntryBottomSheetState();
}

class _LabelEntryBottomSheetState extends State<_LabelEntryBottomSheet> {
  late final TextEditingController _controller;
  LabelFailure? _failure;

  String get _trimmed => _controller.text.trim();
  bool get _canSave =>
      _failure == null && (widget.allowEmpty || _trimmed.isNotEmpty);

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
    setState(() {
      _failure = _validateNote(_controller.text);
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
    final tightGap = MediaQuery.sizeOf(context).height * 0.01;
    final gap = MediaQuery.sizeOf(context).height * 0.02;
    final hPad = MediaQuery.sizeOf(context).width * 0.04;
    final inputHint = widget.hint ?? context.labelLoc.receiveEnterHere;

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
              Semantics(
                header: true,
                namesRoute: true,
                label: widget.title,
                excludeSemantics: true,
                child: BullText(
                  widget.title,
                  style: context.bullType.subtitle.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  color: context.bull.secondary,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => context.pop(),
                color: context.bull.secondary,
                icon: const Icon(Icons.close_sharp),
              ),
            ],
          ),
          if (widget.disclosure case final disclosure?) ...[
            Gap(tightGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: MediaQuery.sizeOf(context).height * 0.02,
                  color: context.bull.onSurfaceVariant,
                ),
                Gap(MediaQuery.sizeOf(context).width * 0.02),
                Expanded(
                  child: BullText(
                    disclosure,
                    style: context.bullType.label.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                    color: context.bull.onSurfaceVariant,
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
                ExcludeSemantics(
                  child: BullText(
                    widget.title,
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    color: context.bull.secondary,
                  ),
                ),
                const Gap(4),
                Semantics(
                  label: widget.title,
                  hint: inputHint,
                  child: TextFormField(
                    controller: _controller,
                    autofocus: true,
                    maxLength: NoteValidator.maxNoteLength,
                    maxLines: 1,
                    inputFormatters: [
                      // Strip newline / tab / carriage return on type or paste.
                      FilteringTextInputFormatter.deny(RegExp(r'[\n\t\r]')),
                    ],
                    style: context.bullType.body.copyWith(
                      color: context.bull.secondary,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hint: ExcludeSemantics(
                        child: Text(
                          inputHint,
                          style: context.bullType.body.copyWith(
                            color: context.bull.onSurfaceVariant,
                          ),
                        ),
                      ),
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_failure case final failure?) ...[
            Gap(tightGap),
            BullText(
              failure.toTranslated(context),
              style: context.bullType.label.copyWith(
                fontWeight: FontWeight.w400,
              ),
              color: context.bull.error,
            ),
          ],
          Gap(gap),
          BullButton.primary(
            label: context.labelLoc.receiveSave,
            onPressed: (!_canSave) ? null : _save,
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

        final tightGap = MediaQuery.sizeOf(context).height * 0.01;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Gap(tightGap),
            if (loading) BullFadingLinearProgress(trigger: true),
            if (showChips) ...[
              if (loading) Gap(tightGap),
              SizedBox(
                height: math.max(
                  48.0,
                  MediaQuery.sizeOf(context).height * 0.05,
                ),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      SizedBox(width: MediaQuery.sizeOf(context).width * 0.01),
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

LabelFailure? _validateNote(String value) {
  final violation = NoteValidator.validate(value);
  return violation == null ? null : mapNoteViolationToLabelFailure(violation);
}
