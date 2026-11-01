import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pulse_share/core/logging/app_logger.dart';
import 'package:pulse_share/core/models/platform_type.dart';
import 'package:pulse_share/core/models/track_info.dart';
import 'package:pulse_share/features/resolver/data/resolver_orchestrator.dart';
import 'package:pulse_share/features/settings/preferences_service.dart';

class TrackPreviewSheet extends StatefulWidget {
  final String? input;
  final TrackInfo? initialTrack;

  const TrackPreviewSheet({
    super.key,
    this.input,
    this.initialTrack,
  });

  static Future<void> show(
    BuildContext context, {
    String? input,
    TrackInfo? track,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TrackPreviewSheet(
        input: input,
        initialTrack: track,
      ),
    );
  }

  @override
  State<TrackPreviewSheet> createState() => _TrackPreviewSheetState();
}

class _TrackPreviewSheetState extends State<TrackPreviewSheet> {
  TrackInfo? _track;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialTrack != null) {
      _track = widget.initialTrack;
    } else if (widget.input != null) {
      _resolveInput(widget.input!);
    }
  }

  Future<void> _resolveInput(String input) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = context.read<PreferencesService>();
      final result = await ResolverOrchestrator.resolve(
        rawInput: input,
        customGeminiKey: prefs.geminiApiKey,
      );

      if (!mounted) return;
      setState(() {
        _track = result;
        _isLoading = false;
      });

      // Auto-open if enabled
      if (prefs.autoOpen) {
        final preferredLink = result.linkFor(prefs.preferredPlatform);
        if (preferredLink != null && preferredLink.isDirect) {
          talker.info('TrackPreviewSheet: Auto-opening preferred app (${prefs.preferredPlatform.displayName})');
          _launchUrl(preferredLink.url);
        }
      }
    } catch (e, stack) {
      talker.handle(e, stack, 'TrackPreviewSheet resolution error');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not resolve link: $e';
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    talker.info('TrackPreviewSheet: Launching URL: $url');
    final uri = Uri.parse(url);
    try {
      final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!success && mounted) {
        talker.warning('TrackPreviewSheet: launchUrl returned false for $url');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the platform link')),
        );
      }
    } catch (e, stack) {
      talker.handle(e, stack, 'TrackPreviewSheet failed to launch URL: $url');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to launch: $e')),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    talker.debug('TrackPreviewSheet: Copied $label link to clipboard ($text)');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label link copied to clipboard!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareAll(TrackInfo track) {
    talker.info('TrackPreviewSheet: Sharing all platform links for "${track.displayTitle}"');
    final buffer = StringBuffer();
    buffer.writeln('🎵 Listen to "${track.title}" by ${track.artist}:');
    buffer.writeln();

    for (final entry in track.platformLinks.entries) {
      buffer.writeln('• ${entry.key.displayName}: ${entry.value.url}');
    }

    SharePlus.instance.share(
      ShareParams(
        text: buffer.toString(),
        subject: '${track.title} - ${track.artist}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = context.watch<PreferencesService>();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(70),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoading) _buildLoadingState(theme),
          if (_errorMessage != null) _buildErrorState(theme),
          if (_track != null) _buildTrackContent(theme, _track!, prefs),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Finding music links...',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Matching across Spotify, Apple Music & YouTube',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text('Failed to resolve', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackContent(ThemeData theme, TrackInfo track, PreferencesService prefs) {
    final preferredLink = track.linkFor(prefs.preferredPlatform);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header with Artwork & Song Info
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Artwork
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: track.artworkUrl != null
                  ? Image.network(
                      track.artworkUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildArtworkPlaceholder(theme),
                    )
                  : _buildArtworkPlaceholder(theme),
            ),
            const SizedBox(width: 16),

            // Title, Artist, Album
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (track.album != null && track.album!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      track.album!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),
        const Divider(height: 1),
        const SizedBox(height: 14),

        // Section Title
        Text(
          'Available On',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),

        // Platform Tiles
        ...track.platformLinks.entries.map((entry) {
          final platform = entry.key;
          final link = entry.value;
          final isPreferred = platform == prefs.preferredPlatform;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: isPreferred
                  ? platform.brandColor.withAlpha(25)
                  : theme.colorScheme.surfaceContainerHighest.withAlpha(80),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _launchUrl(link.url),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      // Platform Icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: platform.brandColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(platform.icon, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 14),

                      // Platform Name & Badge
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  platform.displayName,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (isPreferred) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Preferred',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              link.isDirect ? 'Direct Track' : 'Search Link',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: link.isDirect
                                    ? Colors.green.shade700
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: link.isDirect ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Copy Link Button
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        tooltip: 'Copy ${platform.displayName} link',
                        onPressed: () => _copyToClipboard(link.url, platform.displayName),
                      ),

                      // Open Icon
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 12),

        // Primary Action: Open Preferred Platform
        if (preferredLink != null)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: prefs.preferredPlatform.brandColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: Icon(prefs.preferredPlatform.icon),
            label: Text(
              'Open in ${prefs.preferredPlatform.displayName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            onPressed: () => _launchUrl(preferredLink.url),
          ),

        const SizedBox(height: 8),

        // Secondary Action: Share All Links
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.share_rounded),
          label: const Text('Share All Platform Links', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => _shareAll(track),
        ),
      ],
    );
  }

  Widget _buildArtworkPlaceholder(ThemeData theme) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
      ),
      child: Icon(
        Icons.music_note_rounded,
        size: 40,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }
}
