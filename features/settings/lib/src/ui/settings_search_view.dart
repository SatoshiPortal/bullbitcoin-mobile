import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullSettingsEntryItem, BullThemeX, BullTypographyX;

import '../presentation/settings_search.dart';
import '../settings_menu.dart';

/// The settings search surface: a field, and the results for what it holds.
///
/// The destination is pushed over this view so Back restores the query.
class SettingsSearchView extends StatefulWidget {
  final List<SettingsEntry> items;
  final SettingsLabels labels;

  const SettingsSearchView({
    super.key,
    required this.items,
    required this.labels,
  });

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

  void _open(SettingsEntry item) {
    // The destination is pushed over this screen rather than replacing it, so
    // the keyboard would otherwise still be up when it arrives.
    _focusNode.unfocus();
    item.open(context);
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _query.trim().isNotEmpty;
    final results = hasQuery
        ? searchSettings(widget.items, _query)
        : const <SettingsEntry>[];

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const Key('settings-search-field'),
          controller: _controller,
          focusNode: _focusNode,
          onChanged: (query) => setState(() => _query = query),
          maxLines: 1,
          textInputAction: TextInputAction.search,
          style: context.bullType.body
              .copyWith(fontWeight: FontWeight.w500)
              .copyWith(color: context.bull.onSurface),
          decoration: InputDecoration(
            hintText: widget.labels.searchHint,
            hintStyle: context.bullType.body
                .copyWith(fontWeight: FontWeight.w500)
                .copyWith(color: context.bull.textMuted),
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
              color: context.bull.secondary,
              icon: const Icon(Icons.clear),
              onPressed: _clear,
            ),
        ],
      ),
      body: SafeArea(
        child: switch ((hasQuery, results.isEmpty)) {
          (false, _) => _Message(text: widget.labels.searchStartTyping),
          (true, true) => _Message(text: widget.labels.searchNoResults),
          (true, false) => ListView.builder(
            key: const Key('settings-search-results'),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final entry = results[index];
              return BullSettingsEntryItem(
                key: Key('settings-search-result-${entry.id}-$index'),
                icon: entry.icon,
                title: entry.title,
                subtitle: entry.breadcrumbs.join(
                  Directionality.of(context) == TextDirection.rtl
                      ? ' ← '
                      : ' → ',
                ),
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
          style: context.bullType.body
              .copyWith(fontWeight: FontWeight.w500)
              .copyWith(color: context.bull.textMuted),
        ),
      ),
    );
  }
}
