import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/app_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Remix.arrow_left_s_line),
          onPressed: () => context.pop(),
        ),
        title: const Text('Réglages'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle(context, 'Apparence'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Remix.palette_line, color: context.colors.foreground50),
              title: Text('Thème', style: TextStyle(color: context.colors.foreground50)),
              trailing: DropdownButton<ThemeMode>(
                value: themeMode,
                underline: const SizedBox(),
                dropdownColor: context.colors.background900,
                iconEnabledColor: context.colors.foreground50,
                items: [
                  DropdownMenuItem(value: ThemeMode.system, child: Text('Système', style: TextStyle(color: context.colors.foreground50))),
                  DropdownMenuItem(value: ThemeMode.light, child: Text('Clair', style: TextStyle(color: context.colors.foreground50))),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Sombre', style: TextStyle(color: context.colors.foreground50))),
                ],
                onChanged: (mode) {
                  if (mode != null) {
                    ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle(context, 'Données'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Remix.upload_cloud_2_line, color: context.colors.foreground50),
                  title: Text('Sauvegarder les données', style: TextStyle(color: context.colors.foreground50)),
                  onTap: () {},
                ),
                Divider(color: context.colors.background700, height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Remix.download_cloud_2_line, color: context.colors.foreground50),
                  title: Text('Restaurer une sauvegarde', style: TextStyle(color: context.colors.foreground50)),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle(context, 'À propos'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Remix.information_line, color: context.colors.foreground50),
                  title: Text('Version', style: TextStyle(color: context.colors.foreground50)),
                  trailing: Text('1.0.0', style: TextStyle(color: context.colors.foreground400)),
                ),
                Divider(color: context.colors.background700, height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Remix.file_text_line, color: context.colors.foreground50),
                  title: Text('Mentions légales', style: TextStyle(color: context.colors.foreground50)),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(color: context.colors.foreground400, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
