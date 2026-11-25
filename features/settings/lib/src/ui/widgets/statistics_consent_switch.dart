import 'dart:async';

import 'package:bull_reporting/statistics.dart';
import 'package:bull_ui/bull_ui.dart' show BullSnackBar;
import 'package:material_ui/material_ui.dart';
import 'package:settings/src/l10n.dart';

class StatisticsConsentSwitch extends StatefulWidget {
  const StatisticsConsentSwitch({super.key, this.showRestartNotice = false});

  final bool showRestartNotice;

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
        SwitchListTile(
          title: Text(context.loc.statisticsConsentTitle),
          subtitle: Text(context.loc.statisticsConsentDescription),
          value: snapshot.data ?? false,
          onChanged: _writing ? null : _change,
        ),
        if (_failedChoice case final choice?)
          Row(
            children: [
              Expanded(child: Text(context.loc.statisticsConsentWriteFailed)),
              TextButton(
                onPressed: _writing ? null : () => _change(choice),
                child: Text(context.loc.statisticsConsentRetry),
              ),
            ],
          ),
      ],
    ),
  );
}
