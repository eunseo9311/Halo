import 'package:flutter/material.dart';
import 'package:halo/features/search/domain/recent_search.dart';

class RouteSelectionPlaceholderScreen extends StatelessWidget {
  const RouteSelectionPlaceholderScreen({required this.destination, super.key});

  final RecentSearch destination;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Route selection')),
    body: Center(
      child: Text(
        'Route selection for ${destination.title} is coming soon.',
        textAlign: TextAlign.center,
      ),
    ),
  );
}
