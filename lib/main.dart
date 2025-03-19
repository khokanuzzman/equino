import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
String? pendingInitialUrl;
bool hasHandledInitialNotification = false;
String? overrideInitialUrl;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("c3f57ef1-be96-4d33-aaba-3c8b15e5ae0d");
  OneSignal.Notifications.requestPermission(true);

  OneSignal.Notifications.addClickListener((event) async {
    final data = event.notification.additionalData;
    final externalUrl = data?['url'];

    if (externalUrl != null) {
      final uri = Uri.tryParse(externalUrl);

      if (uri != null) {
        if (navigatorKey.currentContext != null) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => GameWebView(overrideUrl: externalUrl)),
          );
        } else {
          pendingInitialUrl = externalUrl;
        }
        hasHandledInitialNotification = true;
      }
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => SplashScreen(),
      },
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // CookieManager.instance().setCookie()
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    await Future.delayed(const Duration(seconds: 3));

    if (pendingInitialUrl != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => GameWebView(overrideUrl: pendingInitialUrl)),
      );
      pendingInitialUrl = null;
    } else {
      if (!hasHandledInitialNotification) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => GameWebView()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF76091A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/splash.png',
              width: 150,
              height: 150,
            ),
          ],
        ),
      ),
    );
  }
}

class GameWebView extends StatefulWidget {
  final String? overrideUrl;
  const GameWebView({super.key, this.overrideUrl});

  @override
  _GameWebViewState createState() => _GameWebViewState();
}

class _GameWebViewState extends State<GameWebView> {
  late Future<String> gameUrlFuture;
  InAppWebViewController? _webViewController;
  late PullToRefreshController pullToRefreshController;
  late String initialUrl;
  String? lastGameUrl;

  @override
  void initState() {
    super.initState();

    if (widget.overrideUrl != null) {
      initialUrl = widget.overrideUrl!;
    }

    pullToRefreshController = PullToRefreshController(
      onRefresh: () async {
        if (Platform.isAndroid) {
          _webViewController?.reload();
        } else if (Platform.isIOS) {
          Uri? url = await _webViewController?.getUrl();
          if (url != null) {
            _webViewController?.loadUrl(
              urlRequest: URLRequest(url: WebUri(url.toString())),
            );
          }
        }
      },
    );

    gameUrlFuture = _loadConfig();
  }

  Future<String> _loadConfig() async {
    String configJson = await rootBundle.loadString('assets/config.json');
    Map<String, dynamic> config = json.decode(configJson);
    lastGameUrl = config['game_url'];
    return widget.overrideUrl ?? config['game_url'];
  }

  Future<void> _pullToRefresh() async {
    await _webViewController?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_webViewController != null) {
          bool canGoBack = await _webViewController!.canGoBack();
          if (canGoBack) {
            _webViewController!.goBack();
            return false; // Prevent app from closing
          }
        }
        return true; // Allow app to close
      },
      child: Scaffold(
        backgroundColor: Color(0xFF76091A),
        body: SafeArea(
          child: FutureBuilder<String>(
            future: gameUrlFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error loading URL: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Game URL is empty'));
              } else {
                String gameUrl = snapshot.data!;
                return RefreshIndicator(
                  onRefresh: _pullToRefresh,
                  child: InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(gameUrl)),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      useHybridComposition: true,
                      sharedCookiesEnabled: true,
                      incognito: false,
                      useShouldOverrideUrlLoading: true,
                      thirdPartyCookiesEnabled: true,
                      domStorageEnabled: true,
                      cacheEnabled: true,
                      clearCache: false,
                      clearSessionCache: false,
                    ),
                    pullToRefreshController: pullToRefreshController,
                    onWebViewCreated: (controller) {
                      _webViewController = controller;
                    },
                    onLoadStop: (controller, url) {
                      pullToRefreshController.endRefreshing();
                    },
                    onLoadError: (controller, url, code, message) {
                      pullToRefreshController.endRefreshing();
                    },
                    shouldOverrideUrlLoading: (controller, navigationAction) async {
                      return NavigationActionPolicy.ALLOW;
                    },
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
