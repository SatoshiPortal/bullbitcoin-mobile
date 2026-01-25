import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/log_viewer_widget.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';

class LogSettingsScreen extends StatefulWidget {
  const LogSettingsScreen({super.key});

  @override
  State<LogSettingsScreen> createState() => _LogSettingsScreenState();
}

class _LogSettingsScreenState extends State<LogSettingsScreen> {
  List<String>? _logs;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final logs = await log.readLogs();
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        title: const Text('Logs'),
        backgroundColor: context.appColors.background,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: context.appColors.textMuted),
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: BBText(
          'Loading logs...',
          style: context.font.bodyMedium,
          color: context.appColors.textMuted,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Text('Error loading logs: $_error'),
      );
    }

    final logs = _logs ?? [];
    return LogsViewerWidget(logs: logs);
  }
}
