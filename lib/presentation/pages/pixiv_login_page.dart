import 'dart:async';
import 'dart:convert';

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
  Timer? _retryTimer;
  int _retryCount = 0;

  /// Latest cookie/token captured while browsing; kept even when the session
  /// is not fully confirmed so the user can finish manually.
  String? _capturedCookie;
  String? _capturedCsrf;

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

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

  /// Attempts to capture the session Cookie + CSRF token once the user reaches
  /// a Pixiv domain. Unlike the previous logic, it does not block on a single
  /// `sessionid` cookie name or on a specific upload-page path — landing on
  /// www.pixiv.net is enough, and it captures even when the token is empty so
  /// the user can fill it in from the settings page afterwards.
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

    // Merge cookies from the domains Pixiv uses so the session cookie is not
    // missed if it lives under a parent domain.
    final cookies = <WebViewCookie>[];
    for (final domain in const [
      'https://www.pixiv.net',
      'https://accounts.pixiv.net',
      'https://touch.pixiv.net',
    ]) {
      final manager = WebViewCookieManager();
      try {
        final batch = await manager.getCookies(domain: Uri.parse(domain));
        for (final c in batch) {
          final exists = cookies.any(
            (e) => e.name == c.name && e.value == c.value,
          );
          if (!exists) cookies.add(c);
        }
      } catch (_) {
        // A domain read failure must not abort the whole capture.
      }
    }

    // A Pixiv login session is present once we land on www.pixiv.net with any
    // cookies. Requiring the HttpOnly "sessionid" specifically was too brittle
    // on Android — the cookie manager may miss it while the user is clearly
    // logged in (they reached the upload page). Retry a bounded number of
    // times for cookies that arrive a beat after onPageFinished, then give the
    // user control via the app-bar "完成" button / back.
    final hasSession = cookies.isNotEmpty;
    if (!hasSession) {
      if (_retryCount < 5) {
        _retryCount++;
        _retryTimer?.cancel();
        _retryTimer = Timer(const Duration(seconds: 2), () async {
          if (!mounted || _captured) return;
          final current = await _controller.currentUrl();
          if (current != null) await _handlePageFinished(current);
        });
      }
      return;
    }
    _retryTimer?.cancel();
    _retryTimer = null;

    final cookieHeader = cookies.map((c) => '${c.name}=${c.value}').join('; ');
    // Pixiv stores the x-csrf-token in the page DOM (meta tag) or in
    // localStorage["pixiv.akana.cookie"] JSON, not in a cookie, so query the
    // page directly first; fall back to scanning cookies as a safety net.
    final csrf = await _extractCsrfToken();

    _finish(cookieHeader, csrf);
  }

  /// Pops with the captured credentials, or null if none were captured.
  void _finish(String cookie, String csrf) {
    _retryTimer?.cancel();
    _retryTimer = null;
    _capturedCookie = cookie;
    _capturedCsrf = csrf;
    if (_captured) return;
    _captured = true;
    if (mounted) {
      Navigator.pop(context, PixivLoginResult(cookie: cookie, csrfToken: csrf));
    }
  }

  /// Manual finish: pops with whatever was captured (may be null when the user
  /// never reached a logged-in Pixiv page).
  void _finishManual() {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (_captured) return;
    _captured = true;
    if (mounted) {
      Navigator.pop(
        context,
        _capturedCookie == null
            ? null
            : PixivLoginResult(
                cookie: _capturedCookie!,
                csrfToken: _capturedCsrf ?? '',
              ),
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
      // Android JSON-encodes the JS return value (a string arrives quoted,
      // e.g. "abc" or ""), while iOS returns it verbatim. Decode quoted values
      // so the token is clean on both platforms.
      String? token;
      if (result is String) {
        final raw = result.trim();
        if (raw.isEmpty || raw == 'null') {
          token = '';
        } else if (raw.length >= 2 &&
            ((raw.startsWith('"') && raw.endsWith('"')) ||
                (raw.startsWith("'") && raw.endsWith("'")))) {
          token = jsonDecode(raw) as String;
        } else {
          token = raw;
        }
      }
      if (token != null && token.isNotEmpty) return token;
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finishManual();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0E0C15),
        appBar: AppBar(
          title: const Text('Pixiv 登录'),
          actions: [
            TextButton(
              onPressed: _captured ? null : _finishManual,
              child: const Text('完成登录'),
            ),
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
      ),
    );
  }
}

class PixivLoginResult {
  const PixivLoginResult({required this.cookie, required this.csrfToken});

  final String cookie;
  final String csrfToken;
}
