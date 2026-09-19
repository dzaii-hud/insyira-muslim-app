import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FloatingAudioPlayer extends StatefulWidget {
  final String title;
  final String audioUrl;

  const FloatingAudioPlayer({
    super.key,
    required this.title,
    required this.audioUrl,
  });

  @override
  State<FloatingAudioPlayer> createState() => _FloatingAudioPlayerState();
}

class _FloatingAudioPlayerState extends State<FloatingAudioPlayer> {
  final AudioPlayer _player = AudioPlayer();
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupAudio();
  }

  Source _resolveSource(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return UrlSource(path);
    }
    return AssetSource(path);
  }

  Future<void> _setupAudio() async {
    try {
      _player.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });
      _player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _player.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state == PlayerState.playing);
        }
      });
      _player.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        }
      });

      await _player.setSource(_resolveSource(widget.audioUrl));
      if (mounted) setState(() => _isLoading = false);

      // 👇 AUTO-PLAY: langsung putar begitu sumber audio siap
      await _player.resume();
    } catch (e) {
      debugPrint('Gagal load audio: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat audio: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // 👇 PENTING: dispose akan stop & lepas audio lama
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> _seekTo(Duration d) async {
    await _player.seek(d);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final goldColor = AppColors.getGoldLeaf(context);
    final primaryColor = AppColors.getPrimaryText(context);
    final surfaceLow = AppColors.getSurfaceContainerLow(context);
    final surfaceVariant = AppColors.getSurfaceVariant(context);
    final textColor = AppColors.getTextPrimary(context);
    final subTextColor = AppColors.getOnSurfaceVariant(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: surfaceVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.4 : 0.15,
            ),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.music_note, color: goldColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: goldColor,
                ),
              ),
            )
          else ...[
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: _position.inMilliseconds.toDouble().clamp(
                  0,
                  _duration.inMilliseconds.toDouble(),
                ),
                min: 0,
                max: _duration.inMilliseconds.toDouble() > 0
                    ? _duration.inMilliseconds.toDouble()
                    : 1,
                activeColor: goldColor,
                inactiveColor: surfaceVariant,
                onChanged: (v) => _seekTo(Duration(milliseconds: v.toInt())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _fmt(_position),
                    style: TextStyle(color: subTextColor, fontSize: 11),
                  ),
                  Text(
                    _fmt(_duration),
                    style: TextStyle(color: subTextColor, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.replay_10, color: primaryColor),
                  onPressed: () =>
                      _seekTo(_position - const Duration(seconds: 10)),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: goldColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    iconSize: 28,
                    icon: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: const Color(0xFF00120B),
                    ),
                    onPressed: _togglePlay,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.forward_10, color: primaryColor),
                  onPressed: () =>
                      _seekTo(_position + const Duration(seconds: 10)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
