import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'widgets/track_preview_sheet.dart';

class ShareIntentManager {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static StreamSubscription? _intentSub;
  static String? _lastHandledText;

  static void initialize() {
    if (Platform.isIOS) return;

    // Listen to incoming shares while app is alive
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (value) {
        if (value.isNotEmpty) {
          final file = value.first;
          if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
            handleSharedText(file.path);
          }
        }
      },
      onError: (err) {
        debugPrint('ShareIntentManager stream error: $err');
      },
    );

    // Get initial media if opened via share intent from background
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        final file = value.first;
        if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
          handleSharedText(file.path);
        }
      }
    });
  }

  static void handleSharedText(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return;

    // Avoid immediate duplicate trigger
    if (_lastHandledText == clean) return;
    _lastHandledText = clean;
    Timer(const Duration(seconds: 2), () => _lastHandledText = null);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        TrackPreviewSheet.show(context, input: clean);
      }
    });
  }

  static void dispose() {
    _intentSub?.cancel();
  }
}
