import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();  // Ensure the Flutter engine is initialized
  // Request permissions (camera, microphone, storage)
  await Permission.camera.request();
  await Permission.microphone.request();
  await Permission.storage.request();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: GameWebView(),
    );
  }
}

class GameWebView extends StatefulWidget {
  @override
  _GameWebViewState createState() => _GameWebViewState();
}

class _GameWebViewState extends State<GameWebView> {
  late InAppWebViewController _webViewController;
  late String gameUrl;

  @override
  void initState() {
    super.initState();
    _loadConfig(); // Load game URL from config
  }

  // Load game URL from config.json
  Future<void> _loadConfig() async {
    String configJson = await rootBundle.loadString('assets/config.json');
    Map<String, dynamic> config = json.decode(configJson);
    setState(() {
      gameUrl = config['game_url'];
    });
  }

  Future<void> _pullToRefresh() async {
    _webViewController.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Game WebView'),
      ),
      body: gameUrl.isEmpty
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _pullToRefresh,
        child: InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri(gameUrl), // Corrected to WebUri instead of Uri
          ),
          initialOptions: InAppWebViewGroupOptions(
            crossPlatform: InAppWebViewOptions(
              javaScriptEnabled: true,
              useOnDownloadStart: true,
              useShouldOverrideUrlLoading: true,
              // cookiesEnabled is no longer needed here
            ),
          ),
          onWebViewCreated: (InAppWebViewController controller) {
            _webViewController = controller;
          },
          onLoadStart: (controller, url) {
            print("Loading URL: $url");
          },
          onLoadStop: (controller, url) async {
            print("Page loaded: $url");
          },
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            var url = navigationAction.request.url.toString();
            if (url.contains("external")) {
              // Open external links in the default browser
              // You might need to import the `url_launcher` package here
              // await launch(url);
            } else {
              return NavigationActionPolicy.ALLOW;
            }
          },
        ),
      ),
    );
  }
}
