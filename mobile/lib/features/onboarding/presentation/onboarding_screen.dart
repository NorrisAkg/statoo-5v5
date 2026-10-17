import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/theme/app_colors.dart';
import '../application/onboarding_provider.dart';

// ─── Main Screen ──────────────────────────────────────────────────────────────

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingPageData> _pages = [
    _OnboardingPageData(
      title: 'Suivez vos matchs 5v5',
      subtitle: 'Enregistrez facilement vos séances, scores et statistiques individuelles au bord du terrain.',
    ),
    _OnboardingPageData(
      title: 'Tirage rapide & équilibré',
      subtitle: "Générez vos compositions d'équipes aléatoires et ajustez les joueurs en temps réel.",
    ),
    _OnboardingPageData(
      title: 'Classement & Statistiques',
      subtitle: 'Découvrez qui domine au classement des points, aux victoires et au tableau des buteurs.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding({bool toTeamCreation = true}) async {
    await ref.read(hasSeenOnboardingProvider.notifier).completeOnboarding();
    if (mounted) {
      if (toTeamCreation) {
        context.go('/creer-equipe');
      } else {
        context.go('/');
      }
    }
  }

  Future<void> _nextPage() async {
    if (_currentPage < _pages.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      await _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background950,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: context.colors.primary500,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Remix.football_fill,
                            size: 16,
                            color: context.colors.background950,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Statoo',
                          style: TextStyle(
                            color: context.colors.foreground100,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    if (_currentPage < _pages.length - 1)
                      TextButton(
                        onPressed: _completeOnboarding,
                        child: Text(
                          'Passer',
                          style: TextStyle(
                            color: context.colors.foreground400,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (ctx, i) => _buildPage(ctx, _pages[i], i),
              ),
            ),

            // Bottom controls
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: _currentPage == _pages.length - 1
                  ? _buildStartButton(context)
                  : _buildNextRow(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context, _OnboardingPageData data, int index) {
    return Column(
      children: [
        // Illustration (60%)
        Expanded(
          flex: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: MediaQuery.textScalerOf(context).scale(14) > 20
                ? Center(
                    child: Icon(
                      switch (index) {
                        0 => Remix.football_line,
                        1 => Remix.shuffle_line,
                        _ => Remix.trophy_line,
                      },
                      size: 96,
                      color: context.colors.primary500,
                    ),
                  )
                : switch (index) {
                    0 => const _ScoreboardIllustration(),
                    1 => const _ShuffleIllustration(),
                    _ => const _LeaderboardIllustration(),
                  },
          ),
        ),

        // Text (40%)
        Expanded(
          flex: 40,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: context.colors.foreground50,
                          height: 1.2,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        data.subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.colors.foreground400,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_pages.length, (i) {
        final active = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active
                ? context.colors.primary500
                : context.colors.background700,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildNextRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildPageIndicator(),
        GestureDetector(
          onTap: _nextPage,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              color: context.colors.primary500.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(
                color: context.colors.primary500.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Suivant',
                  style: TextStyle(
                    color: context.colors.primary400,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Remix.arrow_right_line,
                  size: 15,
                  color: context.colors.primary400,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return Column(
      children: [
        Center(child: _buildPageIndicator()),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _completeOnboarding,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary500,
              foregroundColor: context.colors.background950,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9999),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Commencer',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
}

// ─── Shared Painters ──────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0DFFFFFF)
      ..strokeWidth = 0.5;
    const step = 36.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter o) => false;
}

class _HexagonPainter extends CustomPainter {
  const _HexagonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x09FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const r = 26.0;
    final h = r * math.sqrt(3);

    for (double row = -r; row < size.height + r; row += h) {
      for (double col = -r; col < size.width + r; col += r * 3) {
        _drawHex(canvas, paint, Offset(col, row), r);
        _drawHex(canvas, paint, Offset(col + r * 1.5, row + h / 2), r);
      }
    }
  }

  void _drawHex(Canvas canvas, Paint paint, Offset c, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = math.pi / 3 * i - math.pi / 6;
      final x = c.dx + r * math.cos(a);
      final y = c.dy + r * math.sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HexagonPainter o) => false;
}

class _DiagonalPainter extends CustomPainter {
  const _DiagonalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x09FFFFFF)
      ..strokeWidth = 1.0;
    const step = 28.0;
    for (double i = -size.height; i < size.width + size.height; i += step) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DiagonalPainter o) => false;
}

class _SparkleParticle {
  const _SparkleParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
    required this.speed,
  });
  final double x;
  final double y;
  final double size;
  final double phase;
  final double speed;
}

class _SparklesPainter extends CustomPainter {
  const _SparklesPainter({
    required this.particles,
    required this.progress,
    required this.color,
  });
  final List<_SparkleParticle> particles;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = (progress * p.speed + p.phase) % 1.0;
      final opacity = (math.sin(t * math.pi * 2) * 0.35 + 0.4).clamp(0.0, 0.75);
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SparklesPainter o) => o.progress != progress;
}

// ─── Slide 1 : Scoreboard ─────────────────────────────────────────────────────

class _ScoreboardIllustration extends StatefulWidget {
  const _ScoreboardIllustration();

  @override
  State<_ScoreboardIllustration> createState() =>
      _ScoreboardIllustrationState();
}

class _ScoreboardIllustrationState extends State<_ScoreboardIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_SparkleParticle> _particles;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    final rng = math.Random(11);
    _particles = List.generate(
      20,
      (_) => _SparkleParticle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: rng.nextDouble() * 2.2 + 0.6,
        phase: rng.nextDouble(),
        speed: rng.nextDouble() * 0.4 + 0.2,
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: c.background900,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.background700),
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final glow = 0.4 + 0.6 * math.sin(_ctrl.value * math.pi * 2).abs();
            return Stack(
              fit: StackFit.expand,
              children: [
                // Grid background
                const CustomPaint(painter: _GridPainter()),

                // Sparks (orange)
                CustomPaint(
                  painter: _SparklesPainter(
                    particles: _particles,
                    progress: _ctrl.value,
                    color: c.secondary400,
                  ),
                ),

                // Radial ambient glow
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.65,
                      colors: [
                        c.primary500.withValues(alpha: 0.07 * glow),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                // Scoreboard card
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: c.background800,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: c.primary500.withValues(alpha: 0.3 + 0.5 * glow),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: c.primary500.withValues(alpha: 0.2 * glow),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Label
                        Text(
                          'SÉANCE · MATCH #12',
                          style: TextStyle(
                            color: c.foreground500,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Teams + score
                        Row(
                          children: [
                            // Équipe A
                            Expanded(
                              child: Column(
                                children: [
                                  _AvatarCircle(
                                    label: 'A',
                                    color: c.primary500,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'Équipe A',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: c.foreground300,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Score box
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: c.background700,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '5',
                                    style: TextStyle(
                                      color: c.primary400,
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      '-',
                                      style: TextStyle(
                                        color: c.foreground500,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '3',
                                    style: TextStyle(
                                      color: c.secondary400,
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Équipe B
                            Expanded(
                              child: Column(
                                children: [
                                  _AvatarCircle(
                                    label: 'B',
                                    color: c.secondary500,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'Équipe B',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: c.foreground300,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Tags
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _TeamTag(label: '5 buts ✓', color: c.primary500),
                            const SizedBox(width: 6),
                            _Dot(color: c.foreground600),
                            const SizedBox(width: 6),
                            _TeamTag(label: '3 buts', color: c.secondary500),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Slide 2 : Shuffle ────────────────────────────────────────────────────────

class _ShuffleIllustration extends StatefulWidget {
  const _ShuffleIllustration();

  @override
  State<_ShuffleIllustration> createState() => _ShuffleIllustrationState();
}

class _ShuffleIllustrationState extends State<_ShuffleIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _spin;
  late Animation<double> _pulse;

  static const _teamA = ['BL', 'KG', 'EP', 'IJ', 'BH'];
  static const _teamB = ['AV', 'MS', 'HL', 'GR', 'CH'];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _spin = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.linear));
    _pulse = Tween<double>(
      begin: 0.85,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: c.background900,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.background700),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: _HexagonPainter()),
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    // Team A avatars
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _teamA.asMap().entries.map((e) {
                          final t = (_ctrl.value + e.key * 0.18) % 1.0;
                          final glow =
                              0.2 + 0.7 * math.sin(t * math.pi * 2).abs();
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.5),
                            child: _PlayerAvatar(
                              label: e.value,
                              color: c.primary500,
                              glowIntensity: glow,
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // Center shuffle icon
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Transform.scale(
                        scale: _pulse.value,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: c.primary500.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: c.primary500.withValues(alpha: 0.4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: c.primary500.withValues(
                                  alpha: 0.35 * _pulse.value,
                                ),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Transform.rotate(
                            angle: _spin.value,
                            child: Icon(
                              Remix.shuffle_line,
                              size: 20,
                              color: c.primary400,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Team B avatars
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _teamB.asMap().entries.map((e) {
                          final t = (_ctrl.value + e.key * 0.18 + 0.5) % 1.0;
                          final glow =
                              0.2 + 0.7 * math.sin(t * math.pi * 2).abs();
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.5),
                            child: _PlayerAvatar(
                              label: e.value,
                              color: c.secondary500,
                              glowIntensity: glow,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Slide 3 : Leaderboard ────────────────────────────────────────────────────

class _PlayerEntry {
  const _PlayerEntry(this.rank, this.name, this.pts, this.color);
  final int rank;
  final String name;
  final String pts;
  final Color color;
}

class _LeaderboardIllustration extends StatefulWidget {
  const _LeaderboardIllustration();

  @override
  State<_LeaderboardIllustration> createState() =>
      _LeaderboardIllustrationState();
}

class _LeaderboardIllustrationState extends State<_LeaderboardIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _glow;

  static const List<_PlayerEntry> _players = [
    _PlayerEntry(1, 'Lucas', '27 pts', Color(0xFFFACC15)),
    _PlayerEntry(2, 'Karim', '21 pts', Color(0xFFCBD5E1)),
    _PlayerEntry(3, 'Sofiane', '18 pts', Color(0xFFF97316)),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glow = Tween<double>(
      begin: 0.2,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: c.background900,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.background700),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: _DiagonalPainter()),
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Trophy
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFACC15)
                            .withValues(alpha: 0.1 + 0.08 * _glow.value),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFACC15)
                                .withValues(alpha: 0.45 * _glow.value),
                            blurRadius: 20 + 8 * _glow.value,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Remix.trophy_fill,
                        size: 24,
                        color: Color(0xFFFACC15),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Rows
                    ..._players.map((p) {
                      final isFirst = p.rank == 1;
                      final rowGlow = isFirst ? _glow.value : 0.15;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _LeaderboardRow(
                          entry: p,
                          glowIntensity: rowGlow,
                          colors: c,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared Sub-widgets ───────────────────────────────────────────────────────

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _TeamTag extends StatelessWidget {
  const _TeamTag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({
    required this.label,
    required this.color,
    required this.glowIntensity,
  });
  final String label;
  final Color color;
  final double glowIntensity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: 0.4 + 0.4 * glowIntensity),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3 * glowIntensity),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.entry,
    required this.glowIntensity,
    required this.colors,
  });
  final _PlayerEntry entry;
  final double glowIntensity;
  final AppColorsExtension colors;

  @override
  Widget build(BuildContext context) {
    final c = entry.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.06 + 0.06 * glowIntensity),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: c.withValues(alpha: 0.18 + 0.22 * glowIntensity),
        ),
        boxShadow: glowIntensity > 0.3
            ? [
                BoxShadow(
                  color: c.withValues(alpha: 0.15 * glowIntensity),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 20,
            child: Text(
              '${entry.rank}',
              style: TextStyle(
                color: c,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Avatar
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                entry.name[0],
                style: TextStyle(
                  color: c,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Name
          Expanded(
            child: Text(
              entry.name,
              style: TextStyle(
                color: colors.foreground100,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),

          // Points badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              entry.pts,
              style: TextStyle(
                color: c,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
