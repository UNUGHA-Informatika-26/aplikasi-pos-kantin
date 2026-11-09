import 'package:flutter/material.dart';
import '../theme.dart';

class StatCard extends StatelessWidget {
  const StatCard(this.title, this.value, this.icon, {super.key});
  final String title, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 165,
      child: Card(
          child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: green),
                    const SizedBox(height: 10),
                    Text(value,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text(title, style: Theme.of(context).textTheme.bodySmall)
                  ]))));
}
