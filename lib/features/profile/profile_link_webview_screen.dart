import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/utils/theme_helper.dart';

final profileLinkWebViewProgressProvider =
    StateProvider.autoDispose<int>((ref) => 0);
final profileLinkWebViewCanGoBackProvider =
    StateProvider.autoDispose<bool>((ref) => false);

/// In-app browser for profile bio links, styled with the app theme.
class ProfileLinkWebViewScreen extends ConsumerStatefulWidget {
  final String url;
  final String? title;

  const ProfileLinkWebViewScreen({
    super.key,
    required this.url,
    this.title,
  });

  @override
  ConsumerState<ProfileLinkWebViewScreen> createState() =>
      _ProfileLinkWebViewScreenState();
}

class _ProfileLinkWebViewScreenState
    extends ConsumerState<ProfileLinkWebViewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            ref.read(profileLinkWebViewProgressProvider.notifier).state =
                progress;
          },
          onPageFinished: (_) => _syncNavState(),
          onNavigationRequest: (_) => NavigationDecision.navigate,
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _syncNavState() async {
    if (!mounted) return;
    final back = await _controller.canGoBack();
    if (!mounted) return;
    ref.read(profileLinkWebViewCanGoBackProvider.notifier).state = back;
  }

  @override
  Widget build(BuildContext context) {
    final accent = ThemeHelper.getAccentColor(context);
    final surface = ThemeHelper.getSurfaceColor(context);
    final loadingProgress = ref.watch(profileLinkWebViewProgressProvider);
    final canGoBack = ref.watch(profileLinkWebViewCanGoBackProvider);

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: ThemeHelper.getTextPrimary(context),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title ?? 'Link',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: ThemeHelper.getTextPrimary(context),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (canGoBack)
            IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: ThemeHelper.getTextPrimary(context),
              ),
              onPressed: () async {
                await _controller.goBack();
                await _syncNavState();
              },
            ),
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: ThemeHelper.getTextPrimary(context),
            ),
            onPressed: () => _controller.reload(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: loadingProgress < 100
              ? LinearProgressIndicator(
                  minHeight: 3,
                  value: loadingProgress / 100,
                  color: accent,
                  backgroundColor:
                      ThemeHelper.getBorderColor(context).withValues(alpha: 0.35),
                )
              : const SizedBox(height: 3),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
