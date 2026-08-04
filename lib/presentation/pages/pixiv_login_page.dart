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
  bool _redirectedToCreate = false;

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
            await _handlePageFinished(url);
          },
        ),
      )
      ..loadRequest(Uri.parse('https://accounts.pixiv.net/login'));
  }

  /// Handles a finished page load. On a logged-in Pixiv domain it redirects to
  /// the illustration upload page (where the CSRF token is guaranteed to exist)
  /// once, then captures the Cookie + token. This delays the capture until the
  /// upload page has loaded so the token is actually present.
  Future<void> _handlePageFinished(String url) async {
    if (_captured) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final host = uri.host;

    // Login form host: keep waiting until auth redirects to a Pixiv domain.
    if (host == 'accounts.pixiv.net') return;

    // Logged-in hosts (www.pixiv.net / touch.pixiv.net / i.pximg.net).
    final loggedIn =
        host == 'www.pixiv.net' ||
        host == 'touch.pixiv.net' ||
        host == 'i.pximg.net';
    if (!loggedIn) return;

    // First landing after login is usually the home page, which may not carry
    // the token; hop to the upload page once so meta/localStorage has it.
    final path = uri.path;
    if (path != '/illustration/create' && !_redirectedToCreate) {
      _redirectedToCreate = true;
      await _controller.loadRequest(
        Uri.parse('https://www.pixiv.net/illustration/create'),
      );
      return;
    }

    final cookieManager = WebViewCookieManager();
    final cookies = await cookieManager.getCookies(
      domain: Uri.parse('https://www.pixiv.net'),
    );
    if (cookies.isEmpty) return;

    final cookieHeader = cookies.map((c) => '${c.name}=${c.value}').join('; ');
    // Pixiv stores the x-csrf-token in the page DOM (meta tag) or in
    // localStorage["pixiv.akana.cookie"] JSON, not in a cookie, so query the
    // page directly first; fall back to scanning cookies as a safety net.
    final csrf = await _extractCsrfToken();

    _captured = true;
    if (mounted) {
      Navigator.pop(
        context,
        PixivLoginResult(cookie: cookieHeader, csrfToken: csrf),
      );
    }
  }

  /// Pulls the CSRF token from the logged-in page. Pixiv keeps it in a
  /// `<meta name="csrf-token">` element or in `localStorage.pixiv.akana.cookie`
  /// (a JSON blob with an `xsrf_token` field). Cookie scanning is the last
  /// resort because the token is normally not exposed as a cookie.
  Future<String> _extractCsrfToken() async {
    try {
      final js =
          r'''
        (() => {
          const meta = document.querySelector('meta[name="csrf-token"]');
          if (meta && meta.content) return meta.content;
          try {
            const blob = JSON.parse(
              localStorage.getItem('pixiv.akana.cookie') || '{}'
            );
            if (blob && blob.xsrf_token) return blob.xsrf_token;
          } catch (e) {}
          const cookie = document.cookie;
          const m = cookie.match(/(?:^|; )([^=;]*csrf[^=;]*)=([^;]+)/i);
          if (m && m[2]) return m[2];
          return '';
        })()
      '''
              .trim();
      final result = await _controller.runJavaScriptReturningResult(js);
      final token = result.toString().trim();
      if (token.isNotEmpty && token != 'null') return token;
    } catch (_) {
      // WebView scripting unavailable (e.g. restricted platform); fall through.
    }

    // Last resort: scan the cookie list for anything CSRF-ish.
    try {
      final cookieManager = WebViewCookieManager();
      final cookies = await cookieManager.getCookies(
        domain: Uri.parse('https://www.pixiv.net'),
      );
      for (final c in cookies) {
        if (c.name.toLowerCase().contains('csrf')) return c.value;
      }
    } catch (_) {}
    return '';
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
