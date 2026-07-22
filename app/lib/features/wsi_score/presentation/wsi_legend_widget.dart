import 'package:flutter/material.dart';
import 'package:halo/features/route_map/domain/map_geometry.dart';

/// Color legend for WSI score bands.
/// Shows in the map corner to explain what red/yellow/green means.
class WsiLegendWidget extends StatelessWidget {
  const WsiLegendWidget({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(8),
      boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Environment Score',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        SizedBox(height: 4),
        _LegendRow(color: Color(greenWsiColor), label: 'High  (≥0.7)'),
        _LegendRow(color: Color(yellowWsiColor), label: 'Mid   (0.4–0.7)'),
        _LegendRow(color: Color(redWsiColor), label: 'Low   (<0.4)'),
      ],
    ),
  );
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 20, height: wsiStrokeWidth, color: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );
}
