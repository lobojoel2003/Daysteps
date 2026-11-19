import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../theme.dart';
import '../widgets/picture_view.dart';

/// How prominent a card is in the child view.
enum KidCardRole { now, next, later }

/// A big picture card for the child view.
class KidCard extends StatelessWidget {
  const KidCard({
    super.key,
    required this.step,
    required this.role,
    this.tag,
    this.showLabel = true,
    this.onTap,
    this.pictureOverride,
    this.footer,
    this.dimmed = false,
  });

  final BoardStep step;
  final KidCardRole role;

  /// Small word in the corner, e.g. "Now", "Next", "First", "Then".
  final String? tag;
  final bool showLabel;
  final VoidCallback? onTap;

  /// Replaces the picture (used to show the visual timer around it).
  final Widget? pictureOverride;

  /// Shown under the label (the Done button).
  final Widget? footer;

  /// Faded, e.g. a finished "first" card.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final isNow = role == KidCardRole.now;
    final radius = switch (role) {
      KidCardRole.now => 40.0,
      KidCardRole.next => 32.0,
      KidCardRole.later => 24.0,
    };
    final border = switch (role) {
      KidCardRole.now => Border.all(color: KidColors.now, width: 7),
      _ => Border.all(color: KidColors.track, width: 3),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final shortest = constraints.biggest.shortestSide;
        final labelSize = (shortest * (isNow ? 0.085 : 0.1)).clamp(
          18.0,
          isNow ? 54.0 : 36.0,
        );
        final pad = (shortest * 0.06).clamp(10.0, 32.0);

        final card = AnimatedOpacity(
          opacity: dimmed ? 0.45 : 1,
          duration: const Duration(milliseconds: 400),
          child: Container(
            decoration: BoxDecoration(
              color: KidColors.card,
              borderRadius: BorderRadius.circular(radius),
              border: border,
              boxShadow: [
                BoxShadow(
                  color: (isNow ? KidColors.now : Colors.black).withValues(
                    alpha: isNow ? 0.28 : 0.06,
                  ),
                  blurRadius: isNow ? 32 : 16,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              borderRadius: BorderRadius.circular(radius),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                hoverColor: Colors.transparent,
                splashColor: KidColors.now.withValues(alpha: 0.18),
                highlightColor: Colors.transparent,
                child: Padding(
                  padding: EdgeInsets.all(pad),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child:
                              pictureOverride ??
                              PictureView(
                                picture: step.picture,
                                label: step.label,
                                fit: BoxFit.contain,
                              ),
                        ),
                      ),
                      // Words-only cards already show their words as the picture.
                      if (showLabel &&
                          step.label.isNotEmpty &&
                          (step.picture != null ||
                              pictureOverride != null)) ...[
                        SizedBox(height: pad * 0.5),
                        Text(
                          step.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: labelSize,
                            fontWeight: FontWeight.w700,
                            color: KidColors.text,
                            height: 1.1,
                          ),
                        ),
                      ],
                      if (footer != null) ...[
                        SizedBox(height: pad * 0.6),
                        footer!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        if (tag == null) return card;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: card),
            Positioned(
              left: radius * 0.6,
              top: -14,
              child: KidTag(text: tag!, strong: isNow),
            ),
          ],
        );
      },
    );
  }
}

/// The little "Now" / "Next" label on a card's top edge.
class KidTag extends StatelessWidget {
  const KidTag({super.key, required this.text, this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: strong ? KidColors.now : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: strong ? null : Border.all(color: KidColors.track, width: 2),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: strong ? KidColors.text : KidColors.muted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// The big round "Done" button.
class DoneButton extends StatefulWidget {
  const DoneButton({
    super.key,
    required this.onPressed,
    this.size = 96,
    this.attention = false,
  });

  final VoidCallback? onPressed;
  final double size;

  /// Gently pulse to draw attention (e.g. when the timer has finished).
  final bool attention;

  @override
  State<DoneButton> createState() => _DoneButtonState();
}

class _DoneButtonState extends State<DoneButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(DoneButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.attention && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.attention && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Done',
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => Transform.scale(
          scale: 1 + 0.08 * Curves.easeInOut.transform(_pulse.value),
          child: child,
        ),
        child: Material(
          color: KidColors.done,
          shape: const CircleBorder(),
          elevation: 4,
          shadowColor: KidColors.done.withValues(alpha: 0.5),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onPressed,
            child: SizedBox.square(
              dimension: widget.size,
              child: Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: widget.size * 0.62,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
