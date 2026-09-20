import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:volume_controller/volume_controller.dart';

void main() {
  runApp(const FingerChooserApp());
}

class FingerChooserApp extends StatelessWidget {
  const FingerChooserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Finger Chooser',
      theme: ThemeData.dark(),
      home: const ChooserScreen(),
    );
  }
}

/// One active finger on the screen.
class _Touch {
  final int id;
  Offset position;
  final Color color;
  final DateTime placedAt;

  _Touch({
    required this.id,
    required this.position,
    required this.color,
    required this.placedAt,
  });
}

class ChooserScreen extends StatefulWidget {
  const ChooserScreen({super.key});

  @override
  State<ChooserScreen> createState() => _ChooserScreenState();
}

class _ChooserScreenState extends State<ChooserScreen>
    with SingleTickerProviderStateMixin {
  // Neon palette the circles cycle through as fingers are placed.
  static const List<Color> _neonColors = [
    Color(0xFFFF00FF), // magenta
    Color(0xFF00FFFF), // cyan
    Color(0xFF39FF14), // neon green
    Color(0xFFFFFF00), // neon yellow
    Color(0xFFFF073A), // neon red
    Color(0xFF9D00FF), // neon purple
    Color(0xFFFF9900), // neon orange
    Color(0xFF00FF87), // neon mint
  ];

  final Map<int, _Touch> _touches = {};
  int _colorCursor = 0;

  Timer? _countdownTimer;
  int _countdownValue = 0;
  static const int _countdownSeconds = 3;

  int? _winnerId;
  bool _locked = false; // true once a winner has been picked, until fingers lift

  // How "off" the volume needs to be to count as the secret trigger.
  static const double _volumeTriggerThreshold = 0.02;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Color _nextColor() {
    final c = _neonColors[_colorCursor % _neonColors.length];
    _colorCursor++;
    return c;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_locked) return; // ignore new fingers once a winner is being shown

    setState(() {
      _touches[event.pointer] = _Touch(
        id: event.pointer,
        position: event.localPosition,
        color: _nextColor(),
        placedAt: DateTime.now(),
      );
    });

    // (Re)start the countdown every time a new finger joins, so players
    // get a fair window to place all fingers before the pick happens.
    _startOrResetCountdown();
  }

  void _onPointerMove(PointerMoveEvent event) {
    final touch = _touches[event.pointer];
    if (touch == null || _locked) return;
    setState(() {
      touch.position = event.localPosition;
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    _handlePointerGone(event.pointer);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _handlePointerGone(event.pointer);
  }

  void _handlePointerGone(int pointerId) {
    setState(() {
      _touches.remove(pointerId);
    });

    if (_touches.isEmpty) {
      // Everyone lifted their finger -> full reset, whether or not
      // a winner had already been revealed.
      _countdownTimer?.cancel();
      setState(() {
        _countdownValue = 0;
        _winnerId = null;
        _locked = false;
        _colorCursor = 0;
      });
    } else if (!_locked && _touches.length < 2) {
      // Not enough fingers left to run a fair pick yet; cancel countdown
      // until a second finger comes back down.
      _countdownTimer?.cancel();
      setState(() => _countdownValue = 0);
    }
  }

  void _startOrResetCountdown() {
    if (_locked) return;
    if (_touches.length < 2) return; // need at least 2 fingers to choose between

    _countdownTimer?.cancel();
    setState(() => _countdownValue = _countdownSeconds);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _countdownValue--);
      if (_countdownValue <= 0) {
        timer.cancel();
        _pickWinner();
      }
    });
  }

  Future<double> _readVolume() async {
    try {
      return await VolumeController().getVolume();
    } catch (_) {
      return 1.0; // if we can't read it, don't accidentally trigger the rig
    }
  }

  Future<void> _pickWinner() async {
    if (_touches.isEmpty) return;

    final volume = await _readVolume();

    final bool rigged = volume <= _volumeTriggerThreshold;

    int winnerId;
    if (rigged) {
      // Pick whichever finger was placed most recently.
      final sorted = _touches.values.toList()
        ..sort((a, b) => a.placedAt.compareTo(b.placedAt));
      winnerId = sorted.last.id;
    } else {
      final ids = _touches.keys.toList();
      winnerId = ids[Random().nextInt(ids.length)];
    }

    if (!mounted) return;
    setState(() {
      _winnerId = winnerId;
      _locked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Hint text, only shown before anyone has touched the screen.
            if (_touches.isEmpty)
              const Center(
                child: Text(
                  'Everyone place a finger\non the screen',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white24, fontSize: 20),
                ),
              ),

            // Countdown number while the pick is pending.
            if (_countdownValue > 0 && !_locked)
              Center(
                child: Text(
                  '$_countdownValue',
                  style: const TextStyle(
                    color: Colors.white24,
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            // One neon circle per active finger.
            ..._touches.values.map((t) => _buildCircle(t)),
          ],
        ),
      ),
    );
  }

  Widget _buildCircle(_Touch touch) {
    final bool isWinner = _locked && touch.id == _winnerId;
    final bool isLoser = _locked && touch.id != _winnerId;

    final double baseSize = 90;
    final double size = isWinner ? baseSize * 1.6 : baseSize;
    final double opacity = isLoser ? 0.15 : 1.0;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      left: touch.position.dx - size / 2,
      top: touch.position.dy - size / 2,
      width: size,
      height: size,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: opacity,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: touch.color.withOpacity(0.25),
            border: Border.all(color: touch.color, width: 4),
            boxShadow: [
              BoxShadow(
                color: touch.color.withOpacity(isWinner ? 0.9 : 0.6),
                blurRadius: isWinner ? 40 : 20,
                spreadRadius: isWinner ? 10 : 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
