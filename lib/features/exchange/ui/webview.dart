// ignore_for_file: unused_field, use_late_for_private_fields_and_variables, use_build_context_synchronously, unused_element

import 'dart:async';
import 'dart:io' show Platform;

import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class BullBitcoinWebView extends StatefulWidget {
  const BullBitcoinWebView({super.key});

  @override
  State<BullBitcoinWebView> createState() => _BullBitcoinWebViewState();
}

class _BullBitcoinWebViewState extends State<BullBitcoinWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _cookieCheckTimer;
  bool _authenticated = false;
  String? _currentUrl;
  Map<String, String> _allCookies = {};
  final Map<String, Map<String, String>> _iframeCookies = {};

  final String _targetAuthCookie = 'bb_session';

  final List<String> _ignoredCookies = [
    'i18n',
    'i18n-lng',
    'i18next',
    'django_language',
    'language',
    'locale',
    'hl',
  ];

  final String _baseUrl = ApiServiceConstants.bbAuthUrl;

  // Variable to track cookie polling attempts
  int _cookieCheckAttempts = 0;
  final int _maxCookieCheckAttempts =
      30; // Maximum 30 polling attempts (1 minute at 2-second intervals)

  @override
  void initState() {
    super.initState();

    // Setup WebViewController
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (url) {
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
            // Reset cookie check attempts on new page load
            _cookieCheckAttempts = 0;
            // Add a small delay before checking cookies to ensure page is fully loaded
            Future.delayed(const Duration(milliseconds: 500), () {
              _checkAllCookies();
              _startCookiePolling();
            });
          },
          onUrlChange: (UrlChange change) {
            final currentUrl = change.url;
            if (currentUrl != null) {
              setState(() => _currentUrl = currentUrl);
              _checkAllCookies();
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
            setState(() {
              _hasError = true;
              _errorMessage = '${error.errorType}: ${error.description}';
              _isLoading = false;
            });
            _stopCookiePolling();
          },
          onHttpAuthRequest: (HttpAuthRequest request) {
            request.onProceed(
              WebViewCredential(
                user: dotenv.env['BASIC_AUTH_USERNAME'] ?? '',
                password: dotenv.env['BASIC_AUTH_PASSWORD'] ?? '',
              ),
            );
          },
        ),
      )
      // Set a more authentic user agent
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1',
      );

    if (Platform.isAndroid) {
      AndroidWebViewController.enableDebugging(false);
      final androidController =
          _controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
    } else if (Platform.isIOS) {
      final iosController = _controller.platform as WebKitWebViewController;
      iosController.setAllowsBackForwardNavigationGestures(true);
    }

    _loadUrlWithBasicAuth();
    _cookieManager();
  }

  Future<void> _cookieManager() async {
    try {
      final cookieManager = WebviewCookieManager();
      final gotCookies = await cookieManager.getCookies('https://$_baseUrl');

      // Debug logging for all cookies
      if (gotCookies.isNotEmpty) {
        debugPrint('Cookies found during initialization:');
        for (final cookie in gotCookies) {
          debugPrint('${cookie.name}: ${cookie.value}');

          // Check for session cookie
          if (cookie.name == _targetAuthCookie) {
            debugPrint('BB_SESSION FOUND DURING INITIALIZATION!');
            // Don't use the removed method
            setState(() {
              _authenticated = true;
              _allCookies[_targetAuthCookie] = cookie.value;
            });
            _stopCookiePolling();
            return;
          }
        }
      } else {
        debugPrint('No cookies found during initialization');
      }

      // Continue with additional cookie checks if no session cookie found
      bool containsSessionToken = false;
      bool containsCsrfToken = false;
      for (final item in gotCookies) {
        if (item.name.contains('csrf')) {
          containsCsrfToken = true;
        }
        if (item.name == 'bb_session') {
          containsSessionToken = true;
        }
      }

      if (containsCsrfToken && containsSessionToken) {
        // Keep the query parameter when navigating to BBX_URL
        final bbxUrl = dotenv.env['BBX_URL'];
        if (bbxUrl != null && bbxUrl.isNotEmpty) {
          final Uri url = Uri.parse('https://$bbxUrl');
          _controller.loadRequest(url);
        }
      }
    } catch (e) {
      debugPrint('Error in cookie manager: $e');
    }
  }

  @override
  void dispose() {
    _stopCookiePolling();
    super.dispose();
  }

  void _startCookiePolling() {
    if (_cookieCheckTimer != null) return; // Already polling

    _cookieCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _cookieCheckAttempts++;
      if (_cookieCheckAttempts > _maxCookieCheckAttempts) {
        debugPrint(
          'Reached maximum cookie polling attempts. Stopping polling.',
        );
        _stopCookiePolling();
        return;
      }
      _checkAllCookies();
    });

    debugPrint('Started cookie polling (attempt $_cookieCheckAttempts)');
  }

  void _stopCookiePolling() {
    _cookieCheckTimer?.cancel();
    _cookieCheckTimer = null;
  }

  Future<void> _checkAllCookies() async {
    if (_authenticated) return; // Already authenticated

    // Only use native cookie detection since it's working
    await _checkNativeCookies();
  }

  // Check cookies using the native cookie manager
  Future<bool> _checkNativeCookies() async {
    try {
      final cookieManager = WebviewCookieManager();
      final nativeCookies = await cookieManager.getCookies('https://$_baseUrl');

      debugPrint('Native cookie count: ${nativeCookies.length}');

      // Update all cookies map
      final Map<String, String> cookieMap = {};
      for (final cookie in nativeCookies) {
        cookieMap[cookie.name] = cookie.value;
      }

      setState(() {
        _allCookies = cookieMap;
      });

      // Find the session cookie
      for (final cookie in nativeCookies) {
        if (cookie.name == _targetAuthCookie) {
          debugPrint('===== SESSION COOKIE FOUND =====');
          debugPrint('bb_session=${cookie.value}');
          debugPrint('================================');

          // Mark as authenticated but don't pop context
          _authenticated = true;
          _stopCookiePolling();
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error checking native cookies: $e');
    }
    return false;
  }

  Future<void> _loadUrlWithBasicAuth() async {
    try {
      // Add the query parameter to the URL
      final Uri url = Uri.parse('https://$_baseUrl');
      _controller.loadRequest(url);
    } catch (e) {
      debugPrint('Error loading URL with basic auth: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load the page: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        flexibleSpace: const SizedBox.shrink(),
        forceMaterialTransparency: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (_hasError)
              _ErrorView(
                message: _errorMessage,
                onRetry: () => Navigator.of(context).pop(),
              )
            else
              WebViewWidget(controller: _controller),
            if (_isLoading && !_hasError)
              const Center(child: CircularProgressIndicator()),
            // Add debug button in non-production builds
          ],
        ),
      ),
    );
  }

  void _showCookiesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cookie Debug'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current URL: $_currentUrl'),
              Text('Authenticated: $_authenticated'),
              Text('Polling attempts: $_cookieCheckAttempts'),
              const Divider(),
              const Text(
                'Cookies:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_allCookies.isEmpty)
                const Text('No cookies found')
              else
                ..._allCookies.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('${entry.key}: ${entry.value}'),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _checkNativeCookies();
                },
                child: const Text('Check Cookies Now'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  final cookieValue = _allCookies[_targetAuthCookie];
                  if (cookieValue != null) {
                    // Return to the previous screen with the cookie
                    context.pop({
                      'authenticated': true,
                      'cookieName': _targetAuthCookie,
                      'cookieValue': cookieValue,
                      'allCookies': _allCookies,
                      'timestamp': DateTime.now().millisecondsSinceEpoch,
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No session cookie found')),
                    );
                  }
                },
                child: const Text('Return with Cookie'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            const BBText(
              'Error loading Bull Bitcoin Exchange',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            BBText(message, style: TextStyle(color: context.colour.onError)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              child: BBText(
                'Go Back',
                style: TextStyle(color: context.colour.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
