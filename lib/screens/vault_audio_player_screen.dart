import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../models/vault_item.dart';
import '../services/vault_service.dart';

const _kCard = Color(0xFF1E1B2E);
const _kTextHead = Color(0xFFF3F4F6);
const _kTextBody = Color(0xFF9CA3AF);
const _kVaultPurple = Color(0xFF8B5CF6);
const _kVaultPurpleDark = Color(0xFF6D28D9);

class VaultAudioPlayerScreen extends StatefulWidget {
  final VaultItem item;
  const VaultAudioPlayerScreen({super.key, required this.item});

  @override
  State<VaultAudioPlayerScreen> createState() => _VaultAudioPlayerScreenState();
}

class _VaultAudioPlayerScreenState extends State<VaultAudioPlayerScreen>
    with SingleTickerProviderStateMixin {
  late VaultItem _item;
  AudioPlayer? _player;

  bool _isPlaying = false;
  bool _hasStarted = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  bool _isLoading = true;
  String? _error;
  String? _tempFilePath;
  Uint8List? _decryptedBytes;

  // Audio Controls
  bool _isLooping = false;
  double _playbackSpeed = 1.0;
  double _volume = 1.0;
  bool _isMuted = false;

  // Vinyl Animation
  late AnimationController _vinylCtrl;

  // Subscriptions
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _compSub;

  @override
  void initState() {
    super.initState();
    _item = widget.item;

    _vinylCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );

    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      _decryptedBytes = await VaultService.instance.getDecryptedBytes(_item);
      _tempFilePath =
          await VaultService.instance.prepareTempFileForOpening(_item);

      if (_tempFilePath == null && _decryptedBytes == null) {
        if (mounted) {
          setState(() {
            _error = 'Could not decrypt audio file from vault.';
            _isLoading = false;
          });
        }
        return;
      }

      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      _player = AudioPlayer();

      _posSub = _player!.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });

      _durSub = _player!.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });

      _stateSub = _player!.onPlayerStateChanged.listen((s) {
        if (mounted) {
          final isPlaying = (s == PlayerState.playing);
          setState(() => _isPlaying = isPlaying);
          if (isPlaying) {
            _vinylCtrl.repeat();
          } else {
            _vinylCtrl.stop();
          }
        }
      });

      _compSub = _player!.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
            _hasStarted = false;
          });
          _vinylCtrl.reset();
        }
      });

      // Set source for duration discovery
      if (_tempFilePath != null && File(_tempFilePath!).existsSync()) {
        try {
          await _player!.setSource(DeviceFileSource(_tempFilePath!));
        } catch (_) {
          if (_decryptedBytes != null) {
            await _player!.setSource(BytesSource(_decryptedBytes!));
          }
        }
      } else if (_decryptedBytes != null) {
        await _player!.setSource(BytesSource(_decryptedBytes!));
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Audio initialization exception: $e');
      if (mounted) {
        setState(() {
          _error = 'Audio initialization error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (_player == null) return;
    try {
      if (_isPlaying) {
        await _player!.pause();
      } else {
        if (!_hasStarted) {
          // Play from beginning
          if (_tempFilePath != null && File(_tempFilePath!).existsSync()) {
            try {
              await _player!.play(DeviceFileSource(_tempFilePath!));
            } catch (_) {
              if (_decryptedBytes != null) {
                await _player!.play(BytesSource(_decryptedBytes!));
              }
            }
          } else if (_decryptedBytes != null) {
            await _player!.play(BytesSource(_decryptedBytes!));
          }
          _hasStarted = true;
        } else {
          await _player!.resume();
        }
      }
    } catch (e) {
      debugPrint('Play/Pause exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playback failed: $e. Try opening in external player.')),
        );
      }
    }
  }

  Future<void> _toggleLoop() async {
    if (_player == null) return;
    setState(() => _isLooping = !_isLooping);
    await _player!
        .setReleaseMode(_isLooping ? ReleaseMode.loop : ReleaseMode.release);
  }

  Future<void> _changeSpeed(double speed) async {
    if (_player == null) return;
    setState(() => _playbackSpeed = speed);
    await _player!.setPlaybackRate(speed);
  }

  Future<void> _toggleMute() async {
    if (_player == null) return;
    setState(() {
      _isMuted = !_isMuted;
    });
    await _player!.setVolume(_isMuted ? 0.0 : _volume);
  }

  Future<void> _seekRelative(Duration delta) async {
    if (_player == null) return;
    final target = _position + delta;
    final clamped = Duration(
      milliseconds: target.inMilliseconds.clamp(
        0,
        _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 0,
      ),
    );
    await _player!.seek(clamped);
  }

  void _openInExternalPlayer() {
    if (_tempFilePath != null && File(_tempFilePath!).existsSync()) {
      OpenFilex.open(_tempFilePath!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparing audio track for music app...')),
      );
      VaultService.instance.prepareTempFileForOpening(_item).then((path) {
        if (path != null) OpenFilex.open(path);
      });
    }
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
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _compSub?.cancel();
    _player?.dispose();
    _vinylCtrl.dispose();
    super.dispose();
  }

  void _showInfoSheet() {
    final dateStr =
        '${_item.importDate.year}-${_item.importDate.month.toString().padLeft(2, '0')}-${_item.importDate.day.toString().padLeft(2, '0')}';

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
                Icon(Icons.music_note_rounded, color: _kVaultPurple, size: 22),
                SizedBox(width: 10),
                Text(
                  'Encrypted Audio Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _kTextHead,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow('Track Title', _item.name),
            _buildInfoRow('Original File', _item.originalFileName),
            _buildInfoRow('Duration', _formatDuration(_duration)),
            _buildInfoRow('File Size', _item.formattedSize),
            _buildInfoRow('Imported', dateStr),
            _buildInfoRow('Encryption', 'AES-256 (CBC) + PBKDF2 Key'),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Play in System Music Player'),
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0A17),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Private Audio Player',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
            tooltip: 'Track Info',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: _showInfoSheet,
          ),
          IconButton(
            tooltip: 'Open in system audio app',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: _openInExternalPlayer,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: _kVaultPurple),
                    SizedBox(height: 16),
                    Text(
                      'Decrypting audio from vault...',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              )
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.music_off_rounded, size: 54, color: Colors.amber),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.open_in_new_rounded, size: 18),
                            label: const Text('Play in System Music Player'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kVaultPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            onPressed: _openInExternalPlayer,
                          ),
                        ],
                      ),
                    ),
                  )
                : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  children: [
                    const Spacer(),

                    // Rotating Vinyl Record with glow
                    Center(
                      child: AnimatedBuilder(
                        animation: _vinylCtrl,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _vinylCtrl.value * 2 * math.pi,
                            child: child,
                          );
                        },
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF131124),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _kVaultPurple.withValues(alpha: _isPlaying ? 0.45 : 0.2),
                                blurRadius: _isPlaying ? 38 : 20,
                                spreadRadius: _isPlaying ? 6 : 0,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Vinyl Grooves
                              Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              Container(
                                width: 125,
                                height: 125,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.07),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              // Center Label
                              Container(
                                width: 80,
                                height: 80,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [_kVaultPurpleDark, _kVaultPurple],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.music_note_rounded,
                                  color: Colors.white,
                                  size: 38,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Track Title & Details
                    Text(
                      _item.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_item.originalFileName} • ${_item.formattedSize}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.white60),
                    ),

                    const Spacer(),

                    // Progress Slider
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3.5,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor: _kVaultPurple,
                        inactiveTrackColor: Colors.white12,
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: _position.inMilliseconds.toDouble().clamp(
                              0.0,
                              _duration.inMilliseconds > 0
                                  ? _duration.inMilliseconds.toDouble()
                                  : 0.0,
                            ),
                        max: _duration.inMilliseconds > 0
                            ? _duration.inMilliseconds.toDouble()
                            : 1.0,
                        onChanged: (val) {
                          _player?.seek(Duration(milliseconds: val.toInt()));
                        },
                      ),
                    ),

                    // Timestamps
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                          Text(
                            _formatDuration(_duration),
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Controls Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Repeat toggle
                        IconButton(
                          icon: Icon(
                            _isLooping ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                            color: _isLooping ? _kVaultPurple : Colors.white60,
                            size: 24,
                          ),
                          tooltip: _isLooping ? 'Repeat One' : 'Repeat Off',
                          onPressed: _toggleLoop,
                        ),

                        // Rewind 10s
                        IconButton(
                          icon: const Icon(Icons.replay_10_rounded, size: 30),
                          color: Colors.white,
                          tooltip: 'Rewind 10s',
                          onPressed: () => _seekRelative(const Duration(seconds: -10)),
                        ),

                        // Big Play / Pause button
                        GestureDetector(
                          onTap: _togglePlayPause,
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_kVaultPurple, _kVaultPurpleDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _kVaultPurple.withValues(alpha: 0.45),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
                        ),

                        // Forward 10s
                        IconButton(
                          icon: const Icon(Icons.forward_10_rounded, size: 30),
                          color: Colors.white,
                          tooltip: 'Forward 10s',
                          onPressed: () => _seekRelative(const Duration(seconds: 10)),
                        ),

                        // Speed selector popup
                        PopupMenuButton<double>(
                          icon: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_playbackSpeed}x',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          color: _kCard,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onSelected: _changeSpeed,
                          itemBuilder: (_) => [
                            for (final s in [0.75, 1.0, 1.25, 1.5, 2.0])
                              PopupMenuItem(
                                value: s,
                                child: Text(
                                  '${s}x',
                                  style: TextStyle(
                                    color: _playbackSpeed == s ? _kVaultPurple : Colors.white,
                                    fontWeight:
                                        _playbackSpeed == s ? FontWeight.w700 : FontWeight.normal,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Volume Bar Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _isMuted ? Icons.volume_off_rounded : Icons.volume_down_rounded,
                              color: Colors.white54,
                              size: 20,
                            ),
                            onPressed: _toggleMute,
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2.5,
                                thumbShape:
                                    const RoundSliderThumbShape(enabledThumbRadius: 4.5),
                                overlayShape:
                                    const RoundSliderOverlayShape(overlayRadius: 10),
                                activeTrackColor: Colors.white54,
                                inactiveTrackColor: Colors.white12,
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                value: _isMuted ? 0.0 : _volume,
                                onChanged: (v) {
                                  setState(() {
                                    _volume = v;
                                    _isMuted = false;
                                  });
                                  _player?.setVolume(v);
                                },
                              ),
                            ),
                          ),
                          const Icon(Icons.volume_up_rounded, color: Colors.white54, size: 20),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
      ),
    );
  }
}
