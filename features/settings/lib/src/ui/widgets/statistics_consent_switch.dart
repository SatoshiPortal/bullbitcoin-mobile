import 'dart:async';

import 'package:bull_reporting/statistics.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullSettingsEntryItem, BullSnackBar, BullSwitch;
import 'package:material_ui/material_ui.dart';
import 'package:settings/src/l10n.dart';

class StatisticsConsentSwitch extends StatefulWidget {
  const StatisticsConsentSwitch({
    super.key,
    this.showRestartNotice = false,
    this.contentPadding = EdgeInsets.zero,
  });

  final bool showRestartNotice;
  final EdgeInsetsGeometry? contentPadding;

  @override
  State<StatisticsConsentSwitch> createState() =>
      _StatisticsConsentSwitchState();
}

class _StatisticsConsentSwitchState extends State<StatisticsConsentSwitch> {
  final _statistics = Statistics.instance;
  bool? _failedChoice;
  bool _writing = false;

  @override
  void initState() {
    super.initState();
    _failedChoice = _statistics.failedChoice;
    unawaited(_statistics.initialize());
  }

  Future<void> _change(bool value) async {
    if (_writing) return;
    setState(() {
      _writing = true;
      _failedChoice = null;
    });
    final saved = await _statistics.setEnabled(value);
    if (!mounted) return;
    setState(() {
      _writing = false;
      _failedChoice = saved ? null : value;
    });
    if (saved && widget.showRestartNotice) {
      BullSnackBar.show(
        context,
        message: context.loc.errorReportingRestartSnackbar,
      );
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
    stream: _statistics.changes,
    initialData: _statistics.enabled,
    builder: (context, snapshot) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MergeSemantics(
          child: BullSettingsEntryItem(
            icon: Icons.bar_chart,
            title: context.loc.statisticsConsentTitle,
            subtitle: context.loc.statisticsConsentDescription,
            contentPadding: widget.contentPadding,
            trailing: BullSwitch(
              value: snapshot.data ?? false,
              onChanged: _writing ? null : _change,
            ),
          ),
        ),
        if (_failedChoice case final choice?)
          Padding(
            // Same inset as the tile above, which falls back to the theme's.
            padding:
                widget.contentPadding ??
                ListTileTheme.of(context).contentPadding ??
                const EdgeInsetsDirectional.only(start: 16, end: 24),
            child: Row(
              children: [
                Expanded(child: Text(context.loc.statisticsConsentWriteFailed)),
                TextButton(
                  onPressed: _writing ? null : () => _change(choice),
                  child: Text(context.loc.statisticsConsentRetry),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
