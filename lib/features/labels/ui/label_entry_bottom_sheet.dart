import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/note_validator.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/tiles/bordered_tappable_tile.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
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
  });

  final String title;
  final String? initialValue;
  final Future<Set<String>>? suggestionsFuture;
  final String? hint;

  /// Privacy notice rendered under the title when non-null.
  /// Set by [LabelEntryBottomSheet.note]; null for [LabelEntryBottomSheet.label].
  final String? disclosure;

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
    );
  }

  static Future<String?> _show(
    BuildContext context, {
    required String title,
    String? initialValue,
    Future<Set<String>>? suggestionsFuture,
    String? hint,
    String? disclosure,
  }) {
    return BlurredBottomSheet.show<String>(
      context: context,
      child: LabelEntryBottomSheet._(
        title: title,
        initialValue: initialValue,
        suggestionsFuture: suggestionsFuture,
        hint: hint,
        disclosure: disclosure,
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
  bool get _canSave => _errorMessage == null && _trimmed.isNotEmpty;

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
      padding: EdgeInsets.fromLTRB(
        hPad,
        0,
        hPad,
        MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Gap(gap),
          Row(
            children: [
              const Spacer(),
              BBText(
                widget.title,
                style: context.font.headlineMedium,
                color: context.appColors.secondary,
              ),
              const Spacer(),
              IconButton(
                onPressed: () => context.pop(),
                color: context.appColors.secondary,
                icon: const Icon(Icons.close_sharp),
              ),
            ],
          ),
          if (widget.disclosure != null) ...[
            Gap(tightGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: Device.screen.height * 0.02,
                  color: context.appColors.onSurfaceVariant,
                ),
                Gap(Device.screen.width * 0.02),
                Expanded(
                  child: BBText(
                    widget.disclosure!,
                    style: context.font.bodySmall,
                    color: context.appColors.onSurfaceVariant,
                    maxLines: 3,
                  ),
                ),
              ],
            ),
          ],
          if (widget.suggestionsFuture != null) _buildSuggestionsBlock(),
          Gap(gap),
          BorderedTappableTile(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText(
                  widget.title,
                  style: context.font.bodyLarge,
                  color: context.appColors.secondary,
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
                  style: context.font.bodyMedium?.copyWith(
                    color: context.appColors.secondary,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText:
                        widget.hint ?? context.loc.receiveEnterHere,
                    hintStyle: context.font.bodyMedium?.copyWith(
                      color: context.appColors.onSurfaceVariant,
                    ),
                    counterText: '',
                  ),
                ),
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            Gap(tightGap),
            BBText(
              _errorMessage!,
              style: context.font.bodySmall,
              color: context.appColors.error,
            ),
          ],
          Gap(gap),
          BBButton.big(
            label: context.loc.receiveSave,
            disabled: !_canSave,
            onPressed: _save,
            bgColor: context.appColors.secondary,
            textColor: context.appColors.onSecondary,
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
        final loading =
            snapshot.connectionState == ConnectionState.waiting;
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
            if (loading) FadingLinearProgress(trigger: true),
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

