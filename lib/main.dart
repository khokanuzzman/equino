import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Debug logging (optional)
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

  // Initialize OneSignal with your App ID
  OneSignal.initialize("c3f57ef1-be96-4d33-aaba-3c8b15e5ae0d");

  // Prompt for notification permission (especially for iOS)
  OneSignal.Notifications.requestPermission(true);

  // Handle notification tap
  OneSignal.Notifications.addClickListener((event) {
    final data = event.notification.additionalData;
    final targetScreen = data?['target']; // Custom field sent from OneSignal

    if (targetScreen != null && navigatorKey.currentContext != null) {
      Navigator.pushNamed(navigatorKey.currentContext!, '/$targetScreen');
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // <-- Add this
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      home: SplashScreen(), // Show splash screen first
      routes: {
        '/splash': (_) => SplashScreen(),
      },
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
    _navigateToHome();
  }

  // Navigate to the main screen after the splash screen is displayed for 3 seconds
  Future<void> _navigateToHome() async {
    await Future.delayed(Duration(seconds: 3)); // Adjust the delay as needed
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GameWebView(),
      ), // Main screen after splash
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF76091A), // Rood color
              Color(0xFF76091A), // Geel color
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/splash.png', // Replace with your logo image
                width: 150, // Adjust width as needed
                height: 150, // Adjust height as needed
              ),
            ],
          ),
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

  @override
  void initState() {
    super.initState();

    if (widget.overrideUrl != null) {
      gameUrlFuture = Future.value(widget.overrideUrl!);
    } else {
      gameUrlFuture = _loadConfig(); // Load default game URL
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
  }

  Future<String> _loadConfig() async {
    String configJson = await rootBundle.loadString('assets/config.json');
    Map<String, dynamic> config = json.decode(configJson);
    return config['game_url'];
  }

  Future<void> _pullToRefresh() async {
    await _webViewController?.reload(); // Reload the WebView
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF76091A),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: gameUrlFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Text('Error loading URL: ${snapshot.error}'),
              );
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
                    useOnDownloadStart: true,
                    useShouldOverrideUrlLoading: true,
                    supportZoom: true,
                    disableHorizontalScroll: false,
                    disableVerticalScroll: false,
                  ),
                  pullToRefreshController: pullToRefreshController,
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                  },
                  onLoadStart: (controller, url) {
                    debugPrint("Loading URL: $url");
                  },
                  onLoadStop: (controller, url) async {
                    pullToRefreshController.endRefreshing();
                    debugPrint("Page loaded: $url");
                  },
                  onLoadError: (controller, url, code, message) {
                    pullToRefreshController.endRefreshing();
                    debugPrint("Failed to load URL: $url, Error: $message");
                  },
                  shouldOverrideUrlLoading: (
                    controller,
                    navigationAction,
                  ) async {
                    var url = navigationAction.request.url.toString();
                    if (url.contains("external")) {
                      // Handle external link
                    }
                    return NavigationActionPolicy.ALLOW;
                  },
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
