import 'package:flutter/material.dart';
import '../models/tenant.dart';

class SummaryChips extends StatelessWidget {
  final MonthSummary summary;

  const SummaryChips({super.key, required this.summary});

  Widget _chip(String label, int v, Color c) => Expanded(
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '₹$v',
              style: TextStyle(
                color: c,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );

  Widget _div() => Container(width: 1, height: 24, color: Colors.grey.shade200);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            _chip('Expected', summary.expected, const Color(0xFF2563EB)),
            _div(),
            _chip('Collected', summary.collected, const Color(0xFF15803D)),
            _div(),
            _chip('Expenses', summary.expenses, const Color(0xFFDC2626)),
            _div(),
            _chip(
              'Net Profit',
              summary.net,
              summary.net >= 0 ? const Color(0xFF1E3A8A) : Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}
