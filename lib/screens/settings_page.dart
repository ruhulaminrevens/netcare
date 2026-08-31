import 'package:flutter/material.dart';

import '../core/app_strings.dart';
import '../widgets/netcare_widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    required this.strings,
    required this.isBangla,
    required this.darkMode,
    required this.onLanguageChanged,
    required this.onDarkModeChanged,
    super.key,
  });

  final AppStrings strings;
  final bool isBangla;
  final bool darkMode;
  final ValueChanged<bool> onLanguageChanged;
  final ValueChanged<bool> onDarkModeChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width >= 700 ? 28 : 16,
        vertical: 20,
      ),
      children: [
        Text(
          strings.t('settings'),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.translate_rounded),
                title: Text(strings.t('language')),
                subtitle: Text(isBangla ? 'বাংলা' : 'English'),
                value: isBangla,
                onChanged: onLanguageChanged,
              ),
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.dark_mode_outlined),
                title: Text(strings.t('darkMode')),
                subtitle: Text(strings.t('appearance')),
                value: darkMode,
                onChanged: onDarkModeChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(
              strings.t('privacy'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(strings.t('privacyBody')),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.monitor_heart_rounded),
            title: Text(
              strings.t('about'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text('${strings.t('aboutBody')}\n${strings.t('version')}'),
            ),
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}
