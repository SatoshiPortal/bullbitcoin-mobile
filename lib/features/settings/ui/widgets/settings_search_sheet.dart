import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:bb_mobile/features/settings/ui/settings_search.dart';
import 'package:bull_ui/bull_ui.dart' show BullBottomSheet, Gap;
import 'package:flutter/material.dart';

class SettingsSearchSheet extends StatefulWidget {
  final List<SettingsItem> items;
  final double heightFactor;

  const SettingsSearchSheet({
    super.key,
    required this.items,
    this.heightFactor = 0.55,
  }) : assert(heightFactor > 0 && heightFactor <= 1);

  static Future<SettingsItem?> show({
    required BuildContext context,
    required List<SettingsItem> items,
    double heightFactor = 0.55,
  }) {
    return BullBottomSheet.show<SettingsItem>(
      context: context,
      child: SettingsSearchSheet(items: items, heightFactor: heightFactor),
    );
  }

  @override
  State<SettingsSearchSheet> createState() => _SettingsSearchSheetState();
}

class _SettingsSearchSheetState extends State<SettingsSearchSheet> {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final hasQuery = _query.trim().isNotEmpty;
    final results = hasQuery
        ? searchSettings(widget.items, _query)
        : const <SettingsItem>[];

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: SizedBox(
        key: const Key('settings-search-sheet-content'),
        height: MediaQuery.sizeOf(context).height * widget.heightFactor,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appColors.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Gap(20),
              Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      context.loc.settingsSearchHint,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: context.appColors.secondary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.loc.closeDialogButton,
                    onPressed: () => Navigator.of(context).pop(),
                    color: context.appColors.secondary,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Gap(24),
              TextField(
                key: const Key('settings-search-field'),
                controller: _controller,
                focusNode: _focusNode,
                onChanged: (query) => setState(() => _query = query),
                maxLines: 1,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: context.loc.settingsSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: hasQuery
                      ? IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).clearButtonTooltip,
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const Gap(12),
              Expanded(
                child: !hasQuery
                    ? Center(
                        child: Text(
                          context.loc.settingsSearchStartTyping,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: context.appColors.textMuted,
                          ),
                        ),
                      )
                    : results.isEmpty
                    ? Center(
                        child: Text(
                          context.loc.settingsSearchNoResults,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: context.appColors.textMuted,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final entry = results[index];
                          return SettingsEntryItem(
                            key: Key(
                              'settings-search-result-${entry.id.name}-$index',
                            ),
                            icon: entry.icon,
                            title: entry.title,
                            subtitle: entry.location(
                              Directionality.of(context),
                            ),
                            isSuperUser: entry.isSuperuser,
                            onTap: () => Navigator.of(context).pop(entry),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
