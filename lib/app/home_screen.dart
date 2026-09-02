import 'package:catear/exercicios/exercicios.dart';
import 'package:flutter/material.dart';

/// Home tab. Carries the "Praticar" CTA into the interval exercise (Story 1.4).
/// Story 1.7 swaps the destination for the sized session.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Que bom ter você no CatEar!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const IntervalExerciseScreen(),
                  ),
                ),
                child: const Text('Praticar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
