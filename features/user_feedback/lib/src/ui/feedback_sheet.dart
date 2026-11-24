import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:user_feedback/src/feedback_form.dart';
import 'package:user_feedback/src/user_feedback_l10n.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Opens the hosted form in a tall sheet.
///
/// [screenshotPng] is only offered to the user: the form attaches it when they tick the box.
Future<void> showFeedbackSheet(
  BuildContext context, {
  required FeedbackForm form,
  String? screen,
  Uint8List? screenshotPng,
}) async {
  final info = await PackageInfo.fromPlatform();
  if (!context.mounted) return;

  final uri = form.uriFor(
    FeedbackContext(
      appVersion: '${info.version}+${info.buildNumber}',
      platform: defaultTargetPlatform.name.toLowerCase(),
      osVersion: Platform.operatingSystemVersion,
      locale: Localizations.localeOf(context).toLanguageTag(),
      screen: screen,
      dark: Theme.of(context).brightness == Brightness.dark,
    ),
  );

  await BullBottomSheet.show<void>(
    context: context,
    child: FractionallySizedBox(
      heightFactor: 0.92,
      child: _FeedbackSheet(form: form, uri: uri, screenshotPng: screenshotPng),
    ),
  );
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet({
    required this.form,
    required this.uri,
    this.screenshotPng,
  });

  final FeedbackForm form;
  final Uri uri;
  final Uint8List? screenshotPng;

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

enum _Load { loading, ready, failed }

class _FeedbackSheetState extends State<_FeedbackSheet> {
  late final WebViewController _controller;
  _Load _load = _Load.loading;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('FeedbackBridge', onMessageReceived: _onMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted && _load == _Load.loading) {
              setState(() => _load = _Load.ready);
            }
          },
          onWebResourceError: (error) {
            if ((error.isForMainFrame ?? true) && mounted) {
              setState(() => _load = _Load.failed);
            }
          },
          // Stay on the form: no browsing away inside the wallet.
          onNavigationRequest: (request) {
            final target = Uri.tryParse(request.url);
            return target != null && widget.form.owns(target)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      );
    unawaited(_controller.loadRequest(widget.uri));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Match the sheet surface so there is no white flash before the page paints.
    final colors = context.bull;
    unawaited(
      _controller.setBackgroundColor(
        Theme.of(context).brightness == Brightness.light
            ? colors.background
            : colors.surface,
      ),
    );
  }

  void _onMessage(JavaScriptMessage message) {
    switch (message.message) {
      case 'ready':
        final png = widget.screenshotPng;
        if (png != null) {
          unawaited(
            _controller.runJavaScript(
              'window.setScreenshot(${jsonEncode(base64Encode(png))})',
            ),
          );
        }
      case 'sent':
        unawaited(
          Future<void>.delayed(const Duration(milliseconds: 1400), () {
            if (mounted) Navigator.of(context).pop();
          }),
        );
    }
  }

  void _retry() {
    setState(() => _load = _Load.loading);
    unawaited(_controller.loadRequest(widget.uri));
  }

  @override
  Widget build(BuildContext context) {
    final copy = context.feedbackCopy;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: BullText(copy.feedbackTitle, role: BullTextRole.title),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: copy.feedbackClose,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (_load) {
            _Load.failed => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BullText(
                      copy.feedbackLoadError,
                      role: BullTextRole.body,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    BullButton.secondary(
                      label: copy.feedbackRetry,
                      onPressed: _retry,
                    ),
                  ],
                ),
              ),
            ),
            _ => Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_load == _Load.loading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          },
        ),
      ],
    );
  }
}
