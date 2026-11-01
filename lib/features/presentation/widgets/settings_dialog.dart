import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:pulse_share/core/logging/app_logger.dart';
import 'package:pulse_share/core/models/platform_type.dart';
import 'package:pulse_share/features/resolver/data/cache_service.dart';
import 'package:pulse_share/features/settings/preferences_service.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const SettingsDialog(),
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _geminiController;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final prefs = context.read<PreferencesService>();
    _geminiController = TextEditingController(text: prefs.geminiApiKey ?? '');
  }

  @override
  void dispose() {
    _geminiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = context.watch<PreferencesService>();

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.tune_rounded),
          SizedBox(width: 10),
          Text('Settings'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preferred Platform Selection
            Text(
              'Preferred Music Service',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Used for 1-tap quick open',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<PlatformType>(
              initialValue: prefs.preferredPlatform,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              items: PlatformType.values.map((p) {
                return DropdownMenuItem(
                  value: p,
                  child: Row(
                    children: [
                      Icon(p.icon, color: p.brandColor, size: 20),
                      const SizedBox(width: 10),
                      Text(p.displayName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) prefs.setPreferredPlatform(val);
              },
            ),

            const SizedBox(height: 20),

            // Auto-Open Toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-Open Preferred App'),
              subtitle: const Text('Automatically open direct song links without showing dialog'),
              value: prefs.autoOpen,
              onChanged: (val) => prefs.setAutoOpen(val),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Gemini API Key Section
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 20, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Gemini AI Key (Optional)',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Enables smart recognition for noisy video titles & raw chat messages.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _geminiController,
              obscureText: _obscureKey,
              decoration: InputDecoration(
                hintText: 'Enter Google AI Studio Key',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                suffixIcon: IconButton(
                  icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
              ),
              onChanged: (val) => prefs.setGeminiApiKey(val),
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),

            // Clear Cache
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Clear Track Cache'),
              subtitle: const Text('Removes all locally saved song links'),
              onTap: () async {
                await CacheService.clearCache();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cache cleared!')),
                  );
                }
              },
            ),

            const SizedBox(height: 8),

            // Talker In-App Logs Viewer
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.terminal_rounded, color: Colors.teal),
              title: const Text('Talker Log Monitor'),
              subtitle: const Text('View real-time resolution logs & errors'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(context);
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
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
