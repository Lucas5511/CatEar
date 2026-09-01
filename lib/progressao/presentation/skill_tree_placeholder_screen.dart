import 'package:flutter/material.dart';

/// Placeholder for the Skill Tree tab. The Skill Tree belongs to Progressão
/// (AR-3); the real screen arrives in Epic 2.
class SkillTreePlaceholderScreen extends StatelessWidget {
  const SkillTreePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'A trilha de habilidades chega em breve.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
