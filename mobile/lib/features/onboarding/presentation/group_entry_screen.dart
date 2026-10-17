import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../application/onboarding_provider.dart';

class GroupEntryScreen extends ConsumerWidget {
  const GroupEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    backgroundColor: context.colors.background950,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Icon(Remix.team_line, color: context.colors.primary500, size: 56),
              const SizedBox(height: 24),
              Text(
                'Bienvenue sur Statoo',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Votre groupe. Votre terrain.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Vous démarrez un nouveau groupe ?'),
                    const SizedBox(height: 12),
                    const Text(
                      'Nommez votre groupe, ajoutez vos joueurs, créez votre accès Admin puis désignez les responsables.',
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Créer un groupe',
                      icon: Remix.add_line,
                      onPressed: () => context.push(
                        ref.read(hasSeenOnboardingProvider)
                            ? '/creer-equipe?partage=1'
                            : '/onboarding?partage=1',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Vous avez reçu des identifiants ?'),
                    const SizedBox(height: 12),
                    const Text(
                      'Rejoignez votre groupe avec votre accès personnel ou l’accès collectif des membres.',
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: () =>
                          context.push('/groupe-partage?installation=1'),
                      child: const Text(
                        'Rejoindre un groupe',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
