import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

const _red = Color(0xFFE24B4A);
const _redDark = Color(0xFF791F1F);
const _green = Color(0xFF639922);
const _greenDark = Color(0xFF173404);
const _blue = Color(0xFF185FA5);

class UmbrellaPosition {
  final int number;
  final double lat;
  final double lng;
  UmbrellaPosition({required this.number, required this.lat, required this.lng});

  factory UmbrellaPosition.fromJson(Map<String, dynamic> j) => UmbrellaPosition(
        number: (j['number'] as num).toInt(),
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
      );
}

/// Entry point — call this from anywhere an order card knows its umbrella number.
Future<void> showUmbrellaLocatorDialog(BuildContext context, int targetNumber) {
  return showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _UmbrellaLocatorDialog(targetNumber: targetNumber),
  );
}

class _UmbrellaLocatorDialog extends StatefulWidget {
  final int targetNumber;
  const _UmbrellaLocatorDialog({required this.targetNumber});

  @override
  State<_UmbrellaLocatorDialog> createState() => _UmbrellaLocatorDialogState();
}

class _UmbrellaLocatorDialogState extends State<_UmbrellaLocatorDialog>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  List<UmbrellaPosition> _positions = [];
  UmbrellaPosition? _target;

  Position? _waiterPos;
  StreamSubscription<Position>? _posSub;

  // Compass heading in degrees, 0 = true/magnetic north, clockwise.
  // Null if the device has no magnetometer or the stream hasn't fired yet.
  double? _heading;
  StreamSubscription<CompassEvent>? _compassSub;

  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _bootstrap();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _posSub?.cancel();
    _compassSub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final raw = await ApiService.getUmbrellaPositions();
      final positions = raw.map((j) => UmbrellaPosition.fromJson(j)).toList();
      final target = positions
          .where((p) => p.number == widget.targetNumber)
          .cast<UmbrellaPosition?>()
          .firstWhere((p) => p != null, orElse: () => null);

      if (target == null) {
        setState(() {
          _loading = false;
          _error = "This umbrella hasn't been pinned on the map yet.";
        });
        return;
      }

      setState(() {
        _positions = positions;
        _target = target;
        _loading = false;
      });

      await _startLocationStream();
      _startCompassStream();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not load umbrella positions.\n$e';
      });
    }
  }

  Future<void> _startLocationStream() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _error = 'Turn on location services to see your position.');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => _error = 'Location permission is needed to show your position.');
      return;
    }

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2, // meters — avoid redundant repaints
      ),
    ).listen((pos) {
      if (mounted) setState(() => _waiterPos = pos);
    });
  }

  // Compass doesn't need location permission on Android; on iOS it rides
  // along with CLLocationManager under the hood, so we start it after the
  // location permission dance above rather than racing it in initState.
  void _startCompassStream() {
    final events = FlutterCompass.events;
    if (events == null) return; // device has no magnetometer
    _compassSub = events.listen((event) {
      if (event.heading != null && mounted) {
        setState(() => _heading = event.heading);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        width: 380,
        constraints: const BoxConstraints(maxHeight: 620),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(context),
            Expanded(child: _body()),
            if (_target != null) _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.pebble, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                style: Theme.of(context).textTheme.titleMedium,
                children: [
                  const TextSpan(text: 'Find umbrella '),
                  TextSpan(
                    text: '#${widget.targetNumber}',
                    style: const TextStyle(color: _greenDark, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }
    return Container(
      color: const Color(0xFFF7E9C9), // sand tone
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _MapPainter(
              target: _target!,
              others: _positions.where((p) => p.number != widget.targetNumber).toList(),
              waiterLat: _waiterPos?.latitude,
              waiterLng: _waiterPos?.longitude,
              waiterAccuracy: _waiterPos?.accuracy,
              heading: _heading,
              pulse: _pulseCtrl,
              repaint: _pulseCtrl,
            ),
          );
        },
      ),
    );
  }

  Widget _footer() {
    String distText = '—';
    double? bearingToTarget;

    if (_waiterPos != null && _target != null) {
      final meters = Geolocator.distanceBetween(
        _waiterPos!.latitude,
        _waiterPos!.longitude,
        _target!.lat,
        _target!.lng,
      );
      distText = meters >= 1000
          ? '${(meters / 1000).toStringAsFixed(1)}km away'
          : '${meters.round()}m away';

      bearingToTarget = Geolocator.bearingBetween(
        _waiterPos!.latitude,
        _waiterPos!.longitude,
        _target!.lat,
        _target!.lng,
      );
      if (bearingToTarget < 0) bearingToTarget += 360;
    }

    // Angle of the arrow relative to which way the phone is currently
    // facing — this is the "which way do I turn" cue, independent of
    // whether the map itself is oriented to north.
    double? relativeAngle;
    if (bearingToTarget != null && _heading != null) {
      relativeAngle = (bearingToTarget - _heading!) * pi / 180;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.pebble, width: 1)),
      ),
      child: Row(
        children: [
          if (relativeAngle != null)
            Transform.rotate(
              angle: relativeAngle,
              child: const Icon(Icons.navigation_rounded, size: 20, color: _blue),
            )
          else
            const Icon(Icons.directions_walk_rounded,
                size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text(distText, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          if (relativeAngle != null) ...[
            const Spacer(),
            Text(
              'pointing to #${widget.targetNumber}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────
class _MapPainter extends CustomPainter {
  final UmbrellaPosition target;
  final List<UmbrellaPosition> others;
  final double? waiterLat;
  final double? waiterLng;
  final double? waiterAccuracy; // meters, from Position.accuracy
  final double? heading; // degrees, 0 = north, clockwise
  final Animation<double> pulse;

  _MapPainter({
    required this.target,
    required this.others,
    required this.waiterLat,
    required this.waiterLng,
    required this.waiterAccuracy,
    required this.heading,
    required this.pulse,
    required Listenable repaint,
  }) : super(repaint: repaint);

  static const _metersPerDegLat = 111320.0;
  double _metersPerDegLng(double lat) => 111320.0 * cos(lat * pi / 180);

  Offset _project(double lat, double lng) {
    final dy = (lat - target.lat) * _metersPerDegLat;
    final dx = (lng - target.lng) * _metersPerDegLng(target.lat);
    return Offset(dx, -dy); // north = up
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final allOffsets = <Offset>[Offset.zero];
    for (final o in others) {
      allOffsets.add(_project(o.lat, o.lng));
    }
    Offset? waiterOffset;
    if (waiterLat != null && waiterLng != null) {
      waiterOffset = _project(waiterLat!, waiterLng!);
      allOffsets.add(waiterOffset);
    }

    double maxAbs = 10; // meters, floor so a single point doesn't over-zoom
    for (final o in allOffsets) {
      maxAbs = max(maxAbs, max(o.dx.abs(), o.dy.abs()));
    }

    final padding = 50.0;
    final available = (min(size.width, size.height) / 2) - padding;
    double scale = available / maxAbs; // px per meter
    scale = scale.clamp(0.3, 8.0);

    Offset toScreen(Offset meters) => center + Offset(meters.dx * scale, meters.dy * scale);

    // Other umbrellas — red
    for (final o in others) {
      final p = toScreen(_project(o.lat, o.lng));
      _drawDot(canvas, p, 6, _red, Colors.white);
      _drawLabel(canvas, p, '${o.number}', _redDark);
    }

    // Dashed line waiter -> target
    if (waiterOffset != null) {
      final from = toScreen(waiterOffset);
      final to = center;
      _drawDashedLine(canvas, from, to, _blue.withOpacity(0.6));
    }

    // Target — pulsing green
    final t = pulse.value;
    for (final phase in [0.0, 0.5]) {
      final localT = (t + phase) % 1.0;
      final radius = 8 + localT * 22;
      final opacity = (1 - localT) * 0.5;
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = _green.withOpacity(opacity),
      );
    }
    _drawDot(canvas, center, 8, _greenDark, Colors.white);
    _drawLabel(canvas, center, '${target.number}', _greenDark, big: true);

    // Waiter — blue, with heading cone + accuracy ring (Google-Maps style)
    if (waiterOffset != null) {
      final p = toScreen(waiterOffset);
      _drawWaiterMarker(canvas, p, scale);
    }
  }

  void _drawWaiterMarker(Canvas canvas, Offset p, double scale) {
    // Accuracy ring — real radius from GPS accuracy, not a fixed size.
    final accuracyM = waiterAccuracy ?? 15;
    final accuracyPx = (accuracyM * scale).clamp(10.0, 70.0);
    canvas.drawCircle(p, accuracyPx, Paint()..color = _blue.withOpacity(0.12));

    // Facing cone — only drawn once we have a real compass reading.
    if (heading != null) {
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(heading! * pi / 180);

      final conePath = Path()
        ..moveTo(0, 0)
        ..lineTo(-16, -34)
        ..arcToPoint(const Offset(16, -34), radius: const Radius.circular(34))
        ..close();
      canvas.drawPath(conePath, Paint()..color = _blue.withOpacity(0.22));

      canvas.restore();
    }

    canvas.drawCircle(p, 12, Paint()..color = _blue.withOpacity(0.18));
    _drawDot(canvas, p, 7, _blue, Colors.white);
  }

  void _drawDot(Canvas canvas, Offset p, double r, Color fill, Color border) {
    canvas.drawCircle(p, r, Paint()..color = fill);
    canvas.drawCircle(
      p,
      r,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawLabel(Canvas canvas, Offset p, String text, Color color, {bool big = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: big ? 16 : 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, p + Offset(-tp.width / 2, -(tp.height + (big ? 18 : 14))));
  }

  void _drawDashedLine(Canvas canvas, Offset from, Offset to, Color color) {
    const dashLength = 6.0;
    const gapLength = 5.0;
    final total = (to - from).distance;
    if (total == 0) return;
    final direction = (to - from) / total;
    double covered = 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    while (covered < total) {
      final segEnd = min(covered + dashLength, total);
      canvas.drawLine(
        from + direction * covered,
        from + direction * segEnd,
        paint,
      );
      covered = segEnd + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) => true;
}