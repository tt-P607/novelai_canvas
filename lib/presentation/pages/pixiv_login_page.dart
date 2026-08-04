import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-app Pixiv login that captures the session Cookie and CSRF token after
/// the user signs in, so they never have to copy them from a browser manually.
///
/// Returns a [PixivLoginResult] via `Navigator.pop` on success, or `null` when
/// the user backs out without completing login.
class PixivLoginPage extends StatefulWidget {
  const PixivLoginPage({super.key});

  @override
  State<PixivLoginPage> createState() => _PixivLoginPageState();
}

class _PixivLoginPageState extends State<PixivLoginPage> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _captured = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0E0C15))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (url) async {
            if (mounted) setState(() => _loading = false);
            await _tryCapture(url);
          },
        ),
      )
      ..loadRequest(Uri.parse('https://accounts.pixiv.net/login'));
  }

  /// Detects a successful login (redirected to www.pixiv.net) and pulls the
  /// full Cookie string plus the CSRF token from the authenticated session.
  Future<void> _tryCapture(String url) async {
    if (_captured) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final host = uri.host;
    // Logged-in users land on www.pixiv.net; accounts.pixiv.net is the login
    // form itself.
    final loggedIn =
        host == 'www.pixiv.net' ||
        host == 'touch.pixiv.net' ||
        host == 'i.pximg.net';
    if (!loggedIn) return;

    final cookieManager = WebViewCookieManager();
    final cookies = await cookieManager.getCookies(
      domain: Uri.parse('https://www.pixiv.net'),
    );
    if (cookies.isEmpty) return;

    final cookieHeader = cookies.map((c) => '${c.name}=${c.value}').join('; ');
    // CSRF token is carried in the logged-in session. Reading it from the page
    // is unreliable, so fall back to the cookie set by the web app.
    var csrf = '';
    for (final c in cookies) {
      if (c.name.toLowerCase().contains('csrf')) {
        csrf = c.value;
        break;
      }
    }

    _captured = true;
    if (mounted) {
      Navigator.pop(
        context,
        PixivLoginResult(cookie: cookieHeader, csrfToken: csrf),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0C15),
      appBar: AppBar(
        title: const Text('Pixiv 登录'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0xFF0E0C15),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class PixivLoginResult {
  const PixivLoginResult({required this.cookie, required this.csrfToken});

  final String cookie;
  final String csrfToken;
}
