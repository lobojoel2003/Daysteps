import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/arasaac.dart';
import '../../state/providers.dart';
import '../widgets/brand_mark.dart';

const sourceCodeUrl = 'https://github.com/lobojoel2003/Daysteps';

final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final info = ref.watch(packageInfoProvider).value;
    final catalog = ref.watch(symbolCatalogProvider);
    final version = info == null
        ? ''
        : 'Version ${info.version} (build ${info.buildNumber})';

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const SizedBox(height: 8),
              const Center(child: BrandMark(size: 96)),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Daysteps',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Center(child: Text(version, style: theme.textTheme.bodyMedium)),
              const SizedBox(height: 16),
              Text(
                'Picture schedules, first–then boards and visual timers. Free and open source, '
                'for Android and the web.',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const _Section(
                icon: Icons.lock_outline_rounded,
                title: 'Privacy',
                body:
                    'No account, no ads, no tracking. Your boards and photos are stored only on this '
                    'device. The internet is used only if you choose to search ARASAAC pictograms or '
                    'open a shared link.',
              ),
              _Section(
                icon: Icons.emoji_symbols_rounded,
                title: 'Pictures',
                body: [
                  for (final set in catalog.sets.values)
                    '${set.name} by ${set.author}, licensed ${set.license}.',
                  'The bundled files were optimised for the app (modified) and are shared under the same licence.',
                  'Optional ARASAAC pictograms: ${ArasaacClient.attribution}',
                ].join('\n\n'),
              ),
              const _Section(
                icon: Icons.font_download_outlined,
                title: 'Font',
                body: 'Atkinson Hyperlegible by the Braille Institute of America, SIL Open Font License 1.1.',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final set in catalog.sets.values)
                    OutlinedButton(
                      onPressed: () => launchUrl(Uri.parse(set.url)),
                      child: Text(set.name),
                    ),
                  OutlinedButton(
                    onPressed: () =>
                        launchUrl(Uri.parse('https://arasaac.org')),
                    child: const Text('ARASAAC'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(sourceCodeUrl)),
                    icon: const Icon(Icons.code_rounded),
                    label: const Text('Source code'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => showLicensePage(
                      context: context,
                      applicationName: 'Daysteps',
                      applicationVersion: info?.version,
                      applicationIcon: const Padding(
                        padding: EdgeInsets.all(12),
                        child: BrandMark(size: 64),
                      ),
                      applicationLegalese:
                          '© Daysteps contributors. GNU GPL v3.0.',
                    ),
                    child: const Text('All licences'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(body, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
