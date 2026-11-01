import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:pulse_share/core/logging/app_logger.dart';
import 'package:pulse_share/core/models/track_info.dart';
import 'package:pulse_share/features/resolver/data/cache_service.dart';
import '../widgets/track_preview_sheet.dart';
import '../widgets/settings_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _inputController = TextEditingController();
  List<TrackInfo> _recentTracks = [];
  bool _isLoadingRecents = true;

  @override
  void initState() {
    super.initState();
    _loadRecents();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _loadRecents() async {
    final recents = await CacheService.getRecentTracks();
    if (mounted) {
      setState(() {
        _recentTracks = recents;
        _isLoadingRecents = false;
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _inputController.text = data.text!;
      _processInput(data.text!);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard is empty')),
        );
      }
    }
  }

  void _processInput(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return;

    talker.info('HomeScreen: User initiated conversion for "$clean"');

    TrackPreviewSheet.show(context, input: clean).then((_) {
      _loadRecents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.graphic_eq_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Text('PulseShare', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.terminal_rounded),
            tooltip: 'Debug Logs',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TalkerScreen(
                    talker: talker,
                    theme: TalkerScreenTheme(
                      backgroundColor: theme.colorScheme.surface,
                      textColor: theme.colorScheme.onSurface,
                      cardColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => SettingsDialog.show(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRecents,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Quick Paste & Convert Card
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Universal Music Bridge',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Paste any music link or song title to get direct links for Spotify, Apple Music & YouTube.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Input Field
                    TextField(
                      controller: _inputController,
                      decoration: InputDecoration(
                        hintText: 'Paste link or search song...',
                        prefixIcon: const Icon(Icons.link_rounded),
                        suffixIcon: _inputController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () => setState(() => _inputController.clear()),
                              )
                            : null,
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: _processInput,
                    ),
                    const SizedBox(height: 14),

                    // Action buttons row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.content_paste_rounded, size: 18),
                            label: const Text('Paste'),
                            onPressed: _pasteFromClipboard,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.search_rounded, size: 18),
                            label: const Text('Convert'),
                            onPressed: () => _processInput(_inputController.text),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Recents Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Conversions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_recentTracks.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      await CacheService.clearCache();
                      _loadRecents();
                    },
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Recents List or Empty Placeholder
            if (_isLoadingRecents)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_recentTracks.isEmpty)
              _buildEmptyState(theme)
            else
              ..._recentTracks.map((track) => _buildRecentTrackTile(theme, track)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.share_outlined,
            size: 40,
            color: theme.colorScheme.primary.withAlpha(180),
          ),
          const SizedBox(height: 12),
          Text(
            'No conversions yet',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Share a song link from Spotify, Apple Music, or YouTube to PulseShare, or paste a link above!',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTrackTile(ThemeData theme, TrackInfo track) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            TrackPreviewSheet.show(context, track: track).then((_) => _loadRecents());
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: track.artworkUrl != null
                      ? Image.network(
                          track.artworkUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildThumbPlaceholder(theme),
                        )
                      : _buildThumbPlaceholder(theme),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbPlaceholder(ThemeData theme) {
    return Container(
      width: 48,
      height: 48,
      color: theme.colorScheme.primaryContainer,
      child: Icon(
        Icons.music_note_rounded,
        size: 24,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }
}
