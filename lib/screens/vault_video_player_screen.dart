import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:video_player/video_player.dart';
import '../models/vault_item.dart';
import '../services/vault_service.dart';

const _kCard = Color(0xFF1E1B2E);
const _kTextHead = Color(0xFFF3F4F6);
const _kTextBody = Color(0xFF9CA3AF);
const _kVaultPurple = Color(0xFF8B5CF6);
const _kVaultPurpleDark = Color(0xFF6D28D9);

class VaultVideoPlayerScreen extends StatefulWidget {
  final VaultItem item;
  const VaultVideoPlayerScreen({super.key, required this.item});

  @override
  State<VaultVideoPlayerScreen> createState() => _VaultVideoPlayerScreenState();
}

class _VaultVideoPlayerScreenState extends State<VaultVideoPlayerScreen> {
  late VaultItem _item;
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _error;
  String? _tempFilePath;

  // Player UI state
  bool _showControls = true;
  Timer? _hideControlsTimer;
  bool _isMuted = false;
  double _playbackSpeed = 1.0;
  BoxFit _videoFit = BoxFit.contain;

  // Double-tap seek visual feedback
  bool _showRewindIndicator = false;
  bool _showForwardIndicator = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _tempFilePath =
          await VaultService.instance.prepareTempFileForOpening(_item);
      if (_tempFilePath == null) {
        if (mounted) {
          setState(() {
            _error = 'Unable to decrypt video file from secure vault.';
            _isLoading = false;
          });
        }
        return;
      }

      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final file = File(_tempFilePath!);
      _controller = VideoPlayerController.file(file);

      await _controller!.initialize();
      _controller!.addListener(_onControllerUpdate);

      if (mounted) {
        setState(() => _isLoading = false);
        _controller!.play();
        _startHideControlsTimer();
      }
    } catch (e) {
      debugPrint('In-app video player init exception: $e');
      if (mounted) {
        // If in-app player fails (e.g. desktop Windows or unsupported codec),
        // we smoothly fall back to our premium showcase card without crashing.
        setState(() {
          _error = 'In-app playback is not supported for this video format on this device.';
          _isLoading = false;
        });
      }
    }
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (_controller != null && _controller!.value.isPlaying) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _controller!.value.isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _startHideControlsTimer();
      } else {
        _hideControlsTimer?.cancel();
      }
    });
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _showControls = true;
        _hideControlsTimer?.cancel();
      } else {
        _controller!.play();
        _startHideControlsTimer();
      }
    });
  }

  void _seekRelative(Duration delta) {
    if (_controller == null) return;
    final newPos = _controller!.value.position + delta;
    final clamped = Duration(
      milliseconds: newPos.inMilliseconds.clamp(
        0,
        _controller!.value.duration.inMilliseconds,
      ),
    );
    _controller!.seekTo(clamped);
    _startHideControlsTimer();
  }

  void _toggleMute() {
    if (_controller == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _changeSpeed(double speed) {
    if (_controller == null) return;
    setState(() {
      _playbackSpeed = speed;
      _controller!.setPlaybackSpeed(speed);
    });
  }

  void _toggleFit() {
    setState(() {
      _videoFit =
          _videoFit == BoxFit.contain ? BoxFit.cover : BoxFit.contain;
    });
  }

  void _openInExternalPlayer() {
    if (_tempFilePath != null && File(_tempFilePath!).existsSync()) {
      OpenFilex.open(_tempFilePath!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparing video file for player...')),
      );
      VaultService.instance.prepareTempFileForOpening(_item).then((path) {
        if (path != null) OpenFilex.open(path);
      });
    }
  }

  void _showInfoSheet() {
    final durStr = _controller != null && _controller!.value.isInitialized
        ? _formatDuration(_controller!.value.duration)
        : 'Unknown';
    final resStr = _controller != null && _controller!.value.isInitialized
        ? '${_controller!.value.size.width.toInt()} × ${_controller!.value.size.height.toInt()} px'
        : 'Native resolution';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Icon(Icons.video_library_rounded, color: _kVaultPurple, size: 22),
                SizedBox(width: 10),
                Text(
                  'Encrypted Video Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _kTextHead,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow('Title', _item.name),
            _buildInfoRow('File Name', _item.originalFileName),
            _buildInfoRow('Resolution', resStr),
            _buildInfoRow('Duration', durStr),
            _buildInfoRow('File Size', _item.formattedSize),
            _buildInfoRow('Security', 'AES-256 GCM / CBC Encryption'),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Open in Device Video Player'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kVaultPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _openInExternalPlayer();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: _kTextBody)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _kTextHead,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final bool hasValidController =
        _controller != null && _controller!.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: _showControls || !hasValidController
            ? Colors.black.withValues(alpha: 0.8)
            : Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _item.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: _item.isFavorite ? 'Remove Favorite' : 'Mark Favorite',
            icon: Icon(
              _item.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: _item.isFavorite ? Colors.amber : Colors.white,
            ),
            onPressed: () async {
              await VaultService.instance.toggleFavorite(_item.id);
              setState(() {
                _item = _item.copyWith(isFavorite: !_item.isFavorite);
              });
            },
          ),
          IconButton(
            tooltip: 'Video Details',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: _showInfoSheet,
          ),
          IconButton(
            tooltip: 'Open in system player',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: _openInExternalPlayer,
          ),
        ],
      ),
      body: Center(
        child: _isLoading
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _kVaultPurple),
                  SizedBox(height: 16),
                  Text(
                    'Decrypting video from secure vault...',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              )
            : !hasValidController
                ? _buildFallbackShowcase()
                : _buildPlayerWithCustomControls(),
      ),
    );
  }

  Widget _buildFallbackShowcase() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated cinema badge
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kVaultPurpleDark, _kVaultPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _kVaultPurple.withValues(alpha: 0.45),
                  blurRadius: 32,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              size: 58,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _item.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_item.originalFileName} • ${_item.formattedSize}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          // Security pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_rounded, size: 14, color: _kVaultPurple),
                SizedBox(width: 6),
                Text(
                  'Encrypted with AES-256',
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          if (_error != null) ...[
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.white60, height: 1.4),
            ),
            const SizedBox(height: 16),
          ],
          // Big Primary Action: Open in system player
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.play_circle_filled_rounded, size: 22),
              label: const Text(
                'Play in Device Video Player',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kVaultPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
              ),
              onPressed: _openInExternalPlayer,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Opens using your device\'s hardware-accelerated video app with full subtitle and audio codec support.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerWithCustomControls() {
    final position = _controller!.value.position;
    final duration = _controller!.value.duration;
    final isPlaying = _controller!.value.isPlaying;

    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          // Video Canvas
          Center(
            child: FittedBox(
              fit: _videoFit,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),

          // Double tap gesture zones for +/- 10s
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: () {
                    _seekRelative(const Duration(seconds: -10));
                    setState(() => _showRewindIndicator = true);
                    Future.delayed(const Duration(milliseconds: 600), () {
                      if (mounted) setState(() => _showRewindIndicator = false);
                    });
                  },
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: () {
                    _seekRelative(const Duration(seconds: 10));
                    setState(() => _showForwardIndicator = true);
                    Future.delayed(const Duration(milliseconds: 600), () {
                      if (mounted) setState(() => _showForwardIndicator = false);
                    });
                  },
                ),
              ),
            ],
          ),

          // Rewind feedback overlay
          if (_showRewindIndicator)
            Positioned(
              left: 40,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fast_rewind_rounded, size: 36, color: Colors.white),
                    Text('-10s', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ),

          // Forward feedback overlay
          if (_showForwardIndicator)
            Positioned(
              right: 40,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fast_forward_rounded, size: 36, color: Colors.white),
                    Text('+10s', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ),

          // Full custom controls overlay
          if (_showControls) ...[
            // Dim background
            Container(color: Colors.black.withValues(alpha: 0.45)),

            // Center Play / Pause button
            Center(
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _kVaultPurple.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _kVaultPurple.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
              ),
            ),

            // Bottom control bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Scrubber Slider
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3.5,
                          thumbShape:
                              const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                          overlayShape:
                              const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: _kVaultPurple,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          value: position.inMilliseconds.toDouble().clamp(
                                0.0,
                                duration.inMilliseconds > 0
                                    ? duration.inMilliseconds.toDouble()
                                    : 0.0,
                              ),
                          max: duration.inMilliseconds > 0
                              ? duration.inMilliseconds.toDouble()
                              : 1.0,
                          onChanged: (val) {
                            _controller!
                                .seekTo(Duration(milliseconds: val.toInt()));
                            _startHideControlsTimer();
                          },
                        ),
                      ),

                      // Time and tool row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            Text(
                              _formatDuration(position),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const Text(
                              ' / ',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                            const Spacer(),

                            // 10s Rewind
                            IconButton(
                              icon: const Icon(Icons.replay_10_rounded,
                                  color: Colors.white, size: 22),
                              tooltip: 'Rewind 10s',
                              onPressed: () =>
                                  _seekRelative(const Duration(seconds: -10)),
                            ),

                            // 10s Forward
                            IconButton(
                              icon: const Icon(Icons.forward_10_rounded,
                                  color: Colors.white, size: 22),
                              tooltip: 'Forward 10s',
                              onPressed: () =>
                                  _seekRelative(const Duration(seconds: 10)),
                            ),

                            // Mute toggle
                            IconButton(
                              icon: Icon(
                                _isMuted
                                    ? Icons.volume_off_rounded
                                    : Icons.volume_up_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              tooltip: _isMuted ? 'Unmute' : 'Mute',
                              onPressed: _toggleMute,
                            ),

                            // Aspect Ratio Fit toggle
                            IconButton(
                              icon: Icon(
                                _videoFit == BoxFit.contain
                                    ? Icons.fullscreen_rounded
                                    : Icons.fullscreen_exit_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              tooltip: _videoFit == BoxFit.contain
                                  ? 'Fill Screen'
                                  : 'Fit Screen',
                              onPressed: _toggleFit,
                            ),

                            // Playback Speed Popup
                            PopupMenuButton<double>(
                              icon: Text(
                                '${_playbackSpeed}x',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              color: _kCard,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              onSelected: _changeSpeed,
                              itemBuilder: (_) => [
                                for (final speed in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                                  PopupMenuItem(
                                    value: speed,
                                    child: Text(
                                      '${speed}x',
                                      style: TextStyle(
                                        color: _playbackSpeed == speed
                                            ? _kVaultPurple
                                            : Colors.white,
                                        fontWeight: _playbackSpeed == speed
                                            ? FontWeight.w700
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
