import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../application/onboarding_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPageData> _pages = const [
    _OnboardingPageData(
      title: 'Suivez vos matchs 5v5',
      subtitle:
          'Enregistrez facilement vos séances, scores et statistiques individuelles au bord du terrain.',
      icon: Remix.football_line,
    ),
    _OnboardingPageData(
      title: 'Tirage rapide & équilibré',
      subtitle:
          "Générez vos compositions d'équipes aléatoires et ajustez les joueurs en temps réel.",
      icon: Remix.shuffle_line,
    ),
    _OnboardingPageData(
      title: 'Classement & Statistiques',
      subtitle:
          'Découvrez qui domine au classement des points, aux victoires et au tableau des buteurs.',
      icon: Remix.trophy_line,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    await ref.read(hasSeenOnboardingProvider.notifier).completeOnboarding();
    if (mounted) {
      context.go('/');
    }
  }

  Future<void> _nextPage() async {
    if (_currentPage < _pages.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
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
            // Top Bar with Skip Button
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerRight,
              child: _currentPage < _pages.length - 1
                  ? TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(
                        'Passer',
                        style: TextStyle(
                          color: context.colors.foreground400,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // Main PageView with 60% top / 40% bottom split
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  return _buildPage(context, _pages[index], index);
                },
              ),
            ),

            // Bottom Navigation and Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
        // Top 60%: Graphic placeholder with smooth gradient fade
        Expanded(
          flex: 6,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: context.colors.background900,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: context.colors.background700),
                ),
                child: Center(
                  child: _buildVisualGraphic(context, index),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 120,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        context.colors.background950.withValues(alpha: 0.7),
                        context.colors.background950,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Bottom 40%: Typography (Title & Subtitle)
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: context.colors.foreground50,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  data.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: context.colors.foreground400,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVisualGraphic(BuildContext context, int index) {
    if (index == 0) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: context.colors.primary500.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Remix.football_line, size: 54, color: context.colors.primary400),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMiniTag(context, 'Équipe A · 5', context.colors.accent500),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('VS', style: TextStyle(color: context.colors.foreground500, fontWeight: FontWeight.bold)),
              ),
              _buildMiniTag(context, 'Équipe B · 3', context.colors.secondary500),
            ],
          ),
        ],
      );
    } else if (index == 1) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: context.colors.accent500.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Remix.shuffle_line, size: 54, color: context.colors.accent400),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: context.colors.background800,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.background700),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Remix.user_shared_line, size: 18, color: context.colors.primary400),
                const SizedBox(width: 8),
                Text(
                  'Tirage équilibré 5v5',
                  style: TextStyle(color: context.colors.foreground200, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: context.colors.card.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Remix.trophy_line, size: 54, color: context.colors.card),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMiniMedal(context, '1', context.colors.card),
              const SizedBox(width: 12),
              _buildMiniMedal(context, '2', context.colors.foreground300),
              const SizedBox(width: 12),
              _buildMiniMedal(context, '3', context.colors.secondary500),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildMiniTag(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildMiniMedal(BuildContext context, String rank, Color color) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        rank,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_pages.length, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? context.colors.primary500 : context.colors.background700,
            borderRadius: BorderRadius.circular(4),
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
        TextButton.icon(
          onPressed: _nextPage,
          icon: Icon(Remix.arrow_right_line, size: 18, color: context.colors.primary400),
          label: Text(
            'Suivant',
            style: TextStyle(
              color: context.colors.primary400,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconAlignment: IconAlignment.end,
        ),
      ],
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return Column(
      children: [
        _buildPageIndicator(),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}
