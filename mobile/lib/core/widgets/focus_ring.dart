import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_colors.dart';

/// Anneau de focus clavier commun à toute l'application (A11Y-001).
///
/// Le surlignage Material de focus ne contrastait qu'à 1,15:1 avec l'état normal. Cet
/// anneau entoure l'élément qui a le focus, quel que soit le widget (bouton, carte,
/// élément de liste), avec la couleur du texte principal du thème, donc contrastée sur
/// les fonds clairs et sombres. Il n'apparaît qu'en navigation clavier
/// ([FocusHighlightMode.traditional]) et ne reçoit ni appui ni sémantique.
class FocusRing extends StatefulWidget {
  const FocusRing({required this.child, super.key});

  final Widget child;

  /// Écart entre l'élément et l'anneau, puis épaisseur du trait.
  static const double gap = 2;
  static const double width = 2;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  _Ring? _ring;
  bool _tracking = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance
      ..addListener(_onFocus)
      ..addHighlightModeListener(_onMode);
  }

  @override
  void dispose() {
    FocusManager.instance
      ..removeListener(_onFocus)
      ..removeHighlightModeListener(_onMode);
    super.dispose();
  }

  void _onFocus() => _schedule(requestFrame: true);

  void _onMode(FocusHighlightMode _) => _schedule(requestFrame: true);

  /// Après un changement de focus, une image est demandée pour relire la position. Tant
  /// que l'anneau est affiché, la position est relue après chaque image produite par
  /// ailleurs (défilement, animation), sans en demander de nouvelles.
  void _schedule({bool requestFrame = false}) {
    if (!mounted) return;
    if (!_tracking) {
      _tracking = true;
      SchedulerBinding.instance.addPostFrameCallback(_check);
    }
    if (requestFrame) SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _check(Duration _) {
    _tracking = false;
    if (!mounted) {
      return;
    }
    final ring = _focusedRing();
    if (ring != _ring) {
      setState(() => _ring = ring);
    }
    if (ring != null) {
      _schedule();
    }
  }

  _Ring? _focusedRing() {
    final manager = FocusManager.instance;
    final node = manager.primaryFocus;
    final focused = node?.context;
    final self = context.findRenderObject();
    final usable =
        manager.highlightMode == FocusHighlightMode.traditional &&
        node is! FocusScopeNode &&
        focused != null &&
        focused.mounted &&
        // Un champ de saisie a déjà sa bordure de focus, et son nœud ne couvre que le texte.
        focused.findAncestorStateOfType<EditableTextState>() == null &&
        self is RenderBox &&
        self.attached &&
        self.hasSize;
    final target = usable ? focused.findRenderObject() : null;
    if (target is! RenderBox || !target.attached || !target.hasSize) {
      return null;
    }
    final box = self! as RenderBox;
    // Taille affichée, transformations comprises (mise à l'échelle des transitions).
    final rect = MatrixUtils.transformRect(
      target.getTransformTo(box),
      Offset.zero & target.size,
    );
    // Une portée entière (page, feuille) n'est pas une commande à entourer.
    if (rect.width >= box.size.width && rect.height >= box.size.height) {
      return null;
    }
    // Zone réellement visible : intersection des rognages des ancêtres (zones de
    // défilement notamment), pour ne pas dessiner sur l'en-tête ou la navigation.
    var clip = Offset.zero & box.size;
    RenderObject child = target;
    for (
      var parent = target.parent;
      parent != null && parent != box;
      parent = parent.parent
    ) {
      final local = parent.describeApproximatePaintClip(child);
      if (local != null) {
        clip = clip.intersect(
          MatrixUtils.transformRect(parent.getTransformTo(box), local),
        );
      }
      child = parent;
    }
    if (!clip.overlaps(rect)) {
      return null;
    }
    return (rect: rect, clip: clip);
  }

  @override
  Widget build(BuildContext context) {
    final ring = _ring;
    return Stack(
      alignment: Alignment.topLeft,
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        if (ring != null)
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: _RingPainter(ring, context.colors.foreground50),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Élément focalisé et zone visible dans laquelle dessiner, en coordonnées de [FocusRing].
typedef _Ring = ({Rect rect, Rect clip});

class _RingPainter extends CustomPainter {
  _RingPainter(this.ring, this.color);

  final _Ring ring;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = FocusRing.gap + FocusRing.width / 2;
    const extent = FocusRing.gap + FocusRing.width;
    final (:rect, :clip) = ring;
    // Élément entièrement visible : l'anneau peut déborder de sa zone de défilement.
    // Élément en partie masqué : l'anneau s'arrête au bord de la zone visible.
    final inside =
        clip.contains(rect.topLeft) &&
        clip.contains(rect.bottomRight - const Offset(0.01, 0.01));
    canvas
      ..save()
      ..clipRect(inside ? clip.inflate(extent) : clip)
      ..drawRRect(
        RRect.fromRectAndRadius(rect.inflate(inset), const Radius.circular(10)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = FocusRing.width
          ..color = color,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.ring != ring || old.color != color;
}
