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
            child: Text('10 au total', style: TextStyle(color: context.colors.foreground400, fontSize: 14)),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFilters(context),
          const SizedBox(height: 24),
          Text('SEPTEMBRE 2026', style: TextStyle(color: context.colors.foreground400, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildSessionCard(context, 'jeu. 10 sept. · 20h30', true, true, 4, 3),
          _buildSessionCard(context, 'mar. 8 sept. · 20h30', false, false, 7, 2),
          _buildSessionCard(context, 'mar. 1 sept. · 20h30', false, false, 7, 4),
          const SizedBox(height: 24),
          Text('AOÛT 2026', style: TextStyle(color: context.colors.foreground400, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildSessionCard(context, 'mar. 25 août. · 20h30', false, false, 4, 1),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/seances/nouvelle'),
        backgroundColor: context.colors.primary500,
        foregroundColor: context.colors.background950,
        child: const Icon(Remix.add_line),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip(context, 'Toutes', true),
          const SizedBox(width: 8),
          _buildChip(context, 'Classées', false),
          const SizedBox(width: 8),
          _buildChip(context, 'Amicales', false),
          const SizedBox(width: 8),
          _buildChip(context, 'Brouillons', false),
        ],
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? context.colors.primary500.withOpacity(0.1) : context.colors.background800,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(
          color: isActive ? context.colors.primary500 : Colors.transparent,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? context.colors.primary500 : context.colors.foreground300,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildSessionCard(BuildContext context, String datetime, bool isDraft, bool hasWarning, int scoreA, int scoreB) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/seances/s9'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.background900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.background700),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(datetime, style: TextStyle(color: context.colors.foreground400)),
                  const SizedBox(width: 8),
                  if (isDraft)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: context.colors.foreground600),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text('BROUILLON', style: TextStyle(color: context.colors.foreground400, fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                  else
                    const StatusBadge(status: BadgeStatus.closed),
                  const Spacer(),
                  if (hasWarning)
                    Row(
                      children: [
                        Icon(Remix.error_warning_line, color: context.colors.warning, size: 14),
                        const SizedBox(width: 4),
                        Text('Buts', style: TextStyle(color: context.colors.warning, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildTeamDot(context, context.colors.accent500, 'A'),
                  const SizedBox(width: 12),
                  Text('$scoreA', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('-', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: context.colors.foreground600)),
                  ),
                  Text('$scoreB', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  _buildTeamDot(context, context.colors.secondary500, 'B'),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: context.colors.background800, borderRadius: BorderRadius.circular(9999)),
                    child: const Text('5v5', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Text('10 joueurs', style: TextStyle(color: context.colors.foreground400, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamDot(BuildContext context, Color color, String label) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(label, style: TextStyle(color: context.colors.foreground50, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
