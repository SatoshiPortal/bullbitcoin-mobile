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
  // btcmap.org reads its theme and basemap from localStorage in a
  // pre-hydration inline script, so they must be set before the page
  // initialises. webview_flutter exposes no document-start injection, so
  // instead we set them on the first loaded page and reload: the reload boots
  // up in the app's theme (see _applyMapTheme). The brightness the map was last
  // primed for, or null until the first load finishes — doubles as the
  // "already primed" flag and lets a live theme change re-sync.
  Brightness? _appliedBrightness;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            // The load can finish after the user has left the screen; bail
            // before touching context or calling setState on a dead State.
            if (!mounted) return;
            if (_appliedBrightness == null) {
              // First load: prime the theme. This triggers a reload, whose own
              // onPageFinished clears the overlay — so keep it up for now.
              await _applyMapTheme(context.theme.brightness);
              return;
            }
            setState(() => _isLoading = false);
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The app theme changed while the screen is open: re-prime and reload so
    // the map's basemap and labels follow. Only after the first prime — the
    // initial one is driven by onPageFinished once the page has loaded.
    final brightness = context.theme.brightness;
    if (_appliedBrightness != null && brightness != _appliedBrightness) {
      // Cover the map with the loading overlay while it reloads into the new
      // theme, mirroring the initial prime.
      setState(() => _isLoading = true);
      _applyMapTheme(brightness);
    }
  }

  /// Pins btcmap to the app's theme by writing the two localStorage keys it
  /// reads on start-up, then reloading so its inline init script runs with them:
  ///
  /// - `theme` (`light`/`dark`) drives the page chrome and map label palette.
  /// - `btcmap-next-basemap` pins the basemap. This is the key the in-map
  ///   basemap picker persists, and `getStoredBasemap()` reads it with priority
  ///   over the theme-derived default. We set it explicitly because the default
  ///   is derived from a Svelte store that still holds its `light` initial value
  ///   at map-init time — so relying on the theme alone leaves a dark app on the
  ///   light `liberty` basemap. `ofm-dark` is OpenFreeMap Dark, `liberty` is
  ///   OpenFreeMap Liberty.
  ///
  /// A reload is required because both keys are read before hydration and a
  /// post-load theme switch only restyles labels, not the basemap tiles.
  Future<void> _applyMapTheme(Brightness brightness) async {
    _appliedBrightness = brightness;
    final isDark = brightness == Brightness.dark;
    final theme = isDark ? 'dark' : 'light';
    final basemap = isDark ? 'ofm-dark' : 'liberty';
    try {
      await _controller.runJavaScript(
        "try { localStorage.theme = '$theme'; "
        "localStorage['btcmap-next-basemap'] = '$basemap'; } catch (e) {}",
      );
      // reload() dispatches the navigation; the loading overlay is cleared by
      // the next onPageFinished, not here.
      if (mounted) await _controller.reload();
    } catch (_) {
      // If priming fails, show the map as-is rather than leaving the user
      // staring at the spinner forever.
      if (mounted) setState(() => _isLoading = false);
    }
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
    // Read the theme unconditionally so this element always depends on it:
    // otherwise, once the loading overlay (the only other theme reader) is
    // gone, a later app-theme change would not fire didChangeDependencies and
    // the map would never re-prime to the new theme.
    final theme = context.theme;
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
                    // Opaque while loading so the brief first (theme-priming)
                    // load and the reload aren't seen behind the spinner.
                    if (_isLoading)
                      Positioned.fill(
                        child: ColoredBox(
                          color: theme.scaffoldBackgroundColor,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
