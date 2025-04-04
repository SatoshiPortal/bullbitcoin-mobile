// ignore_for_file: unused_field, use_late_for_private_fields_and_variables, use_build_context_synchronously, unused_element

import 'dart:async';
import 'dart:convert';
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

  // The specific cookie name we're looking for
  final String _targetAuthCookie = 'bb_session';

  // Cookies to ignore (not related to authentication)
  final List<String> _ignoredCookies = [
    'i18n',
    'i18n-lng',
    'i18next',
    'django_language',
    'language',
    'locale',
    'hl',
  ];

  // Base URL of the site
  final String _baseUrl = ApiServiceConstants.bbAuthUrl;

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

            // Check cookies after page loads
            _checkAllCookies();

            // Start cookie polling if not already started
            _startCookiePolling();
          },
          onUrlChange: (UrlChange change) {
            final currentUrl = change.url;
            if (currentUrl != null) {
              setState(() => _currentUrl = currentUrl);
              // Check cookies when URL changes
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
          // Handle HTTP Basic Auth
          onHttpAuthRequest: (HttpAuthRequest request) {
            request.onProceed(
              WebViewCredential(
                user: dotenv.env['BASIC_AUTH_USERNAME'] ?? '',
                password: dotenv.env['BASIC_AUTH_PASSWORD'] ?? '',
              ),
            );
          },
        ),
      );

    // Platform-specific setup
    if (Platform.isAndroid) {
      AndroidWebViewController.enableDebugging(false);
      final androidController =
          _controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
    } else if (Platform.isIOS) {
      final iosController = _controller.platform as WebKitWebViewController;
      iosController.setAllowsBackForwardNavigationGestures(true);
    }

    // Load the URL with Basic Auth
    _loadUrlWithBasicAuth();
    _cookieManager();
  }

  Future<void> _cookieManager() async {
    final cookieManager = WebviewCookieManager();
    // await cookieManager.clearCookies();

    final gotCookies =
        await cookieManager.getCookies('https://$_baseUrl?generateAPIKey=xyz');
    bool containsSessionToken = false;
    bool containerCsrfToken = false;
    for (final item in gotCookies) {
      if (item.name.contains('csrf')) {
        containerCsrfToken = true;
      }
      if (item.name == 'bb_session') {
        containsSessionToken = true;
      }
    }

    if (containerCsrfToken && containsSessionToken) {
      final Uri url = Uri.parse('https://${dotenv.env['BBX_URL']}/');
      _controller.loadRequest(url);
    }
  }

  @override
  void dispose() {
    _stopCookiePolling();
    super.dispose();
  }

  void _startCookiePolling() {
    if (_cookieCheckTimer != null) return; // Already polling

    // Create a timer to periodically check for authentication cookies
    _cookieCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkAllCookies();
    });

    debugPrint('Started cookie polling');
  }

  void _stopCookiePolling() {
    _cookieCheckTimer?.cancel();
    _cookieCheckTimer = null;
  }

  Future<void> _checkAllCookies() async {
    if (_authenticated) return; // Already authenticated

    try {
      // Execute JavaScript to extract all cookies from the main document and iframes
      final result = await _controller.runJavaScriptReturningResult('''
        (function() {
          // Get cookies from the main document
          var mainCookies = {};
          document.cookie.split('; ').forEach(function(cookie) {
            var parts = cookie.split('=');
            if (parts.length == 2) {
              mainCookies[parts[0]] = parts[1];
            }
          });
          
          // Get cookies from all iframes
          var iframeCookies = {};
          try {
            var iframes = document.querySelectorAll('iframe');
            for (var i = 0; i < iframes.length; i++) {
              var iframe = iframes[i];
              try {
                var frameSrc = iframe.src || 'unnamed_frame_' + i;
                var frameId = 'frame_' + i + '_' + frameSrc.replace(/[^a-zA-Z0-9]/g, '_');
                
                // Try to access cookies from the iframe
                // Note: This will only work for same-origin iframes
                var iframeCookieStr = '';
                try {
                  iframeCookieStr = iframe.contentDocument.cookie;
                } catch(e) {
                  // Cross-origin iframe, can't access cookies
                  iframeCookieStr = '[Cannot access: likely cross-origin]';
                }
                
                var frameCookies = {};
                if (iframeCookieStr && !iframeCookieStr.includes('Cannot access')) {
                  iframeCookieStr.split('; ').forEach(function(cookie) {
                    var parts = cookie.split('=');
                    if (parts.length == 2) {
                      frameCookies[parts[0]] = parts[1];
                    }
                  });
                }
                
                iframeCookies[frameId] = {
                  src: frameSrc,
                  cookies: frameCookies,
                  raw: iframeCookieStr
                };
              } catch (frameError) {
                iframeCookies['iframe_' + i + '_error'] = {
                  error: frameError.toString()
                };
              }
            }
          } catch (error) {
            iframeCookies['error'] = error.toString();
          }
          
          return JSON.stringify({
            mainCookies: mainCookies,
            iframeCookies: iframeCookies,
            mainCookieString: document.cookie
          });
        })();
      ''');

      // Parse the result
      String jsonString = result.toString();
      if (jsonString.startsWith('"') && jsonString.endsWith('"')) {
        jsonString = jsonString
            .substring(1, jsonString.length - 1)
            .replaceAll(r'\"', '"')
            .replaceAll(r'\\', '\\');
      }

      final cookiesData = json.decode(jsonString) as Map<String, dynamic>;

      // Extract main cookies
      final mainCookies = cookiesData['mainCookies'] as Map<String, dynamic>;
      final mainCookieString = cookiesData['mainCookieString'] as String;

      // Convert main cookies to string map
      final Map<String, String> mainCookieMap = {};
      mainCookies.forEach((key, value) {
        mainCookieMap[key] = value.toString();
      });

      // Update state with all cookies
      setState(() {
        _allCookies = mainCookieMap;
      });

      // Print all cookies, but mark ignored ones
      debugPrint('===== MAIN DOCUMENT COOKIES =====');
      debugPrint('Raw cookie string: $mainCookieString');
      mainCookieMap.forEach((key, value) {
        final isIgnored = _ignoredCookies.contains(key);
        debugPrint('${isIgnored ? "[IGNORED] " : ""}$key: $value');
      });

      // Extract iframe cookies
      final iframeCookiesData =
          cookiesData['iframeCookies'] as Map<String, dynamic>;
      debugPrint('\n===== IFRAME COOKIES =====');
      iframeCookiesData.forEach((frameId, frameData) {
        debugPrint('\nFrame: $frameId');

        if (frameData is Map<String, dynamic>) {
          if (frameData.containsKey('src')) {
            debugPrint('Source: ${frameData['src']}');
          }

          if (frameData.containsKey('raw')) {
            debugPrint('Raw cookies: ${frameData['raw']}');
          }

          if (frameData.containsKey('cookies') && frameData['cookies'] is Map) {
            final frameCookies = frameData['cookies'] as Map<String, dynamic>;
            frameCookies.forEach((cookieName, cookieValue) {
              final isIgnored = _ignoredCookies.contains(cookieName);
              debugPrint(
                '  ${isIgnored ? "[IGNORED] " : ""}$cookieName: $cookieValue',
              );
            });
          }

          if (frameData.containsKey('error')) {
            debugPrint('Error: ${frameData['error']}');
          }
        }
      });
      debugPrint('==============================\n');

      // Look ONLY for bb_session cookie in main document
      String? bbSessionValue = mainCookieMap[_targetAuthCookie];

      // If not found in main document, check iframes
      if (bbSessionValue == null) {
        iframeLoop:
        for (final frameId in iframeCookiesData.keys) {
          final frameData = iframeCookiesData[frameId];
          if (frameData is Map<String, dynamic> &&
              frameData.containsKey('cookies') &&
              frameData['cookies'] is Map) {
            final frameCookies = frameData['cookies'] as Map<String, dynamic>;

            if (frameCookies.containsKey(_targetAuthCookie)) {
              bbSessionValue = frameCookies[_targetAuthCookie].toString();
              debugPrint('Found bb_session cookie in frame: $frameId');
              break iframeLoop;
            }
          }
        }
      }

      // If found the specific bb_session cookie
      if (bbSessionValue != null) {
        debugPrint('=== BB_SESSION COOKIE FOUND ===');
        debugPrint('bb_session=$bbSessionValue');
        debugPrint('===============================');

        _authenticated = true;
        _stopCookiePolling();

        // Filter out ignored cookies from the result
        final Map<String, String> filteredCookieMap = {};
        mainCookieMap.forEach((key, value) {
          if (!_ignoredCookies.contains(key)) {
            filteredCookieMap[key] = value;
          }
        });

        // Return to previous screen with auth cookie
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            context.pop({
              'authenticated': true,
              'cookieName': _targetAuthCookie,
              'cookieValue': bbSessionValue,
              'allCookies': mainCookieString,
              'cookieMap': filteredCookieMap,
            });
          });
        }
      } else {
        // Log the cookies we found, but keep polling since bb_session is missing
        if (mainCookieMap.isNotEmpty) {
          debugPrint(
            'Found some cookies, but no bb_session yet. Continuing to poll...',
          );
          if (_cookieCheckTimer == null) {
            _startCookiePolling();
          }
        } else {
          debugPrint('No cookies found. Continuing to poll...');
        }
      }
    } catch (e) {
      debugPrint('Error checking cookies: $e');
    }
  }

  Future<void> _loadUrlWithBasicAuth() async {
    try {
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
          ],
        ),
      ),
    );
  }

  void _showCookiesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Current Cookies'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Main Document Cookies:',
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: _checkAllCookies,
            child: const Text('Refresh'),
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
