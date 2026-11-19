import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/database.dart';
import '../../data/models.dart';
import '../../services/arasaac.dart';
import '../../state/providers.dart';
import '../../symbols/symbol_catalog.dart';
import '../widgets/picture_view.dart';
import 'navigation.dart';

/// A picture the adult chose, with a suggested card label.
@immutable
class PickedPicture {
  const PickedPicture({required this.picture, required this.label});

  final PictureRef picture;
  final String label;
}

/// Opens the full-screen picture library. Returns null if cancelled.
Future<PickedPicture?> pickPicture(
  BuildContext context, {
  String initialQuery = '',
}) {
  return Navigator.of(context).push<PickedPicture>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PicturePickerScreen(initialQuery: initialQuery),
    ),
  );
}

class PicturePickerScreen extends StatelessWidget {
  const PicturePickerScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Choose a picture'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.emoji_symbols_rounded), text: 'Symbols'),
              Tab(icon: Icon(Icons.photo_library_outlined), text: 'My photos'),
              Tab(icon: Icon(Icons.cloud_download_outlined), text: 'ARASAAC'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SymbolBrowser(
              initialQuery: initialQuery,
              onPicked: (s) => Navigator.pop(
                context,
                PickedPicture(picture: SymbolPicture(s.id), label: s.label),
              ),
            ),
            _PhotosTab(onPicked: (p) => Navigator.pop(context, p)),
            _ArasaacTab(
              initialQuery: initialQuery,
              onPicked: (p) => Navigator.pop(context, p),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Bundled symbols
// -----------------------------------------------------------------------------

/// Search and browse the bundled pictograms. With [draggable] set, tiles can
/// be dragged onto a board (used by the wide editor layout).
class SymbolBrowser extends ConsumerStatefulWidget {
  const SymbolBrowser({
    super.key,
    required this.onPicked,
    this.initialQuery = '',
    this.draggable = false,
    this.tileExtent = 128,
  });

  final void Function(SymbolInfo symbol) onPicked;
  final String initialQuery;
  final bool draggable;
  final double tileExtent;

  @override
  ConsumerState<SymbolBrowser> createState() => _SymbolBrowserState();
}

class _SymbolBrowserState extends ConsumerState<SymbolBrowser> {
  late final _search = TextEditingController(text: widget.initialQuery);
  String? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(symbolCatalogProvider);
    final query = _search.text;
    final results = catalog.search(
      query,
      category: query.isEmpty ? _category : null,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Search pictures, e.g. “teeth” or “park”',
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(_search.clear),
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (query.isEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: _category == null,
                    onSelected: (_) => setState(() => _category = null),
                  ),
                ),
                for (final c in catalog.categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c.label),
                      selected: _category == c.id,
                      onSelected: (_) => setState(() => _category = c.id),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: results.isEmpty
              ? _NoResults(query: query)
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: widget.tileExtent,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final s = results[i];
                    final tile = PictureTile(
                      label: s.label,
                      onTap: () => widget.onPicked(s),
                      child: SvgPicture.asset(
                        s.asset,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    );
                    if (!widget.draggable) return tile;
                    final data = PickedPicture(
                      picture: SymbolPicture(s.id),
                      label: s.label,
                    );
                    return Draggable<PickedPicture>(
                      data: data,
                      feedback: _DragFeedback(child: SvgPicture.asset(s.asset)),
                      childWhenDragging: Opacity(opacity: 0.4, child: tile),
                      child: tile,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'No bundled pictures for “$query”.\nTry another word, use one of your photos, or search ARASAAC.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      color: Colors.white,
      child: SizedBox.square(
        dimension: 96,
        child: Padding(padding: const EdgeInsets.all(10), child: child),
      ),
    );
  }
}

/// A square picture with its name, used in all picture grids.
class PictureTile extends StatelessWidget {
  const PictureTile({
    super.key,
    required this.label,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
              child: Column(
                children: [
                  Expanded(child: Center(child: child)),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF21323A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Family photos
// -----------------------------------------------------------------------------

class _PhotosTab extends ConsumerWidget {
  const _PhotosTab({required this.onPicked});

  final void Function(PickedPicture) onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(picturesProvider(PictureSource.photo));
    final theme = Theme.of(context);
    final canUseCamera =
        kIsWeb || defaultTargetPlatform == TargetPlatform.android;
    final list = photos.value ?? const <PictureRow>[];

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Photos of your own home, people and places often work best. '
              'They stay on this device.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 140,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
            ),
            delegate: SliverChildListDelegate([
              if (canUseCamera)
                _ActionTile(
                  icon: Icons.photo_camera_outlined,
                  label: 'Take photo',
                  onTap: () => _addPhoto(context, ref, ImageSource.camera),
                ),
              _ActionTile(
                icon: Icons.add_photo_alternate_outlined,
                label: 'Choose photo',
                onTap: () => _addPhoto(context, ref, ImageSource.gallery),
              ),
              for (final p in list)
                PictureTile(
                  label: p.label,
                  onTap: () => onPicked(
                    PickedPicture(picture: StoredPicture(p.id), label: p.label),
                  ),
                  onLongPress: () => _photoMenu(context, ref, p),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: PictureView(
                      picture: StoredPicture(p.id),
                      label: p.label,
                      fit: BoxFit.cover,
                      thumbnailWidth: 140,
                    ),
                  ),
                ),
            ]),
          ),
        ),
        if (list.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Press and hold a photo to rename or delete it.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addPhoto(
    BuildContext context,
    WidgetRef ref,
    ImageSource source,
  ) async {
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
    } catch (e) {
      if (context.mounted) {
        showMessage(
          context,
          'Could not open the ${source == ImageSource.camera ? 'camera' : 'photos'}.',
        );
      }
      return;
    }
    if (file == null || !context.mounted) return;
    final bytes = await file.readAsBytes();
    if (!context.mounted) return;
    final name = await promptText(
      context,
      title: 'Name this picture',
      hint: 'e.g. Grandma’s house',
      initial: '',
      action: 'Add',
    );
    if (name == null) return;
    final repo = ref.read(repositoryProvider);
    final id = await repo.addPicture(
      source: PictureSource.photo,
      label: name,
      bytes: bytes,
      mimeType: file.mimeType ?? _guessMime(file.name),
    );
    onPicked(PickedPicture(picture: StoredPicture(id), label: name));
  }

  Future<void> _photoMenu(
    BuildContext context,
    WidgetRef ref,
    PictureRow p,
  ) async {
    final repo = ref.read(repositoryProvider);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline_rounded),
              title: const Text('Rename'),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'rename':
        final name = await promptText(
          context,
          title: 'Rename picture',
          initial: p.label,
        );
        if (name != null) await repo.renamePicture(p.id, name);
      case 'delete':
        final uses = await repo.countPictureUses(p.id);
        if (!context.mounted) return;
        final ok = await confirm(
          context,
          title: 'Delete “${p.label}”?',
          message: uses == 0
              ? 'This photo will be removed from this device.'
              : 'It is used on $uses ${uses == 1 ? 'card' : 'cards'}. Those cards will keep their words but lose the photo.',
          action: 'Delete',
        );
        if (ok) await repo.deletePicture(p.id);
    }
  }
}

String _guessMime(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: scheme.onPrimaryContainer),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ARASAAC (optional, online)
// -----------------------------------------------------------------------------

class _ArasaacTab extends ConsumerStatefulWidget {
  const _ArasaacTab({required this.onPicked, this.initialQuery = ''});

  final void Function(PickedPicture) onPicked;
  final String initialQuery;

  @override
  ConsumerState<_ArasaacTab> createState() => _ArasaacTabState();
}

class _ArasaacTabState extends ConsumerState<_ArasaacTab> {
  late final _search = TextEditingController(text: widget.initialQuery);
  List<ArasaacPictogram>? _results;
  String? _error;
  bool _loading = false;
  int? _downloading;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final q = _search.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ref.read(arasaacClientProvider).search(q);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = 'Could not reach ARASAAC. Check the internet connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _download(ArasaacPictogram p) async {
    final repo = ref.read(repositoryProvider);
    final existing = await repo.findByRemoteId(
      PictureSource.arasaac,
      '${p.id}',
    );
    if (existing != null) {
      widget.onPicked(
        PickedPicture(
          picture: StoredPicture(existing.id),
          label: existing.label,
        ),
      );
      return;
    }
    setState(() => _downloading = p.id);
    try {
      final bytes = await ref.read(arasaacClientProvider).download(p.id);
      final id = await repo.addPicture(
        source: PictureSource.arasaac,
        label: p.label,
        bytes: bytes,
        mimeType: 'image/png',
        attribution: ArasaacClient.attribution,
        remoteId: '${p.id}',
      );
      widget.onPicked(
        PickedPicture(picture: StoredPicture(id), label: p.label),
      );
    } catch (e) {
      if (mounted) showMessage(context, 'Download failed. Please try again.');
    } finally {
      if (mounted) setState(() => _downloading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final downloaded =
        ref.watch(picturesProvider(PictureSource.arasaac)).value ?? const [];
    final results = _results;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Card(
              color: theme.colorScheme.secondaryContainer.withValues(
                alpha: 0.5,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Optional download',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'ARASAAC has thousands more pictograms. They need the internet to search, '
                      'and once downloaded they work offline. They are by Sergio Palao for the '
                      'Government of Aragón and licensed CC BY-NC-SA 4.0: free for personal, '
                      'school and therapy use, but not for commercial use.',
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => launchUrl(
                          Uri.parse('https://arasaac.org/terms-of-use'),
                        ),
                        child: const Text('ARASAAC terms of use'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          sliver: SliverToBoxAdapter(
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _runSearch(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.travel_explore_rounded),
                hintText: 'Search ARASAAC',
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: _runSearch,
                ),
              ),
            ),
          ),
        ),
        if (_loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        if (_error != null)
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ),
        if (results != null && results.isEmpty && !_loading)
          const SliverPadding(
            padding: EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Text('No ARASAAC pictograms found.'),
            ),
          ),
        if (results != null && results.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 140,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.82,
              ),
              delegate: SliverChildBuilderDelegate((context, i) {
                final p = results[i];
                return PictureTile(
                  label: p.label,
                  onTap: _downloading == null ? () => _download(p) : null,
                  child: _downloading == p.id
                      ? const CircularProgressIndicator()
                      : Image.network(
                          p.previewUrl.toString(),
                          fit: BoxFit.contain,
                          webHtmlElementStrategy:
                              WebHtmlElementStrategy.fallback,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                );
              }, childCount: results.length),
            ),
          ),
        if (downloaded.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text('Downloaded', style: theme.textTheme.titleMedium),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 140,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.82,
              ),
              delegate: SliverChildBuilderDelegate((context, i) {
                final p = downloaded[i];
                return PictureTile(
                  label: p.label,
                  onTap: () => widget.onPicked(
                    PickedPicture(picture: StoredPicture(p.id), label: p.label),
                  ),
                  child: PictureView(
                    picture: StoredPicture(p.id),
                    label: p.label,
                    thumbnailWidth: 140,
                  ),
                );
              }, childCount: downloaded.length),
            ),
          ),
        ],
      ],
    );
  }
}
