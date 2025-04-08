// ignore_for_file: unused_field, use_late_for_private_fields_and_variables, use_build_context_synchronously, unused_element

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:bb_mobile/features/exchange/domain/save_api_key_usecase.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// Provider wrapper for the BullBitcoinWebView
class BullBitcoinWebViewProvider extends StatelessWidget {
  const BullBitcoinWebViewProvider({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ExchangeCubit(
        saveApiKeyUsecase: locator<SaveApiKeyUsecase>(),
      ),
      child: const BullBitcoinWebView(),
    );
  }
}

class BullBitcoinWebView extends StatefulWidget {
  const BullBitcoinWebView({super.key});

  @override
  State<BullBitcoinWebView> createState() => _BullBitcoinWebViewState();
}

class _BullBitcoinWebViewState extends State<BullBitcoinWebView> {
  late final WebViewController _controller;
  Timer? _cookieCheckTimer;
  bool _webViewInitialized = false;

  final List<String> _ignoredCookies = [
    'i18n',
    'i18n-lng',
    'i18next',
    'django_language',
    'language',
    'locale',
    'hl',
  ];

  // Add these fields to track URLs that indicate login flow
  final String _baseAccountsUrl = 'https://accounts05.bullbitcoin.dev';
  final String _loginUrlPattern = 'login';
  final String _registrationUrlPattern = 'registration';
  final String _verificationUrlPattern = 'verification';
  String? _previousUrl;

  @override
  void initState() {
    super.initState();

    // Setup WebViewController
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!mounted) return;
            context.read<ExchangeCubit>().setLoading(true);
            context.read<ExchangeCubit>().setCurrentUrl(url);

            // Store previous URL for comparison
            _previousUrl = context.read<ExchangeCubit>().state.currentUrl;

            // Check if the URL change indicates successful login
            _checkForSuccessfulLogin(url);
          },
          onPageFinished: (url) {
            if (!mounted) return;
            context.read<ExchangeCubit>().setLoading(false);
            context.read<ExchangeCubit>().setCurrentUrl(url);

            // Reset cookie check attempts on new page load
            context.read<ExchangeCubit>().resetCookieCheckAttempts();

            // Add a small delay before checking cookies to ensure page is fully loaded
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _checkAllCookies();
                _startCookiePolling();
              }
            });
          },
          onUrlChange: (UrlChange change) {
            final currentUrl = change.url;
            if (currentUrl != null && mounted) {
              // Store previous URL for comparison
              _previousUrl = context.read<ExchangeCubit>().state.currentUrl;

              context.read<ExchangeCubit>().setCurrentUrl(currentUrl);
              _checkAllCookies();

              // Check if the URL change indicates successful login
              _checkForSuccessfulLogin(currentUrl);
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
            if (!mounted) return;
            context.read<ExchangeCubit>().setError(
                  message: '${error.errorType}: ${error.description}',
                );
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
        'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15.0 Safari/604.1',
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Initialize webview after the widget is fully built and provider is available
    if (!_webViewInitialized) {
      _webViewInitialized = true;
      _loadUrlWithBasicAuth();
      _cookieManager();
    }
  }

  Future<void> _cookieManager() async {
    if (!mounted) return;

    final cubit = context.read<ExchangeCubit>();

    try {
      final cookieManager = WebviewCookieManager();
      final gotCookies =
          await cookieManager.getCookies('https://${cubit.baseUrl}');

      // Debug logging for all cookies
      if (gotCookies.isNotEmpty) {
        debugPrint('Cookies found during initialization:');
        for (final cookie in gotCookies) {
          debugPrint('${cookie.name}: ${cookie.value}');

          // Check for session cookie
          if (cookie.name == cubit.targetAuthCookie) {
            debugPrint('BB_SESSION FOUND DURING INITIALIZATION!');
            // Update state with authentication and cookie
            if (!mounted) return;
            final updatedCookies =
                Map<String, String>.from(cubit.state.allCookies);
            updatedCookies[cubit.targetAuthCookie] = cookie.value;
            cubit.updateCookies(updatedCookies);
            cubit.setAuthenticated(true);
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
    if (!mounted) return;
    final cubit = context.read<ExchangeCubit>();
    if (_cookieCheckTimer != null) return; // Already polling

    _cookieCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) {
        _stopCookiePolling();
        return;
      }

      cubit.incrementCookieCheckAttempts();
      if (cubit.state.cookieCheckAttempts >
          cubit.state.maxCookieCheckAttempts) {
        debugPrint(
          'Reached maximum cookie polling attempts. Stopping polling.',
        );
        _stopCookiePolling();
        return;
      }
      _checkAllCookies();
    });

    debugPrint(
      'Started cookie polling (attempt ${cubit.state.cookieCheckAttempts})',
    );
  }

  void _stopCookiePolling() {
    _cookieCheckTimer?.cancel();
    _cookieCheckTimer = null;
  }

  Future<void> _checkAllCookies() async {
    if (!mounted) return;
    final cubit = context.read<ExchangeCubit>();
    if (cubit.state.authenticated) return; // Already authenticated

    // Only use native cookie detection since it's working
    await _checkNativeCookies();
  }

  Future<bool> _checkNativeCookies() async {
    if (!mounted) return false;
    final cubit = context.read<ExchangeCubit>();
    try {
      final cookieManager = WebviewCookieManager();
      final nativeCookies =
          await cookieManager.getCookies('https://${cubit.baseUrl}');

      debugPrint('Native cookie count: ${nativeCookies.length}');

      // Update all cookies map
      final Map<String, String> cookieMap = {};
      for (final cookie in nativeCookies) {
        cookieMap[cookie.name] = cookie.value;
      }

      if (!mounted) return false;
      cubit.updateCookies(cookieMap);

      // Find the session cookie
      for (final cookie in nativeCookies) {
        if (cookie.name == cubit.targetAuthCookie) {
          debugPrint('===== SESSION COOKIE FOUND =====');
          debugPrint('bb_session=${cookie.value}');
          debugPrint('================================');

          // Mark as authenticated but don't pop context
          if (!mounted) return false;
          cubit.setAuthenticated(true);
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

  // Rest of your methods with mounted checks...
  // ...

  Future<void> _generateApiKey() async {
    if (!mounted) return;
    final cubit = context.read<ExchangeCubit>();
    if (cubit.state.apiKeyGenerating) return;

    cubit.setApiKeyGenerating(true);

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

        cubit.setApiKeyResponse(jsonString);
        cubit.setApiKeyGenerating(false);

        // Log the response
        debugPrint('===== API KEY GENERATION RESPONSE =====');
        debugPrint(const JsonEncoder.withIndent('  ').convert(responseData));
        debugPrint('======================================');

        // Store the API key data
        await cubit.storeApiKey(responseData as Map<String, dynamic>);
      } catch (parseError) {
        debugPrint('Failed to parse API response: $parseError');
        debugPrint('Raw response: $jsonString');

        // Try to clean up the response if it's a string
        if (jsonString.contains('apiKey')) {
          cubit.setApiKeyResponse('{"apiKeyRawResponse": $jsonString}');
          cubit.setApiKeyGenerating(false);
        } else {
          throw Exception('Invalid JSON response: $jsonString');
        }
      }
    } catch (e) {
      debugPrint('Error generating API key: $e');

      // Try alternative approach if the first one fails
      await _tryAlternativeApiKeyGeneration();

      cubit.setApiKeyGenerating(false);
    }
  }

  Future<void> _tryAlternativeApiKeyGeneration() async {
    if (!mounted) return;
    final cubit = context.read<ExchangeCubit>();
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

      cubit.setApiKeyResponse(
        '{"info": "Alternative API request submitted. Check console logs for details."}',
      );

      debugPrint('Alternative API generation request completed');
    } catch (e) {
      debugPrint('Alternative API generation also failed: $e');
    }
  }

  Future<void> _loadUrlWithBasicAuth() async {
    if (!mounted) return;
    final cubit = context.read<ExchangeCubit>();
    try {
      // Add the query parameter to the URL
      final Uri url = Uri.parse('https://${cubit.baseUrl}');
      _controller.loadRequest(url);
    } catch (e) {
      debugPrint('Error loading URL with basic auth: $e');
      if (!mounted) return;
      cubit.setError(message: 'Failed to load the page: $e');
    }
  }

  // Add this method to check for successful login based on URL changes
  void _checkForSuccessfulLogin(String currentUrl) {
    if (!mounted) return;

    // Ignore if we don't have a previous URL yet
    if (_previousUrl == null) return;

    debugPrint('URL changed: $_previousUrl -> $currentUrl');

    // Check if we came from login, registration, or verification
    // and now we're at the main account page
    final wasOnAuthFlow = _previousUrl!.contains(_loginUrlPattern) ||
        _previousUrl!.contains(_registrationUrlPattern) ||
        _previousUrl!.contains(_verificationUrlPattern);

    final isOnMainPage = !currentUrl.contains(_loginUrlPattern) &&
        !currentUrl.contains(_registrationUrlPattern) &&
        !currentUrl.contains(_verificationUrlPattern);

    // If we navigated from login/registration/verification to the main page,
    // we've successfully logged in
    if (wasOnAuthFlow && isOnMainPage) {
      debugPrint(
        'Successful login detected: URL changed from auth flow to main page',
      );

      // Allow a brief moment to see the success page
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (!mounted) return;

        // Ensure we have cookies and API key if needed
        if (!context.read<ExchangeCubit>().state.authenticated) {
          await _checkAllCookies();
          await _generateApiKey();
        }

        // Show popup dialog instead of closing the webview
        _showLoginSuccessDialog();
      });
    }
  }

  // Add this helper method to identify the previous URL type
  String _getPreviousUrlType(String url) {
    if (url == _loginUrlPattern) return 'login';
    if (url == _registrationUrlPattern) return 'registration';
    if (url.startsWith(_verificationUrlPattern)) return 'verification';
    return 'unknown';
  }

  // Add this new method to show the success popup
  void _showLoginSuccessDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Successful'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text('You are now logged in to Bull Bitcoin!'),
            SizedBox(height: 8),
            Text('You can return to the wallet now.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExchangeCubit, ExchangeState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 0,
            flexibleSpace: const SizedBox.shrink(),
            forceMaterialTransparency: true,
          ),
          body: SafeArea(
            child: Stack(
              children: [
                if (state.hasError)
                  _ErrorView(
                    message: state.errorMessage,
                    onRetry: () => Navigator.of(context).pop(),
                  )
                else
                  WebViewWidget(controller: _controller),
                if (state.isLoading && !state.hasError)
                  const Center(child: CircularProgressIndicator()),

                // Show API key generation indicator
                if (state.apiKeyGenerating)
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
              ],
            ),
          ),
        );
      },
    );
  }

  // Rest of your code
  // ...
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
