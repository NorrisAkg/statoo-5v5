import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class Stepper3 extends StatelessWidget {
  const Stepper3({
    required this.currentStep,
    super.key,
  });

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStep(context, 1, currentStep >= 1),
        _buildLine(context, currentStep >= 2),
        _buildStep(context, 2, currentStep >= 2),
        _buildLine(context, currentStep >= 3),
        _buildStep(context, 3, currentStep >= 3),
      ],
    );
  }

  Widget _buildStep(BuildContext context, int step, bool isActive) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActive ? context.colors.primary500 : context.colors.background700,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$step',
        style: TextStyle(
          color: isActive ? Theme.of(context).colorScheme.onPrimary : context.colors.foreground400,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLine(BuildContext context, bool isActive) {
    return Container(
      width: 32,
      height: 2,
      color: isActive ? context.colors.primary500 : context.colors.background700,
    );
  }
}
