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

  // Add variables to track API key generation
  bool _apiKeyGenerating = false;
  String? _apiKeyResponse;

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

          // Generate API key when cookie is found
          _generateApiKey();

          return true;
        }
      }
    } catch (e) {
      debugPrint('Error checking native cookies: $e');
    }
    return false;
  }

  // Generate API key with improved error handling for iOS
  Future<void> _generateApiKey() async {
    if (_apiKeyGenerating) return;

    setState(() {
      _apiKeyGenerating = true;
    });

    debugPrint('Attempting to generate API key...');

    try {
      // First, try a simpler approach
      await _controller.runJavaScript('''
        console.log('Preparing to generate API key...');
      ''');

      // Add a small delay to ensure JavaScript context is ready
      await Future.delayed(const Duration(milliseconds: 500));

      // Use a simpler JavaScript approach that's more compatible with iOS
      final result = await _controller.runJavaScriptReturningResult('''
        (function() {
          var xhr = new XMLHttpRequest();
          xhr.open('POST', 'https://accounts05.bullbitcoin.dev/api/generate-api-key', false); // Synchronous request
          xhr.setRequestHeader('Content-Type', 'application/json');
          xhr.withCredentials = true; // Include cookies
          
          try {
            xhr.send(JSON.stringify({
              apiKeyName: 'test-key-' + new Date().getTime()
            }));
            
            console.log('API Response Status:', xhr.status);
            if (xhr.status >= 200 && xhr.status < 300) {
              try {
                return xhr.responseText;
              } catch (e) {
                return JSON.stringify({error: 'Failed to parse response: ' + e.toString()});
              }
            } else {
              return JSON.stringify({
                error: 'Request failed with status: ' + xhr.status,
                statusText: xhr.statusText || 'Unknown error'
              });
            }
          } catch (e) {
            return JSON.stringify({error: 'XHR Error: ' + e.toString()});
          }
        })();
      ''');

      // Process the result
      String jsonString = result.toString();

      // Clean up the JSON string if needed
      if (jsonString.startsWith('"') && jsonString.endsWith('"')) {
        jsonString = jsonString
            .substring(1, jsonString.length - 1)
            .replaceAll(r'\"', '"')
            .replaceAll(r'\\', '\\');
      }

      try {
        final responseData = json.decode(jsonString);

        setState(() {
          _apiKeyResponse = jsonString;
          _apiKeyGenerating = false;
        });

        // Log the response
        debugPrint('===== API KEY GENERATION RESPONSE =====');
        debugPrint(const JsonEncoder.withIndent('  ').convert(responseData));
        debugPrint('======================================');
      } catch (parseError) {
        debugPrint('Failed to parse API response: $parseError');
        debugPrint('Raw response: $jsonString');

        // Try to clean up the response if it's a string
        if (jsonString.contains('apiKey')) {
          setState(() {
            _apiKeyResponse = '{"apiKeyRawResponse": $jsonString}';
            _apiKeyGenerating = false;
          });
        } else {
          throw Exception('Invalid JSON response: $jsonString');
        }
      }
    } catch (e) {
      debugPrint('Error generating API key: $e');

      // Try alternative approach if the first one fails
      await _tryAlternativeApiKeyGeneration();

      setState(() {
        _apiKeyGenerating = false;
      });
    }
  }

  // Alternative API key generation approach for iOS
  Future<void> _tryAlternativeApiKeyGeneration() async {
    debugPrint('Trying alternative API key generation method...');

    try {
      // Inject a form submission approach which might be more compatible
      await _controller.runJavaScript('''
        (function() {
          // Create an invisible iframe to handle the response
          var iframe = document.createElement('iframe');
          iframe.style.display = 'none';
          document.body.appendChild(iframe);
          
          // Create a form for API key generation
          var form = document.createElement('form');
          form.method = 'POST';
          form.action = 'https://accounts05.bullbitcoin.dev/api/generate-api-key';
          form.target = iframe.name;
          
          // Add the API key name as a hidden field
          var input = document.createElement('input');
          input.type = 'hidden';
          input.name = 'apiKeyName';
          input.value = 'test-key-' + Date.now();
          form.appendChild(input);
          
          // Add form to document and submit
          document.body.appendChild(form);
          setTimeout(function() {
            form.submit();
            console.log('Alternative API request submitted');
            
            // Clean up
            setTimeout(function() {
              document.body.removeChild(form);
              document.body.removeChild(iframe);
            }, 5000);
          }, 100);
        })();
      ''');

      // Wait a bit and then set a placeholder response
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _apiKeyResponse =
            '{"info": "Alternative API request submitted. Check console logs for details."}';
      });

      debugPrint('Alternative API generation request completed');
    } catch (e) {
      debugPrint('Alternative API generation also failed: $e');
    }
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

            // Show API key generation indicator
            if (_apiKeyGenerating)
              ColoredBox(
                // ignore: deprecated_member_use
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Generating API key...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),

            // Add debug button in non-production builds
            if (!const bool.fromEnvironment('dart.vm.product'))
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton.small(
                  heroTag: 'debugBtn',
                  // ignore: deprecated_member_use
                  backgroundColor: Colors.black.withOpacity(0.7),
                  onPressed: () => _showDebugDialog(context),
                  child: const Icon(Icons.bug_report, color: Colors.white),
                ),
              ),
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

  void _showDebugDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('URL: $_currentUrl'),
              Text('Authenticated: $_authenticated'),
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

              // Show API key response if available
              if (_apiKeyResponse != null) ...[
                const Divider(),
                const Text(
                  'API Key Response:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_apiKeyResponse!),
                ),
              ],

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _checkNativeCookies,
                      child: const Text('Check Cookies'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _generateApiKey,
                      child: const Text('Generate API Key'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).pop(
                      {
                        'authenticated': _authenticated,
                        'cookieName': _targetAuthCookie,
                        'cookieValue': _allCookies[_targetAuthCookie],
                        'allCookies': _allCookies,
                        'apiKeyResponse': _apiKeyResponse != null
                            ? json.decode(_apiKeyResponse!)
                            : null,
                        'timestamp': DateTime.now().millisecondsSinceEpoch,
                      },
                    );
                  },
                  child: const Text('Return with Data'),
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
