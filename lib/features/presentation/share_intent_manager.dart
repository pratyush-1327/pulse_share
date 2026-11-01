import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:pulse_share/core/logging/app_logger.dart';
import 'widgets/track_preview_sheet.dart';

class ShareIntentManager {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static StreamSubscription? _intentSub;
  static String? _lastHandledText;

  static void initialize() {
    if (Platform.isIOS) {
      talker.debug('ShareIntentManager: iOS detected, intent listeners skipped');
      return;
    }

    talker.info('ShareIntentManager: Initializing Android share intent listener');

    // Listen to incoming shares while app is alive
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (value) {
        if (value.isNotEmpty) {
          final file = value.first;
          talker.info('ShareIntentManager: Received stream event with type ${file.type}');
          if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
            handleSharedText(file.path);
          }
        }
      },
      onError: (err, stack) {
        talker.handle(err, stack, 'ShareIntentManager stream error');
      },
    );

    // Get initial media if opened via share intent from background
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        final file = value.first;
        talker.info('ShareIntentManager: Received initial media intent with type ${file.type}');
        if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
          handleSharedText(file.path);
        }
      }
    }).catchError((err, stack) {
      talker.handle(err, stack, 'ShareIntentManager getInitialMedia error');
    });
  }

  static void handleSharedText(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return;

    // Avoid immediate duplicate trigger
    if (_lastHandledText == clean) {
      talker.debug('ShareIntentManager: Debouncing duplicate intent "$clean"');
      return;
    }
    _lastHandledText = clean;
    Timer(const Duration(seconds: 2), () => _lastHandledText = null);

    talker.info('📲 ShareIntentManager: Processing shared text "$clean"');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        talker.debug('ShareIntentManager: Displaying TrackPreviewSheet');
        TrackPreviewSheet.show(context, input: clean);
      } else {
        talker.warning('ShareIntentManager: navigatorKey context is null');
      }
    });
  }

  static void dispose() {
    _intentSub?.cancel();
    talker.debug('ShareIntentManager: Disposed stream subscription');
  }
}
