import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../application/team_provider.dart';
import '../domain/team_info.dart';

Future<void> showTeamSwitcher(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const TeamSwitcherBottomSheet(),
  );
}

class TeamSwitcherBottomSheet extends ConsumerWidget {
  const TeamSwitcherBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTeamsAsync = ref.watch(allTeamsProvider);
    final activeTeam = ref.watch(activeTeamProvider).value;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: context.colors.background900,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: context.colors.background700),
          left: BorderSide(color: context.colors.background700),
          right: BorderSide(color: context.colors.background700),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.background700,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title bar
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.colors.primary500.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Remix.group_line, size: 20, color: context.colors.primary500),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vos groupes',
                          style: TextStyle(
                            color: context.colors.foreground50,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Basculez entre vos groupes ou créez-en un nouveau',
                          style: TextStyle(
                            color: context.colors.foreground400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Remix.close_line),
                    color: context.colors.foreground400,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Teams list
              Flexible(
                child: allTeamsAsync.when(
                  data: (teams) {
                    if (teams.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Aucun groupe configuré',
                            style: TextStyle(color: context.colors.foreground400),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: teams.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final team = teams[index];
                        final isActive = team.id == activeTeam?.id;
                        return _TeamTile(
                          team: team,
                          isActive: isActive,
                          onTap: () async {
                            if (!isActive) {
                              await ref.read(teamInfoProvider.notifier).switchTeam(team.id);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Groupe actif : ${team.name}'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Erreur: $err',
                        style: TextStyle(color: context.colors.danger),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Add team button
              PrimaryButton(
                label: 'Créer un nouveau groupe',
                icon: Remix.add_line,
                onPressed: () {
                  Navigator.of(context).pop();
                  unawaited(context.push('/creer-equipe'));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamTile extends ConsumerWidget {
  const _TeamTile({
    required this.team,
    required this.isActive,
    required this.onTap,
  });

  final TeamInfo team;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(teamCountsProvider(team.id));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive
              ? context.colors.primary500.withValues(alpha: 0.1)
              : context.colors.background800,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? context.colors.primary500.withValues(alpha: 0.6)
                : context.colors.background700,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Shield avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isActive
                    ? context.colors.primary500.withValues(alpha: 0.2)
                    : context.colors.background700,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  team.name.isNotEmpty ? team.name.substring(0, 1).toUpperCase() : 'E',
                  style: TextStyle(
                    color: isActive ? context.colors.primary500 : context.colors.foreground200,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          team.name,
                          style: TextStyle(
                            color: context.colors.foreground50,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.colors.primary500.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Actif',
                            style: TextStyle(
                              color: context.colors.primary400,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        team.format,
                        style: TextStyle(
                          color: context.colors.foreground400,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (team.location != null) ...[
                        Text(
                          ' · ${team.location}',
                          style: TextStyle(
                            color: context.colors.foreground400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      countsAsync.maybeWhen(
                        data: (counts) {
                          final players = counts['players'] ?? 0;
                          final sessions = counts['sessions'] ?? 0;
                          return Text(
                            ' · $players j. / $sessions s.',
                            style: TextStyle(
                              color: context.colors.foreground400,
                              fontSize: 12,
                            ),
                          );
                        },
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Icon indicator
            if (isActive)
              Icon(Remix.check_line, color: context.colors.primary500, size: 20)
            else
              Icon(Remix.arrow_right_s_line, color: context.colors.foreground600, size: 18),
          ],
        ),
      ),
    );
  }
}
