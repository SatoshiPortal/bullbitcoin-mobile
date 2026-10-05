import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:bb_mobile/features/settings/ui/settings_search.dart';
import 'package:flutter/material.dart';

/// The settings search surface: a field, and the results for what it holds.
///
/// Takes the registry it searches rather than resolving it, so it can be
/// rendered and tested without the settings cubit. [SettingsSearchScreen] is the
/// one place that resolves it.
class SettingsSearchView extends StatefulWidget {
  final List<SettingsItem> items;

  const SettingsSearchView({super.key, required this.items});

  @override
  State<SettingsSearchView> createState() => _SettingsSearchViewState();
}

class _SettingsSearchViewState extends State<SettingsSearchView> {
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

  void _clear() {
    _controller.clear();
    setState(() => _query = '');
    _focusNode.requestFocus();
  }

  void _open(SettingsItem item) {
    // The destination is pushed over this screen rather than replacing it, so
    // the keyboard would otherwise still be up when it arrives.
    _focusNode.unfocus();
    item.open(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasQuery = _query.trim().isNotEmpty;
    final results = hasQuery
        ? searchSettings(widget.items, _query)
        : const <SettingsItem>[];

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const Key('settings-search-field'),
          controller: _controller,
          focusNode: _focusNode,
          onChanged: (query) => setState(() => _query = query),
          maxLines: 1,
          textInputAction: TextInputAction.search,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: context.appColors.onSurface,
          ),
          decoration: InputDecoration(
            hintText: context.loc.settingsSearchHint,
            hintStyle: theme.textTheme.bodyLarge?.copyWith(
              color: context.appColors.textMuted,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
        actionsPadding: const EdgeInsets.only(right: 8),
        actions: [
          if (hasQuery)
            IconButton(
              key: const Key('settings-search-clear'),
              tooltip: MaterialLocalizations.of(context).clearButtonTooltip,
              color: context.appColors.secondary,
              icon: const Icon(Icons.clear),
              onPressed: _clear,
            ),
        ],
      ),
      body: SafeArea(
        child: switch ((hasQuery, results.isEmpty)) {
          (false, _) => _Message(text: context.loc.settingsSearchStartTyping),
          (true, true) => _Message(text: context.loc.settingsSearchNoResults),
          (true, false) => ListView.builder(
            key: const Key('settings-search-results'),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final entry = results[index];
              return SettingsEntryItem(
                key: Key('settings-search-result-${entry.id.name}-$index'),
                icon: entry.icon,
                title: entry.title,
                subtitle: entry.location(Directionality.of(context)),
                isSuperUser: entry.isSuperuser,
                onTap: () => _open(entry),
              );
            },
          ),
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;

  const _Message({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: context.appColors.textMuted),
        ),
      ),
    );
  }
}
