import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/stepper3.dart';

class NewSessionScreen extends StatefulWidget {
  const NewSessionScreen({super.key});

  @override
  State<NewSessionScreen> createState() => _NewSessionScreenState();
}

class _NewSessionScreenState extends State<NewSessionScreen> {
  int _currentStep = 1;

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      context.go('/seances/s9'); // Retour au détail après création (mock)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Remix.arrow_left_line),
          onPressed: () => context.pop(),
        ),
        title: const Text('Nouvelle séance'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Stepper3(currentStep: _currentStep),
          const SizedBox(height: 32),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (_currentStep == 1) _buildStep1(),
                if (_currentStep == 2) _buildStep2(),
                if (_currentStep == 3) _buildStep3(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: PrimaryButton(
              label: _currentStep == 3 ? 'Enregistrer la séance' : 'Continuer',
              onPressed: _nextStep,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quand joue-t-on ?',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'On pré-remplit à maintenant. Ajuste si besoin.',
          style: TextStyle(color: AppColors.foreground400),
        ),
        const SizedBox(height: 24),
        AppCard(
          child: Column(
            children: [
              _buildInputField('Date', '24/09/2026', Remix.calendar_line),
              const SizedBox(height: 16),
              _buildInputField('Heure', '17:38', Remix.time_line),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.foreground50,
                    side: const BorderSide(color: AppColors.background700),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                  ),
                  child: const Text('Maintenant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary500.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Text(
              'jeu. 24 sept. 2026 · 17h38',
              style: TextStyle(color: AppColors.primary500, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField(String label, String value, IconData icon) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.background800,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.background700),
          ),
          child: Row(
            children: [
              Text(value, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 32),
              Icon(icon, color: AppColors.foreground500, size: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Composition', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Sélectionnez les présents et répartissez les équipes.', style: TextStyle(color: AppColors.foreground400)),
        const SizedBox(height: 24),
        const AppCard(
          child: Center(
            child: Text('Placeholder Étape 2\n(Liste des joueurs et brouillon RandomSplitter)', textAlign: TextAlign.center, style: TextStyle(color: AppColors.foreground400)),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Résultat', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Saisissez le score final et les statistiques individuelles.', style: TextStyle(color: AppColors.foreground400)),
        const SizedBox(height: 24),
        const AppCard(
          child: Center(
            child: Text('Placeholder Étape 3\n(Score et Stats)', textAlign: TextAlign.center, style: TextStyle(color: AppColors.foreground400)),
          ),
        ),
      ],
    );
  }
}
