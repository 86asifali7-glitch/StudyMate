import 'dart:async';
import 'package:flutter/material.dart';
import '../services/sound_service.dart';

// ─── Design tokens matching StudyMate ─────────────────────────────────────────
const _kBg = Color(0xFFFFFFFF);
const _kPrimary = Color(0xFF2563EB);
const _kPrimaryLight = Color(0xFFEFF6FF);
const _kCard = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE2E8F0);
const _kTextHead = Color(0xFF1E293B);
const _kTextBody = Color(0xFF64748B);
const _kAmberTag = Color(0xFFF59E0B);
const _kGreenTag = Color(0xFF10B981);
const _kRedTag = Color(0xFFEF4444);

class ClockScreen extends StatefulWidget {
  final int initialTabIndex;
  const ClockScreen({super.key, this.initialTabIndex = 0});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    // Only play ticking in stopwatch tab (index 1)
    if (_tabController.index != 1) {
      SoundService.instance.stopStopwatchTicking();
    }
  }

  @override
  void dispose() {
    SoundService.instance.stopStopwatchTicking();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  const DigitalClockTab(),
                  StopwatchTab(tabController: _tabController),
                  const CountdownTimerTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorder, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: _kTextHead,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clock',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kTextHead,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Time, stopwatch & countdown timer',
                  style: TextStyle(
                    fontSize: 12,
                    color: _kTextBody,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // Clock tool badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kPrimaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule_rounded, size: 14, color: _kPrimary),
                SizedBox(width: 4),
                Text(
                  'Tool',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: _kPrimary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _kPrimary.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: _kTextBody,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(
            icon: Icon(Icons.access_time_rounded, size: 18),
            text: 'Digital Clock',
          ),
          Tab(
            icon: Icon(Icons.timer_outlined, size: 18),
            text: 'Stopwatch',
          ),
          Tab(
            icon: Icon(Icons.hourglass_bottom_rounded, size: 18),
            text: 'Countdown Timer',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1: DIGITAL CLOCK
// ─────────────────────────────────────────────────────────────────────────────

class DigitalClockTab extends StatefulWidget {
  const DigitalClockTab({super.key});

  @override
  State<DigitalClockTab> createState() => _DigitalClockTabState();
}

class _DigitalClockTabState extends State<DigitalClockTab>
    with AutomaticKeepAliveClientMixin {
  late DateTime _currentTime;
  Timer? _liveClockTimer;
  bool _is24HourFormat = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    // Update live clock every second
    _liveClockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _liveClockTimer?.cancel();
    _liveClockTimer = null;
    super.dispose();
  }

  String _formatTime() {
    final hour = _currentTime.hour;
    final minute = _currentTime.minute.toString().padLeft(2, '0');
    final second = _currentTime.second.toString().padLeft(2, '0');

    if (_is24HourFormat) {
      final h = hour.toString().padLeft(2, '0');
      return '$h:$minute:$second';
    } else {
      final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$h:$minute:$second';
    }
  }

  String _formatDate() {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    final dayName = days[_currentTime.weekday - 1];
    final monthName = months[_currentTime.month - 1];
    return '$dayName, $monthName ${_currentTime.day}, ${_currentTime.year}';
  }

  String _timeZoneOffset() {
    final offset = _currentTime.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return 'GMT$sign$hours:$minutes (${_currentTime.timeZoneName})';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final period = _currentTime.hour < 12 ? 'AM' : 'PM';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          // Main Clock Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Live status tag
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: _kPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Live Device Time',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _kPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Time digits
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _formatTime(),
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          color: _kTextHead,
                          letterSpacing: -1.0,
                          fontFeatures: [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      if (!_is24HourFormat) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _kPrimary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            period,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _kPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Formatted Date
                Text(
                  _formatDate(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _kTextBody,
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                const SizedBox(height: 16),
                // 12h / 24h format switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Time Format',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kTextHead,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: _kBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Row(
                        children: [
                          _FormatToggleBtn(
                            label: '12h',
                            isSelected: !_is24HourFormat,
                            onTap: () {
                              if (_is24HourFormat) {
                                setState(() => _is24HourFormat = false);
                              }
                            },
                          ),
                          _FormatToggleBtn(
                            label: '24h',
                            isSelected: _is24HourFormat,
                            onTap: () {
                              if (!_is24HourFormat) {
                                setState(() => _is24HourFormat = true);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Timezone / Details Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.public_rounded,
                    color: _kPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Time Zone',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _kTextBody,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _timeZoneOffset(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _kTextHead,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatToggleBtn extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatToggleBtn({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? _kPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : _kTextBody,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2: STOPWATCH
// ─────────────────────────────────────────────────────────────────────────────

class _LapData {
  final int index;
  final Duration lapTime;
  final Duration totalTime;

  const _LapData({
    required this.index,
    required this.lapTime,
    required this.totalTime,
  });
}

class StopwatchTab extends StatefulWidget {
  final TabController? tabController;

  const StopwatchTab({super.key, this.tabController});

  @override
  State<StopwatchTab> createState() => _StopwatchTabState();
}

class _StopwatchTabState extends State<StopwatchTab>
    with AutomaticKeepAliveClientMixin {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  final List<_LapData> _laps = [];
  Duration _previousLapsDuration = Duration.zero;
  bool _tickingSoundEnabled = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.tabController?.addListener(_onTabControllerChanged);
  }

  void _onTabControllerChanged() {
    if (widget.tabController == null) return;
    if (widget.tabController!.index == 1) {
      if (_stopwatch.isRunning && _tickingSoundEnabled) {
        SoundService.instance.startStopwatchTicking();
      }
    } else {
      SoundService.instance.stopStopwatchTicking();
    }
  }

  @override
  void didUpdateWidget(covariant StopwatchTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabController != widget.tabController) {
      oldWidget.tabController?.removeListener(_onTabControllerChanged);
      widget.tabController?.addListener(_onTabControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.tabController?.removeListener(_onTabControllerChanged);
    _ticker?.cancel();
    _ticker = null;
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
    }
    SoundService.instance.stopStopwatchTicking();
    super.dispose();
  }

  void _start() {
    _stopwatch.start();
    _ticker = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (mounted) setState(() {});
    });
    if (_tickingSoundEnabled) {
      SoundService.instance.startStopwatchTicking();
    }
    setState(() {});
  }

  void _pause() {
    _stopwatch.stop();
    _ticker?.cancel();
    _ticker = null;
    SoundService.instance.stopStopwatchTicking();
    setState(() {});
  }

  void _reset() {
    _stopwatch.reset();
    _ticker?.cancel();
    _ticker = null;
    _laps.clear();
    _previousLapsDuration = Duration.zero;
    SoundService.instance.stopStopwatchTicking();
    setState(() {});
  }

  void _toggleTickingSound() {
    setState(() {
      _tickingSoundEnabled = !_tickingSoundEnabled;
      if (_stopwatch.isRunning) {
        if (_tickingSoundEnabled) {
          SoundService.instance.startStopwatchTicking();
        } else {
          SoundService.instance.stopStopwatchTicking();
        }
      }
    });
  }

  void _recordLap() {
    final currentElapsed = _stopwatch.elapsed;
    final lapTime = currentElapsed - _previousLapsDuration;
    _previousLapsDuration = currentElapsed;

    setState(() {
      _laps.insert(
        0,
        _LapData(
          index: _laps.length + 1,
          lapTime: lapTime,
          totalTime: currentElapsed,
        ),
      );
    });
  }

  String _formatStopwatch(Duration d) {
    final hours = d.inHours;
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    final hundredths =
        ((d.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');

    if (hours > 0) {
      final h = hours.toString().padLeft(2, '0');
      return '$h:$minutes:$seconds.$hundredths';
    }
    return '$minutes:$seconds.$hundredths';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isRunning = _stopwatch.isRunning;
    final elapsed = _stopwatch.elapsed;
    final canReset = !isRunning && elapsed > Duration.zero;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Display Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: (isRunning ? _kGreenTag : _kPrimary)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isRunning ? _kGreenTag : _kPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isRunning
                                ? 'Running'
                                : (elapsed > Duration.zero ? 'Paused' : 'Ready'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isRunning ? _kGreenTag : _kPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Tooltip(
                      message: _tickingSoundEnabled
                          ? 'Mute ticking sound'
                          : 'Enable ticking sound',
                      child: InkWell(
                        onTap: _toggleTickingSound,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: (_tickingSoundEnabled ? _kPrimary : _kTextBody)
                                .withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _tickingSoundEnabled
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_off_rounded,
                                size: 13,
                                color: _tickingSoundEnabled
                                    ? _kPrimary
                                    : _kTextBody,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _tickingSoundEnabled ? 'Tick SFX' : 'Muted',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _tickingSoundEnabled
                                      ? _kPrimary
                                      : _kTextBody,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formatStopwatch(elapsed),
                    style: const TextStyle(
                      fontSize: 54,
                      fontWeight: FontWeight.w800,
                      color: _kTextHead,
                      letterSpacing: -1.0,
                      fontFeatures: [
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Action Buttons Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Lap or Reset button
                    if (isRunning) ...[
                      _StopwatchBtn(
                        label: 'Lap',
                        icon: Icons.flag_rounded,
                        bgColor: _kBg,
                        textColor: _kPrimary,
                        onTap: _recordLap,
                      ),
                      const SizedBox(width: 14),
                    ] else if (canReset) ...[
                      _StopwatchBtn(
                        label: 'Reset',
                        icon: Icons.replay_rounded,
                        bgColor: _kRedTag.withValues(alpha: 0.10),
                        textColor: _kRedTag,
                        onTap: _reset,
                      ),
                      const SizedBox(width: 14),
                    ],
                    // Start or Pause button
                    _StopwatchBtn(
                      label: isRunning
                          ? 'Pause'
                          : (elapsed > Duration.zero ? 'Resume' : 'Start'),
                      icon: isRunning
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      bgColor: isRunning ? _kAmberTag : _kPrimary,
                      textColor: Colors.white,
                      isPrimary: true,
                      onTap: isRunning ? _pause : _start,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Laps List
          Expanded(
            child: _laps.isEmpty
                ? Center(
                    child: Text(
                      isRunning
                          ? 'Tap Lap to record split times'
                          : 'No lap times recorded',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _kTextBody,
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        itemCount: _laps.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          color: Color(0xFFF3F4F6),
                        ),
                        itemBuilder: (context, i) {
                          final lap = _laps[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: _kPrimary.withValues(alpha: 0.10),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '#${lap.index}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _kPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Lap ${lap.index}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _kTextHead,
                                  ),
                                ),
                                const Spacer(),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '+${_formatStopwatch(lap.lapTime)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _kTextHead,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      _formatStopwatch(lap.totalTime),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: _kTextBody,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _StopwatchBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color textColor;
  final bool isPrimary;
  final VoidCallback onTap;

  const _StopwatchBtn({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.textColor,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minWidth: isPrimary ? 130 : 100),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: bgColor.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3: COUNTDOWN TIMER
// ─────────────────────────────────────────────────────────────────────────────

class CountdownTimerTab extends StatefulWidget {
  const CountdownTimerTab({super.key});

  @override
  State<CountdownTimerTab> createState() => _CountdownTimerTabState();
}

class _CountdownTimerTabState extends State<CountdownTimerTab>
    with AutomaticKeepAliveClientMixin {
  int _setHours = 0;
  int _setMinutes = 25;
  int _setSeconds = 0;

  late Duration _initialDuration;
  late Duration _remainingDuration;
  Timer? _countdownTimer;

  bool _isRunning = false;
  bool _isPaused = false;
  bool _isFinished = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _recalcInitialDuration();
    _remainingDuration = _initialDuration;
  }

  void _recalcInitialDuration() {
    _initialDuration = Duration(
      hours: _setHours,
      minutes: _setMinutes,
      seconds: _setSeconds,
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    super.dispose();
  }

  void _start() {
    if (_remainingDuration <= Duration.zero) {
      _remainingDuration = _initialDuration;
    }
    if (_remainingDuration <= Duration.zero) return;

    _isRunning = true;
    _isPaused = false;
    _isFinished = false;

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingDuration > const Duration(seconds: 1)) {
        setState(() {
          _remainingDuration -= const Duration(seconds: 1);
        });
      } else {
        _countdownTimer?.cancel();
        _countdownTimer = null;
        setState(() {
          _remainingDuration = Duration.zero;
          _isRunning = false;
          _isPaused = false;
          _isFinished = true;
        });
        _notifyFinished();
      }
    });
    setState(() {});
  }

  void _pause() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    setState(() {
      _isRunning = false;
      _isPaused = true;
    });
  }

  void _resume() {
    _start();
  }

  void _reset() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _isFinished = false;
      _remainingDuration = _initialDuration;
    });
  }

  void _notifyFinished() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text(
              "Time's up! Timer finished.",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        backgroundColor: _kGreenTag,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _applyPreset(int minutes) {
    if (_isRunning || _isPaused) return;
    setState(() {
      _setHours = minutes ~/ 60;
      _setMinutes = minutes % 60;
      _setSeconds = 0;
      _recalcInitialDuration();
      _remainingDuration = _initialDuration;
      _isFinished = false;
    });
  }

  String _formatRemaining(Duration d) {
    final clamped = d.isNegative ? Duration.zero : d;
    final hours = clamped.inHours.toString().padLeft(2, '0');
    final minutes = (clamped.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (clamped.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  double _progressFraction() {
    if (_initialDuration.inMilliseconds == 0) return 0.0;
    final frac =
        _remainingDuration.inMilliseconds / _initialDuration.inMilliseconds;
    return frac.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isConfigurable = !_isRunning && !_isPaused && !_isFinished;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          // Visual Finished Banner
          if (_isFinished) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _kGreenTag.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _kGreenTag.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.celebration_rounded, color: _kGreenTag, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Time's Up!",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _kGreenTag,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Countdown complete. Great study session!',
                          style: TextStyle(
                            fontSize: 12,
                            color: _kGreenTag,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          // Main Display Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Circular Progress + Time Display
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 190,
                        height: 190,
                        child: CircularProgressIndicator(
                          value: _progressFraction(),
                          strokeWidth: 10,
                          backgroundColor: _kBg,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _isFinished
                                ? _kGreenTag
                                : (_isRunning ? _kPrimary : _kAmberTag),
                          ),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatRemaining(_remainingDuration),
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: _kTextHead,
                              letterSpacing: -0.5,
                              fontFeatures: [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isFinished
                                ? 'Finished'
                                : (_isRunning
                                    ? 'Counting down'
                                    : (_isPaused ? 'Paused' : 'Set Timer')),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _isFinished
                                  ? _kGreenTag
                                  : (_isRunning ? _kPrimary : _kTextBody),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Reset Button
                    if (_isRunning || _isPaused || _isFinished) ...[
                      GestureDetector(
                        onTap: _reset,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          decoration: BoxDecoration(
                            color: _kRedTag.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.replay_rounded,
                                  size: 18, color: _kRedTag),
                              SizedBox(width: 6),
                              Text(
                                'Reset',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _kRedTag,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                    ],
                    // Start / Pause / Resume Button
                    GestureDetector(
                      onTap: () {
                        if (_isRunning) {
                          _pause();
                        } else if (_isPaused) {
                          _resume();
                        } else {
                          _start();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: _isRunning ? _kAmberTag : _kPrimary,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: (_isRunning ? _kAmberTag : _kPrimary)
                                  .withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isRunning
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isRunning
                                  ? 'Pause'
                                  : (_isPaused ? 'Resume' : 'Start'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Time Adjuster (only accessible when stopped/reset)
          if (isConfigurable) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Set Duration',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kTextHead,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _TimeUnitPicker(
                          label: 'Hours',
                          value: _setHours,
                          onIncrement: () {
                            if (_setHours < 23) {
                              setState(() {
                                _setHours++;
                                _recalcInitialDuration();
                                _remainingDuration = _initialDuration;
                              });
                            }
                          },
                          onDecrement: () {
                            if (_setHours > 0) {
                              setState(() {
                                _setHours--;
                                _recalcInitialDuration();
                                _remainingDuration = _initialDuration;
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          ':',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: _kTextBody,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _TimeUnitPicker(
                          label: 'Minutes',
                          value: _setMinutes,
                          onIncrement: () {
                            if (_setMinutes < 59) {
                              setState(() {
                                _setMinutes++;
                                _recalcInitialDuration();
                                _remainingDuration = _initialDuration;
                              });
                            }
                          },
                          onDecrement: () {
                            if (_setMinutes > 0) {
                              setState(() {
                                _setMinutes--;
                                _recalcInitialDuration();
                                _remainingDuration = _initialDuration;
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          ':',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: _kTextBody,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _TimeUnitPicker(
                          label: 'Seconds',
                          value: _setSeconds,
                          onIncrement: () {
                            if (_setSeconds < 59) {
                              setState(() {
                                _setSeconds++;
                                _recalcInitialDuration();
                                _remainingDuration = _initialDuration;
                              });
                            }
                          },
                          onDecrement: () {
                            if (_setSeconds > 0) {
                              setState(() {
                                _setSeconds--;
                                _recalcInitialDuration();
                                _remainingDuration = _initialDuration;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Quick Presets
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Study Presets',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kTextHead,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PresetChip(
                        label: '5 min',
                        isSelected:
                            _setHours == 0 && _setMinutes == 5 && _setSeconds == 0,
                        onTap: () => _applyPreset(5),
                      ),
                      _PresetChip(
                        label: '10 min',
                        isSelected:
                            _setHours == 0 && _setMinutes == 10 && _setSeconds == 0,
                        onTap: () => _applyPreset(10),
                      ),
                      _PresetChip(
                        label: '15 min',
                        isSelected:
                            _setHours == 0 && _setMinutes == 15 && _setSeconds == 0,
                        onTap: () => _applyPreset(15),
                      ),
                      _PresetChip(
                        label: '25 min (Pomodoro)',
                        isSelected:
                            _setHours == 0 && _setMinutes == 25 && _setSeconds == 0,
                        onTap: () => _applyPreset(25),
                      ),
                      _PresetChip(
                        label: '45 min',
                        isSelected:
                            _setHours == 0 && _setMinutes == 45 && _setSeconds == 0,
                        onTap: () => _applyPreset(45),
                      ),
                      _PresetChip(
                        label: '60 min',
                        isSelected:
                            _setHours == 1 && _setMinutes == 0 && _setSeconds == 0,
                        onTap: () => _applyPreset(60),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _TimeUnitPicker extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _TimeUnitPicker({
    required this.label,
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 22),
          color: _kPrimary,
          onPressed: onIncrement,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _kTextHead,
              fontFeatures: [
                FontFeature.tabularFigures(),
              ],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
          color: _kPrimary,
          onPressed: onDecrement,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: _kTextBody,
          ),
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _kPrimary : _kBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : _kTextHead,
          ),
        ),
      ),
    );
  }
}
