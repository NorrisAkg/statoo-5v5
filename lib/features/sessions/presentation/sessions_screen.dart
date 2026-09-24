import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/status_badge.dart';

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Séances'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Text('10 au total', style: TextStyle(color: AppColors.foreground400, fontSize: 14)),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFilters(),
          const SizedBox(height: 24),
          const Text('SEPTEMBRE 2026', style: TextStyle(color: AppColors.foreground400, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildSessionCard(context, 'jeu. 10 sept. · 20h30', true, true, 4, 3),
          _buildSessionCard(context, 'mar. 8 sept. · 20h30', false, false, 7, 2),
          _buildSessionCard(context, 'mar. 1 sept. · 20h30', false, false, 7, 4),
          const SizedBox(height: 24),
          const Text('AOÛT 2026', style: TextStyle(color: AppColors.foreground400, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildSessionCard(context, 'mar. 25 août. · 20h30', false, false, 4, 1),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/seances/nouvelle'),
        backgroundColor: AppColors.primary500,
        foregroundColor: AppColors.background950,
        child: const Icon(Remix.add_line),
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip('Toutes', true),
          const SizedBox(width: 8),
          _buildChip('Classées', false),
          const SizedBox(width: 8),
          _buildChip('Amicales', false),
          const SizedBox(width: 8),
          _buildChip('Brouillons', false),
        ],
      ),
    );
  }

  Widget _buildChip(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary500.withOpacity(0.1) : AppColors.background800,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(
          color: isActive ? AppColors.primary500 : Colors.transparent,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? AppColors.primary500 : AppColors.foreground300,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildSessionCard(BuildContext context, String datetime, bool isDraft, bool hasWarning, int scoreA, int scoreB) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.go('/seances/s9'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.background700),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(datetime, style: const TextStyle(color: AppColors.foreground400)),
                  const SizedBox(width: 8),
                  if (isDraft)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.foreground600),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: const Text('BROUILLON', style: TextStyle(color: AppColors.foreground400, fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                  else
                    const StatusBadge(status: BadgeStatus.closed),
                  const Spacer(),
                  if (hasWarning)
                    const Row(
                      children: [
                        Icon(Remix.error_warning_line, color: AppColors.warning, size: 14),
                        SizedBox(width: 4),
                        Text('Buts', style: TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildTeamDot(AppColors.accent500, 'A'),
                  const SizedBox(width: 12),
                  Text('$scoreA', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('-', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.foreground600)),
                  ),
                  Text('$scoreB', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  _buildTeamDot(AppColors.secondary500, 'B'),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.background800, borderRadius: BorderRadius.circular(9999)),
                    child: const Text('5v5', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  const Text('10 joueurs', style: TextStyle(color: AppColors.foreground400, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamDot(Color color, String label) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(label, style: const TextStyle(color: AppColors.foreground50, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
