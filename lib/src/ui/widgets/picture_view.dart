import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../theme.dart';

/// Renders the picture of a card: a bundled pictogram (SVG), a stored photo
/// or ARASAAC download, or — when there is no picture — the words themselves.
class PictureView extends ConsumerWidget {
  const PictureView({
    super.key,
    required this.picture,
    required this.label,
    this.fit = BoxFit.contain,
    this.padding = EdgeInsets.zero,
    this.thumbnailWidth,
    this.semanticLabel,
  });

  final PictureRef? picture;
  final String label;
  final BoxFit fit;
  final EdgeInsets padding;

  /// Decode stored photos at this width (logical pixels) to save memory in
  /// grids and lists.
  final double? thumbnailWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ref0 = picture;
    final semantics = semanticLabel ?? label;
    return switch (ref0) {
      SymbolPicture(:final symbolId) => _Symbol(
        symbolId: symbolId,
        label: label,
        padding: padding,
        semanticLabel: semantics,
      ),
      StoredPicture(:final pictureId) => _Stored(
        pictureId: pictureId,
        label: label,
        fit: fit,
        padding: padding,
        thumbnailWidth: thumbnailWidth,
        semanticLabel: semantics,
      ),
      null => WordsPicture(label: label),
    };
  }
}

class _Symbol extends ConsumerWidget {
  const _Symbol({
    required this.symbolId,
    required this.label,
    required this.padding,
    required this.semanticLabel,
  });

  final String symbolId;
  final String label;
  final EdgeInsets padding;
  final String semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(symbolCatalogProvider)[symbolId];
    if (info == null) return WordsPicture(label: label);
    return Padding(
      padding: padding,
      // Fill the slot: symbol sets use different viewBox sizes, and an SVG
      // would otherwise shrink to its intrinsic size under loose constraints.
      child: SvgPicture.asset(
        info.asset,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        semanticsLabel: semanticLabel,
        placeholderBuilder: (_) => const SizedBox.expand(),
        errorBuilder: (_, _, _) => WordsPicture(label: label),
      ),
    );
  }
}

class _Stored extends ConsumerWidget {
  const _Stored({
    required this.pictureId,
    required this.label,
    required this.fit,
    required this.padding,
    required this.thumbnailWidth,
    required this.semanticLabel,
  });

  final String pictureId;
  final String label;
  final BoxFit fit;
  final EdgeInsets padding;
  final double? thumbnailWidth;
  final String semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(pictureBytesProvider(pictureId));
    return bytes.when(
      loading: () => const SizedBox.expand(),
      error: (_, _) => WordsPicture(label: label),
      data: (data) {
        if (data == null) return WordsPicture(label: label);
        ImageProvider provider = MemoryImage(data);
        final width = thumbnailWidth;
        if (width != null) {
          final dpr = MediaQuery.devicePixelRatioOf(context);
          provider = ResizeImage(
            provider,
            width: (width * dpr).round(),
            policy: ResizeImagePolicy.fit,
          );
        }
        return Padding(
          padding: padding,
          child: Image(
            image: provider,
            fit: fit,
            gaplessPlayback: true,
            semanticLabel: semanticLabel,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => WordsPicture(label: label),
          ),
        );
      },
    );
  }
}

/// A card face for steps without a picture: the words, large and clear.
class WordsPicture extends StatelessWidget {
  const WordsPicture({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final text = label.trim().isEmpty ? '?' : label.trim();
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide.isFinite
            ? constraints.biggest.shortestSide
            : 120.0;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Brand.sand,
            borderRadius: BorderRadius.circular(size * 0.12),
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(size * 0.08),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: size * 1.6),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    style: TextStyle(
                      fontSize: (size * 0.22).clamp(12, 64),
                      fontWeight: FontWeight.w700,
                      color: Brand.ink,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
