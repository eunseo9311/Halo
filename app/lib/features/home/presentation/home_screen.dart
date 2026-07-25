import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/features/incidents/presentation/incident_providers.dart';
import 'package:halo/features/route_map/domain/map_geometry.dart';
import 'package:halo/features/route_map/presentation/platform_map/platform_route_map.dart';
import 'package:halo/features/route_map/presentation/route_map_screen.dart';
import 'package:url_launcher/url_launcher.dart';

typedef HomeMapBuilder =
    Widget Function({
      required MapCoordinate center,
      required MapGeometry geometry,
      required bool showUserLocation,
      required int northResetGeneration,
      required MapMarkerTapCallback onMarkerTap,
    });
typedef SosLauncher = Future<bool> Function(Uri uri);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    this.mapBuilder,
    this.onSearch,
    this.onDirections,
    this.sosLauncher,
    super.key,
  });

  final HomeMapBuilder? mapBuilder;
  final VoidCallback? onSearch;
  final VoidCallback? onDirections;
  final SosLauncher? sosLauncher;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  var _northResetGeneration = 0;

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(mapLocationProvider);
    final incidentsAsync = ref.watch(displayedIncidentsProvider);
    final incidents = incidentsAsync.valueOrNull ?? const <DisplayedIncident>[];
    final location = locationAsync.valueOrNull;
    final center = location?.center ?? defaultMapCenter;
    final mapBuilder = widget.mapBuilder ?? _buildMap;
    final geometry = MapGeometry(
      polylines: const [],
      markers: [
        for (final incident in incidents)
          MapMarker(
            id: incident.markerId,
            position: MapCoordinate(incident.latitude, incident.longitude),
            kind: MapMarkerKind.incident,
            label: incident.incident.emoji,
          ),
      ],
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          mapBuilder(
            center: MapCoordinate(center.latitude, center.longitude),
            geometry: geometry,
            showUserLocation: location?.hasLocationFix ?? false,
            northResetGeneration: _northResetGeneration,
            onMarkerTap: (marker) {
              if (marker.kind != MapMarkerKind.incident) return;
              for (final incident in incidents) {
                if (incident.markerId == marker.id) {
                  _showIncidentDetails(incident);
                  return;
                }
              }
            },
          ),
          SafeArea(
            minimum: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: _SearchBar(onTap: widget.onSearch),
                ),
                Positioned(
                  right: 0,
                  top: 72,
                  child: Column(
                    children: [
                      SosButton(
                        location: location,
                        launcher: widget.sosLauncher ?? launchUrl,
                      ),
                      const SizedBox(height: 12),
                      _CircleActionButton(
                        key: const Key('north-reset-button'),
                        size: 48,
                        tooltip: 'Reset map to north',
                        icon: Icons.navigation_outlined,
                        foregroundColor: const Color(0xFFEA4335),
                        onPressed: () =>
                            setState(() => _northResetGeneration += 1),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _CircleActionButton(
                      key: const Key('directions-button'),
                      size: 72,
                      color: const Color(0xFF0F7C66),
                      foregroundColor: Colors.white,
                      tooltip: 'Directions',
                      icon: Icons.directions,
                      iconSize: 34,
                      onPressed: widget.onDirections,
                    ),
                  ),
                ),
                if (locationAsync.hasValue &&
                    !(location?.hasLocationFix ?? false))
                  const Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 108),
                      child: _FallbackBanner(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showIncidentDetails(DisplayedIncident incident) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => _IncidentDetails(incident: incident),
      );
}

Widget _buildMap({
  required MapCoordinate center,
  required MapGeometry geometry,
  required bool showUserLocation,
  required int northResetGeneration,
  required MapMarkerTapCallback onMarkerTap,
}) => PlatformRouteMap(
  center: center,
  geometry: geometry,
  showUserLocation: showUserLocation,
  recenterGeneration: 0,
  northResetGeneration: northResetGeneration,
  onMarkerTap: onMarkerTap,
);

class _IncidentDetails extends StatelessWidget {
  const _IncidentDetails({required this.incident});

  final DisplayedIncident incident;

  @override
  Widget build(BuildContext context) {
    final report = incident.incident;
    final localTime = report.occurredAt.toLocal();
    final minute = localTime.minute.toString().padLeft(2, '0');
    final dateTime =
        '${localTime.month}/${localTime.day}/${localTime.year} '
        '${localTime.hour}:$minute';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          key: const Key('incident-detail-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${report.emoji}  ${report.title}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(report.description),
            const SizedBox(height: 16),
            Text('When: $dateTime'),
            const SizedBox(height: 6),
            Text('Location: ${report.locationType} · ${report.areaName}'),
            if (incident.isDemoLocation) ...[
              const SizedBox(height: 10),
              const Text(
                'Sample data',
                style: TextStyle(color: Color(0xFF6B7472), fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE7ECEA)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x24172B2B),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: const Key('home-search-button'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: const SizedBox(
          height: 56,
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Icon(Icons.search, color: Color(0xFF465552)),
                SizedBox(width: 12),
                Text(
                  'Where to?',
                  style: TextStyle(
                    color: Color(0xFF465552),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class SosButton extends StatefulWidget {
  const SosButton({required this.location, required this.launcher, super.key});

  final MapLocationState? location;
  final SosLauncher launcher;

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  Timer? _activationTimer;
  var _activated = false;
  var _isLaunching = false;
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  void _startPress(TapDownDetails _) {
    _activationTimer?.cancel();
    _activated = false;
    _progress.forward(from: 0);
    _activationTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      _activated = true;
      _progress.stop();
      _showServiceDialog();
    });
  }

  void _endPress(TapUpDetails _) {
    _activationTimer?.cancel();
    _progress.reset();
    if (!_activated) _showShortPressMessage();
  }

  void _cancelPress() {
    _activationTimer?.cancel();
    _progress.reset();
  }

  void _showShortPressMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Press and hold for 2 seconds to activate SOS.'),
        ),
      );
  }

  Future<void> _showServiceDialog() async {
    final location = widget.location;
    final locationText = location?.hasLocationFix ?? false
        ? '${location!.center.latitude.toStringAsFixed(5)}, '
              '${location.center.longitude.toStringAsFixed(5)}'
        : 'Location unavailable';
    final number = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose emergency service'),
        content: Text('Current location: $locationText'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, '119'),
            child: const Text('Fire & Rescue (119)'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, '112'),
            child: const Text('Police (112)'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (!mounted || number == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm emergency call'),
        content: Text('Call $number now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Call'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _launchEmergencyCall(number);
    }
  }

  Future<void> _launchEmergencyCall(String number) async {
    if (_isLaunching) return;
    _isLaunching = true;
    var launched = false;
    try {
      launched = await widget.launcher(Uri(scheme: 'tel', path: number));
    } catch (_) {
      launched = false;
    } finally {
      _isLaunching = false;
    }
    if (!mounted || launched) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Unable to open the Phone app. Call emergency services manually.',
          ),
        ),
      );
  }

  @override
  void dispose() {
    _activationTimer?.cancel();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'SOS emergency',
    child: GestureDetector(
      key: const Key('sos-button'),
      behavior: HitTestBehavior.opaque,
      onTapDown: _startPress,
      onTapUp: _endPress,
      onTapCancel: _cancelPress,
      child: SizedBox.square(
        dimension: 64,
        child: AnimatedBuilder(
          animation: _progress,
          builder: (context, child) => Stack(
            fit: StackFit.expand,
            children: [
              const Material(
                elevation: 4,
                color: Color(0xFFD92D20),
                shape: CircleBorder(),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.emergency_share_outlined,
                        color: Colors.white,
                        size: 23,
                      ),
                      Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_progress.value > 0)
                CircularProgressIndicator(
                  value: _progress.value,
                  strokeWidth: 4,
                  color: Colors.white,
                  backgroundColor: Colors.white30,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.size,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color = Colors.white,
    this.foregroundColor = const Color(0xFF3C4043),
    this.iconSize = 24,
    super.key,
  });

  final double size;
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final Color foregroundColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 4,
    color: color,
    shape: const CircleBorder(),
    child: IconButton(
      constraints: BoxConstraints.tightFor(width: size, height: size),
      padding: EdgeInsets.zero,
      tooltip: tooltip,
      onPressed: onPressed,
      color: foregroundColor,
      iconSize: iconSize,
      icon: Icon(icon),
    ),
  );
}

class _FallbackBanner extends StatelessWidget {
  const _FallbackBanner();

  @override
  Widget build(BuildContext context) => Material(
    elevation: 2,
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text('Location unavailable — showing Los Angeles.'),
    ),
  );
}
