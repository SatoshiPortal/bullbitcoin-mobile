import 'dart:io';

import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// Whether [url] may load inside the WebView: https on btcmap.org or one of
/// its subdomains. The host is derived from [SettingsConstants.btcMapUrl] so
/// the load URL and the allowlist cannot drift apart.
@visibleForTesting
bool isBtcMapUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return false;
  final btcMapHost = Uri.parse(SettingsConstants.btcMapUrl).host;
  return uri.host == btcMapHost || uri.host.endsWith('.$btcMapHost');
}

class BtcMapScreen extends StatefulWidget {
  const BtcMapScreen({super.key});

  @override
  State<BtcMapScreen> createState() => _BtcMapScreenState();
}

class _BtcMapScreenState extends State<BtcMapScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            // A failed subresource (a single map tile, a blocked beacon) must
            // not tear down the whole screen — only main-frame failures do.
            if ((error.isForMainFrame ?? true) && mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            if (isBtcMapUrl(request.url)) {
              return NavigationDecision.navigate;
            }
            // Merchant popups link out (website, OSM, socials, tel/mailto):
            // open those externally instead of silently swallowing the tap.
            final uri = Uri.tryParse(request.url);
            if (uri != null) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
            }
            return NavigationDecision.prevent;
          },
        ),
      );

    final platformController = _controller.platform;
    if (Platform.isIOS && platformController is WebKitWebViewController) {
      platformController.setAllowsBackForwardNavigationGestures(true);
    }

    _controller.loadRequest(Uri.parse(SettingsConstants.btcMapUrl));
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    _controller.loadRequest(Uri.parse(SettingsConstants.btcMapUrl));
  }

  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    if (didPop) return;
    // Mirror iOS's in-page back gestures: system back walks the WebView
    // history first and only pops the route once there is nothing left.
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
        appBar: AppBar(title: Text(context.loc.settingsBtcMapTitle)),
        body: SafeArea(
          child: _hasError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.loc.oopsSomethingWentWrong),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _retry,
                        child: Text(context.loc.retry),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    WebViewWidget(controller: _controller),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
        ),
      ),
    );
  }
}
