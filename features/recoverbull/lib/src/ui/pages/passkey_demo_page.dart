import 'dart:async';

import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

import '../../domain/passkey_demo_operation.dart';
import '../../domain/repositories/passkey_demo_repository.dart';
import '../../domain/usecases/run_passkey_demo_usecase.dart';
import '../../l10n/context_localizations.dart';

class PasskeyDemoEntry extends StatefulWidget {
  final RunPasskeyDemoUsecase demo;
  final bool alternative;

  const PasskeyDemoEntry({
    super.key,
    required this.demo,
    this.alternative = false,
  });

  @override
  State<PasskeyDemoEntry> createState() => _PasskeyDemoEntryState();
}

class _PasskeyDemoEntryState extends State<PasskeyDemoEntry> {
  late Future<bool> _enabled = widget.demo.isEnabled();
  bool _opening = false;
  Timer? _timer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_checking || _opening) return;
    _checking = true;
    try {
      final enabled = await widget.demo.isEnabled();
      if (mounted) {
        setState(() {
          _enabled = Future.value(enabled);
        });
      }
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _open() async {
    if (_opening) return;
    _opening = true;
    try {
      final demo = widget.demo;
      if (await demo.isEnabled() && mounted) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => PasskeyDemoPage(demo: demo)),
        );
      }
    } finally {
      _opening = false;
      if (mounted) {
        final enabled = widget.demo.isEnabled();
        setState(() {
          _enabled = enabled;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _enabled,
    builder: (context, snapshot) => snapshot.data == true
        ? widget.alternative
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: BullButton.secondary(
                    label: context.loc.recoverbullUsePasskeyInstead,
                    onPressed: _open,
                  ),
                )
              : BullSettingsEntryItem(
                  icon: Icons.lock_outline,
                  title: context.loc.recoverbullPasskeyDemoTitle,
                  onTap: _open,
                )
        : const SizedBox.shrink(),
  );
}

class PasskeyDemoPage extends StatefulWidget {
  final RunPasskeyDemoUsecase demo;
  final String? initialAccountId;
  final String? initialContent;
  final bool startImmediately;

  const PasskeyDemoPage({
    super.key,
    required this.demo,
    this.initialAccountId,
    this.initialContent,
    this.startImmediately = false,
  });

  @override
  State<PasskeyDemoPage> createState() => _PasskeyDemoPageState();
}

class _PasskeyDemoPageState extends State<PasskeyDemoPage> {
  String? _accountId;
  String? _content;
  PasskeyDemoFailure? _failure;
  bool _busy = false;
  bool _checking = false;
  Timer? _timer;
  PasskeyDemoOperation? _operation;

  @override
  void initState() {
    super.initState();
    _accountId = widget.initialAccountId;
    _content = widget.initialContent;
    if (widget.startImmediately) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _run();
      });
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _checkAccess());
  }

  Future<void> _checkAccess() async {
    if (_checking) return;
    _checking = true;
    try {
      if (!await widget.demo.isEnabled()) {
        _operation?.cancel();
        if (mounted) {
          setState(() {
            _accountId = null;
            _content = null;
            _failure = PasskeyDemoFailure.disabled;
          });
        }
      }
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _operation?.cancel();
    _accountId = null;
    _content = null;
    super.dispose();
  }

  Future<void> _run() async {
    if (_busy) return;
    final accountId = _accountId;
    setState(() {
      _busy = true;
      _content = null;
      _failure = null;
    });
    final operation = widget.demo.newOperation();
    _operation = operation;
    final result = await widget.demo.execute(
      accountId: accountId,
      operation: operation,
    );
    if (identical(_operation, operation)) _operation = null;
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (result) {
        case Ok(value: final value):
          if (accountId == null) {
            _accountId = value;
          } else {
            _content = value;
          }
        case Err(failure: final failure):
          _failure = failure;
          if (failure == PasskeyDemoFailure.disabled) _accountId = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final message = switch (_failure) {
      PasskeyDemoFailure.disabled => loc.recoverbullPasskeyDemoDisabled,
      PasskeyDemoFailure.cancelled => loc.recoverbullPasskeyDemoCancelled,
      PasskeyDemoFailure.unavailable => loc.recoverbullPasskeyDemoUnavailable,
      null => null,
    };
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _operation?.cancel();
          _accountId = null;
          _content = null;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: BullText(loc.recoverbullPasskeyDemoTitle),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            BullText(loc.recoverbullPasskeyDemoDescription),
            const Gap(16),
            BullButton.primary(
              label: _accountId == null
                  ? loc.recoverbullPasskeyDemoRegister
                  : loc.recoverbullPasskeyDemoOpen,
              onPressed: _busy ? null : _run,
            ),
            if (_busy) const BullFadingLinearProgress(trigger: true),
            if (message != null) ...[const Gap(16), BullText(message)],
            if (_content case final content?) ...[
              const Gap(16),
              BullText(content),
            ],
          ],
        ),
      ),
    );
  }
}
