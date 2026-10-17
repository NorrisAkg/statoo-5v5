import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/participation.dart';
import '../domain/session.dart';
import '../domain/team_appearance.dart';

String sessionCelebrationMessage(Session session) {
  final teams = session.sessionType == SessionType.tournament3
      ? Team.values
      : [Team.a, Team.b];
  final values = session.sessionType == SessionType.tournament3
      ? [session.winsA, session.winsB, session.winsC]
      : [session.scoreA ?? 0, session.scoreB ?? 0];
  final maximum = values.reduce(math.max);
  final winners = [
    for (var i = 0; i < teams.length; i++)
      if (values[i] == maximum) effectiveTeamName(teams[i], session.teamNames),
  ];
  if (winners.length == teams.length) return 'Bravo à tous pour cette séance !';
  if (winners.length == 1) return 'Bravo à ${winners.single} !';
  return 'Égalité entre ${winners.join(' et ')}. Bravo à tous !';
}

class SessionCelebration extends StatefulWidget {
  const SessionCelebration({required this.session, super.key});
  final Session session;
  @override
  State<SessionCelebration> createState() => _SessionCelebrationState();
}

class _SessionCelebrationState extends State<SessionCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && !MediaQuery.disableAnimationsOf(context)) {
      _started = true;
      _animation.forward();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(sessionCelebrationMessage(widget.session)),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!MediaQuery.disableAnimationsOf(context))
          ExcludeSemantics(
            child: SizedBox(
              height: 80,
              width: 260,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, _) => CustomPaint(
                  key: const ValueKey('celebration-confetti'),
                  painter: _Confetti(
                    _animation.value,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        const Text('La séance est clôturée. Merci à tous les participants !'),
      ],
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Continuer'),
      ),
    ],
  );
}

class _Confetti extends CustomPainter {
  _Confetti(this.progress, this.color);
  final double progress;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1) return;
    final paint = Paint()..color = color.withValues(alpha: 1 - progress);
    for (var i = 0; i < 24; i++) {
      final x = (i * 47 % 260) / 260 * size.width;
      final y = ((i * 13 % 40) + progress * 80) % size.height;
      canvas.drawRect(Rect.fromLTWH(x, y, 5, 9), paint);
    }
  }

  @override
  bool shouldRepaint(_Confetti oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
