// lib/screens/relax_sounds_page.dart
// Soothing Sounds — Dark teal themed mixing panel using just_audio
// UX: Robust play button states (loading/playing/paused), animated transitions,
// stream-driven UI, and safer toggling.
//
// pubspec.yaml (reminder):
// dependencies:
//   just_audio: ^0.9.35
//   shared_preferences: ^2.0.0
//   // optional: just_audio_background: ^0.0.7
// assets:
//   - assets/sounds/rain_loop.mp3
//   - assets/sounds/ocean_loop.mp3
//   - assets/sounds/forest_loop.mp3
//   - assets/sounds/white_noise_loop.mp3
//   - assets/sounds/om_chant_loop.mp3
//   - assets/sounds/drum_loop.mp3

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color teal1 = Color(0xFF016C6C);
const Color teal2 = Color(0xFF79C2BF);
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF005E5C);

enum UiPlayState { idle, loading, playing, paused, error }

class AmbientSound {
  final String id;
  final String label;
  final String assetPath;
  double volume; // 0..1
  bool desiredPlaying; // what the user last asked for
  AudioPlayer? player;

  // Subscriptions for state syncing
  StreamSubscription<PlayerState>? _playerStateSub;

  AmbientSound({
    required this.id,
    required this.label,
    required this.assetPath,
    this.volume = 0.6,
    this.desiredPlaying = false,
    this.player,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'volume': volume,
    'playing': desiredPlaying,
  };

  void applyJson(Map<String, dynamic> j) {
    if (j.containsKey('volume')) volume = (j['volume'] as num).toDouble();
    if (j.containsKey('playing')) desiredPlaying = j['playing'] as bool;
  }

  void attachStateListener(VoidCallback onChange) {
    if (player == null) return;
    _playerStateSub?.cancel();
    _playerStateSub = player!.playerStateStream.listen(
      (_) {
        onChange();
      },
      onError: (_) {
        onChange();
      },
    );
  }

  Future<void> dispose() async {
    await _playerStateSub?.cancel();
    try {
      await player?.dispose();
    } catch (_) {}
  }
}

class RelaxSoundsPage extends StatefulWidget {
  const RelaxSoundsPage({super.key});

  @override
  State<RelaxSoundsPage> createState() => _RelaxSoundsPageState();
}

class _RelaxSoundsPageState extends State<RelaxSoundsPage> {
  final List<AmbientSound> _sounds = [
    AmbientSound(
      id: 'om',
      label: 'OM Chant (subtle)',
      assetPath: 'assets/sounds/om_chant_loop.mp3',
    ),
    AmbientSound(
      id: 'rain',
      label: 'Rain',
      assetPath: 'assets/sounds/rain_loop.mp3',
    ),
    AmbientSound(
      id: 'ocean',
      label: 'Ocean Waves',
      assetPath: 'assets/sounds/ocean_loop.mp3',
    ),
    AmbientSound(
      id: 'forest',
      label: 'Forest (birds & leaves)',
      assetPath: 'assets/sounds/forest_loop.mp3',
    ),
    AmbientSound(
      id: 'white',
      label: 'White Noise',
      assetPath: 'assets/sounds/white_noise_loop.mp3',
    ),
    AmbientSound(
      id: 'drum',
      label: 'Drums',
      assetPath: 'assets/sounds/drum_loop.mp3',
    ),
  ];

  double _masterVolume = 0.85;
  bool get _anyPlaying =>
      _sounds.any((s) => _uiStateOf(s) == UiPlayState.playing);

  // used for simple fade timers per sound
  final Map<String, Timer?> _fadeTimers = {};

  // for soloing
  String? _soloedId;

  // for prefs
  late SharedPreferences _prefs;

  // NEW: tutorial language toggle (false = English, true = Hindi)
  bool _tutorialInHindi = false;

  @override
  void initState() {
    super.initState();
    for (final s in _sounds) {
      _fadeTimers[s.id] = null;
    }
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    final mv = _prefs.getDouble('masterVolume');
    if (mv != null) _masterVolume = mv;

    final raw = _prefs.getString('soundConfig');
    if (raw != null) {
      try {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        for (final s in _sounds) {
          if (decoded.containsKey(s.id)) {
            final j = decoded[s.id] as Map<String, dynamic>;
            s.applyJson(j);
          }
        }
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  Future<void> _savePrefs() async {
    final Map<String, dynamic> out = {};
    for (final s in _sounds) {
      out[s.id] = s.toJson();
    }
    await _prefs.setString('soundConfig', json.encode(out));
    await _prefs.setDouble('masterVolume', _masterVolume);
  }

  @override
  void dispose() {
    for (final s in _sounds) {
      _fadeTimers[s.id]?.cancel();
      s.dispose();
    }
    super.dispose();
  }

  Future<AudioPlayer> _ensurePlayer(AmbientSound s) async {
    if (s.player != null) return s.player!;
    final p = AudioPlayer();
    try {
      await p.setLoopMode(LoopMode.one);
      await p.setAsset(s.assetPath, preload: true);
      await p.setVolume((s.volume * _masterVolume).clamp(0.0, 1.0));
    } catch (e) {
      debugPrint('[relax_sounds] Failed to init ${s.assetPath}: $e');
    }
    s.player = p;
    s.attachStateListener(() {
      if (mounted) setState(() {});
    });
    return p;
  }

  UiPlayState _uiStateOf(AmbientSound s) {
    final p = s.player;
    if (p == null) {
      return s.desiredPlaying ? UiPlayState.loading : UiPlayState.idle;
    }
    final ps = p.playerState; // synchronous snapshot
    if (ps.processingState == ProcessingState.idle) {
      return s.desiredPlaying ? UiPlayState.loading : UiPlayState.idle;
    }
    if (ps.processingState == ProcessingState.loading ||
        ps.processingState == ProcessingState.buffering) {
      return UiPlayState.loading;
    }
    if (ps.processingState == ProcessingState.completed) {
      // loop mode prevents complete, but just in case:
      return UiPlayState.paused;
    }
    // ready
    if (ps.playing) return UiPlayState.playing;
    return UiPlayState.paused;
  }

  bool _isBusy(AmbientSound s) {
    final st = _uiStateOf(s);
    return st == UiPlayState.loading;
  }

  Future<void> _playSound(AmbientSound s, {bool fade = true}) async {
    s.desiredPlaying = true;
    _fadeTimers[s.id]?.cancel();
    final p = await _ensurePlayer(s);

    // If already playing or loading, no-op
    final st = _uiStateOf(s);
    if (st == UiPlayState.playing || st == UiPlayState.loading) {
      setState(() {});
      return;
    }

    if (fade) {
      const steps = 14;
      const stepMs = 50;
      int step = 0;
      final target = (s.volume * _masterVolume).clamp(0.0, 1.0);
      try {
        await p.setVolume(0.0);
        await p.play();
      } catch (_) {}
      _fadeTimers[s.id] = Timer.periodic(const Duration(milliseconds: stepMs), (
        t,
      ) async {
        step++;
        final v = target * (step / steps);
        try {
          await p.setVolume(v.clamp(0.0, 1.0));
        } catch (_) {}
        if (step >= steps) {
          t.cancel();
          _fadeTimers[s.id] = null;
        }
      });
    } else {
      try {
        await p.setVolume((s.volume * _masterVolume).clamp(0.0, 1.0));
        await p.play();
      } catch (_) {}
    }

    if (mounted) setState(() {});
    _savePrefs();
  }

  Future<void> _stopSound(AmbientSound s, {bool fade = true}) async {
    s.desiredPlaying = false;
    _fadeTimers[s.id]?.cancel();
    final p = s.player;
    if (p == null) {
      if (mounted) setState(() {});
      return;
    }

    if (fade) {
      const steps = 10;
      const stepMs = 50;
      int step = 0;
      double start = 0.0;
      try {
        start = p.volume;
      } catch (_) {
        start = (s.volume * _masterVolume).clamp(0.0, 1.0);
      }

      _fadeTimers[s.id] = Timer.periodic(const Duration(milliseconds: stepMs), (
        t,
      ) async {
        step++;
        final v = start * (1 - (step / steps));
        try {
          await p.setVolume(v.clamp(0.0, 1.0));
        } catch (_) {}
        if (step >= steps) {
          t.cancel();
          _fadeTimers[s.id] = null;
          try {
            await p.pause();
          } catch (_) {}
          // restore target volume so next play starts right
          try {
            await p.setVolume((s.volume * _masterVolume).clamp(0.0, 1.0));
          } catch (_) {}
        }
      });
    } else {
      try {
        await p.pause();
      } catch (_) {}
    }

    if (mounted) setState(() {});
    _savePrefs();
  }

  Future<void> _toggleSound(AmbientSound s) async {
    if (_isBusy(s)) return; // ignore taps while preparing/buffering
    final state = _uiStateOf(s);
    if (state == UiPlayState.playing) {
      await _stopSound(s);
    } else {
      await _playSound(s);
    }
  }

  Future<void> _setSoundVolume(AmbientSound s, double vol) async {
    s.volume = vol;
    final p = s.player;
    final effective = (s.volume * _masterVolume).clamp(0.0, 1.0);
    if (p != null) {
      try {
        await p.setVolume(effective);
      } catch (_) {}
    }
    if (mounted) setState(() {});
    _savePrefs();
  }

  Future<void> _setMasterVolume(double v) async {
    _masterVolume = v;
    for (final s in _sounds) {
      final p = s.player;
      if (p != null) {
        try {
          await p.setVolume((s.volume * _masterVolume).clamp(0.0, 1.0));
        } catch (_) {}
      }
    }
    if (mounted) setState(() {});
    _savePrefs();
  }

  Future<void> _stopAll() async {
    for (final s in _sounds) {
      await _stopSound(s, fade: false);
    }
    setState(() {
      _soloedId = null;
    });
    _savePrefs();
  }

  // Solo a sound: mute others but preserve their playing state
  Future<void> _soloSound(AmbientSound s) async {
    if (_soloedId == s.id) {
      _soloedId = null;
      for (final other in _sounds) {
        if (other.player != null) {
          try {
            await other.player!.setVolume(
              (other.volume * _masterVolume).clamp(0.0, 1.0),
            );
          } catch (_) {}
        }
      }
    } else {
      _soloedId = s.id;
      for (final other in _sounds) {
        if (other.id == s.id) continue;
        if (other.player != null) {
          try {
            await other.player!.setVolume(0.0);
          } catch (_) {}
        }
      }
      if (s.player != null) {
        try {
          await s.player!.setVolume((s.volume * _masterVolume).clamp(0.0, 1.0));
        } catch (_) {}
      }
    }
    if (mounted) setState(() {});
  }

  Widget _buildPlayIcon(UiPlayState st) {
    Widget child;
    switch (st) {
      case UiPlayState.loading:
        child = const SizedBox(
          width: 24,
          height: 24,
          child: Padding(
            padding: EdgeInsets.all(2),
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
        );
        break;
      case UiPlayState.playing:
        child = const Icon(Icons.pause_circle_filled, size: 28);
        break;
      case UiPlayState.paused:
      case UiPlayState.idle:
        child = const Icon(Icons.play_circle_fill, size: 28);
        break;
      case UiPlayState.error:
        child = const Icon(Icons.error_outline, size: 26);
        break;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (c, anim) => ScaleTransition(scale: anim, child: c),
      child: Container(key: ValueKey(st), child: child),
    );
  }

  Widget _buildSoundTile(AmbientSound s) {
    final st = _uiStateOf(s);
    final isSoloed = _soloedId != null && _soloedId != s.id;

    // Colors that reflect state
    final iconColor = switch (st) {
      UiPlayState.loading => teal2,
      UiPlayState.playing => teal2,
      UiPlayState.paused => Colors.white70,
      UiPlayState.idle => Colors.white70,
      UiPlayState.error => Colors.amber,
    };

    return Card(
      color: Colors.black.withOpacity(0.14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // Play/Pause with loading indicator
                InkResponse(
                  onTap: _isBusy(s) ? null : () => _toggleSound(s),
                  radius: 24,
                  child: IconTheme(
                    data: IconThemeData(color: iconColor),
                    child: _buildPlayIcon(st),
                  ),
                ),
                const SizedBox(width: 4),
                // Solo / unsolo
                IconButton(
                  onPressed: () => _soloSound(s),
                  icon: Icon(
                    _soloedId == s.id ? Icons.headset : Icons.headset_off,
                    size: 22,
                  ),
                  color: _soloedId == s.id ? teal2 : Colors.white38,
                  tooltip: _soloedId == s.id ? 'Unsolo' : 'Solo',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.volume_down, color: Colors.white70, size: 18),
                Expanded(
                  child: Slider(
                    value: s.volume.clamp(0.0, 1.0),
                    min: 0,
                    max: 1,
                    divisions: 20,
                    onChanged: (isSoloed || st == UiPlayState.loading)
                        ? null
                        : (v) => _setSoundVolume(s, v),
                    activeColor: teal2,
                    inactiveColor: Colors.white12,
                  ),
                ),
                SizedBox(
                  width: 42,
                  child: Text(
                    '${(s.volume * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ----- Presets -----
  Future<void> _savePresetDialog() async {
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save preset'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(hintText: 'Preset name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      final name = nameCtrl.text.trim();
      final Map<String, dynamic> preset = {
        'master': _masterVolume,
        'sounds': {},
      };
      for (final s in _sounds) preset['sounds'][s.id] = s.toJson();
      final all = _prefs.getStringList('presets') ?? [];
      final entry = json.encode({'name': name, 'data': preset});
      all.add(entry);
      await _prefs.setStringList('presets', all);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Preset saved')));
    }
  }

  Future<void> _showPresets() async {
    final list = _prefs.getStringList('presets') ?? [];
    if (list.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No presets saved')));
      return;
    }

    final choice = await showDialog<int?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Load preset'),
        children: List.generate(list.length, (i) {
          final decoded = json.decode(list[i]) as Map<String, dynamic>;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, i),
            child: Text(decoded['name'] ?? 'Preset ${i + 1}'),
          );
        }),
      ),
    );

    if (choice != null) {
      final decoded = json.decode(list[choice]) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>;
      _masterVolume = (data['master'] as num).toDouble();
      final sounds = data['sounds'] as Map<String, dynamic>;
      for (final s in _sounds) {
        if (sounds.containsKey(s.id)) {
          s.applyJson(sounds[s.id] as Map<String, dynamic>);
        }
        // update player volumes if player exists
        if (s.player != null) {
          try {
            await s.player!.setVolume(
              (s.volume * _masterVolume).clamp(0.0, 1.0),
            );
            if (s.desiredPlaying) {
              await s.player!.play();
            }
          } catch (_) {}
        }
      }
      if (mounted) setState(() {});
      _savePrefs();
    }
  }

  // ----- Tutorial (Draggable sheet with EN/HI toggle) -----
  void _showTutorial() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.92),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16.0),
                ),
                border: Border.all(color: Colors.white.withOpacity(0.02)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: StatefulBuilder(
                builder: (sheetCtx, sheetSetState) {
                  String t(String en, String hi) => _tutorialInHindi ? hi : en;

                  Widget headerToggle() {
                    return Row(
                      children: [
                        Text(
                          _tutorialInHindi ? 'Switch to EN' : 'Switch to हिंदी',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _tutorialInHindi,
                          activeColor: teal3,
                          onChanged: (v) {
                            sheetSetState(() => _tutorialInHindi = v);
                            setState(() => _tutorialInHindi = v);
                          },
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ],
                    );
                  }

                  return SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 6,
                          width: 60,
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                t(
                                  'Soothing Sounds — Tutorial',
                                  'सोथिंग साउंड्स — ट्यूटोरियल',
                                ),
                                style: const TextStyle(
                                  color: teal2,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // language toggle + close
                        headerToggle(),
                        const SizedBox(height: 8),

                        Text(
                          t('What is this?', 'यह क्या है?'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t(
                            'A mixing panel of ambient loops. Play, mix, and adjust volumes to build a calming background for meditation or focus.',
                            'अम्बिएंट लूप्स का एक मिक्सिंग पैनल। ध्यान या फोकस के लिए शांत पृष्ठभूमि बनाने हेतु प्ले, मिक्स और वॉल्यूम समायोजित करें।',
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          t('How to use', 'कैसे उपयोग करें'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t(
                            '• Tap the play icon to start a loop. Use the slider to set loop volume.\n'
                                '• Use the master volume to control overall loudness.\n'
                                '• Solo a track to focus on it (mutes others). Use Stop all to halt everything.\n'
                                '• Save presets to recall mixes later.',
                            '• किसी लूप को शुरू करने हेतु प्ले आइकन दबाएँ। स्लाइडर से लूप वॉल्यूम सेट करें।\n'
                                '• मास्टर वॉल्यूम से समग्र आवाज़ नियंत्रित करें।\n'
                                '• किसी ट्रैक को सोलो करने पर अन्य म्यूट हो जाते हैं। सबको रोकने हेतु Stop all का उपयोग करें।\n'
                                '• मिक्स सेव करने के लिए Preset सहेजें।',
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          t(
                            'Tips & best practices',
                            'टिप्स और सर्वोत्तम प्रथाएँ',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t(
                            '• Keep background loops relatively soft so cues (if any) remain audible.\n'
                                '• Combine distant ocean + soft rain or a low-volume OM chant for meditation.\n'
                                '• If playback stalls, try stopping and reinitializing that loop (tap play again).',
                            '• पृष्ठभूमि लूप को अपेक्षाकृत धीमा रखें ताकि किसी भी संकेत की आवाज़ सुनाई दे।\n'
                                '• ध्यान के लिए दूर की सागर + हल्की बारिश या कम वॉल्यूम OM मंत्र मिलाएँ।\n'
                                '• यदि प्लेबैक अटक जाए तो उस लूप को रोकें और फिर से प्रारम्भ करें (प्ले दबाएँ)।',
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          t('Presets & quick save', 'प्रेसैट्स और क्विक सेव'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t(
                            'Use Quick save to snapshot current mix instantly. Use Save preset to name and keep it. Load from the folder icon.',
                            'वर्तमान मिक्स का त्वरित स्नैपशॉट लेने के लिए Quick save का उपयोग करें। Save preset से नाम देकर रखें। फोल्डर आइकन से लोड करें।',
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 18),

                        _tutorialRow(
                          t('Play / Pause', 'प्ले / पॉज़'),
                          t(
                            'Toggle to start/stop a loop. Loading indicator appears while preparing.',
                            'लूप शुरू/बंद करने के लिए टॉगल करें। तैयारी के दौरान लोडिंग संकेत दिखेगा।',
                          ),
                        ),
                        const SizedBox(height: 10),
                        _tutorialRow(
                          t('Solo', 'सोलो'),
                          t(
                            'Solo isolates one track — others are muted but retained so you can un-solo later.',
                            'सोलो एक ट्रैक को अलग करता है — अन्य म्यूट रहेंगे पर उनकी स्थिति बनी रहेगी।',
                          ),
                        ),
                        const SizedBox(height: 10),
                        _tutorialRow(
                          t('Volume sliders', 'वॉल्यूम स्लाइडर'),
                          t(
                            'Each loop has its own slider; master volume multiplies these for the final output.',
                            'प्रत्येक लूप का अपना स्लाइडर है; मास्टर वॉल्यूम इन्हें मिलाकर अंतिम आउटपुट बनाता है।',
                          ),
                        ),

                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  // Helpful quick action: stop all and reset solo
                                  _stopAll();
                                },
                                icon: const Icon(Icons.stop_circle_outlined),
                                label: Text(t('Stop all', 'सभी बंद करें')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade400,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                              ),
                              child: Text(
                                t('Close', 'बंद करें'),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _tutorialRow(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: teal3, shape: BoxShape.circle),
          child: const Center(
            child: Icon(Icons.info_outline, color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ],
    );
  }

  // ----- UI -----
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soothing Sounds'),
        backgroundColor: teal4,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _savePresetDialog,
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            onPressed: _showPresets,
            icon: const Icon(Icons.folder_open),
          ),
          // NEW: tutorial button
          IconButton(
            onPressed: _showTutorial,
            icon: const Icon(Icons.help_outline),
            tooltip: 'Show tutorial',
          ),
        ],
      ),
      backgroundColor: const Color(0xFF031718),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Card(
                color: Colors.transparent,
                elevation: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Mix ambient loops to create a calming background. Use master volume to control overall level.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.volume_up, color: Colors.white70),
                          Expanded(
                            child: Slider(
                              value: _masterVolume,
                              min: 0,
                              max: 1,
                              divisions: 20,
                              onChanged: (v) => _setMasterVolume(v),
                              activeColor: teal2,
                              inactiveColor: Colors.white12,
                            ),
                          ),
                          SizedBox(
                            width: 48,
                            child: Text(
                              '${(_masterVolume * 100).toInt()}%',
                              style: const TextStyle(color: Colors.white70),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _anyPlaying ? _stopAll : null,
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: const Text('Stop all'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              backgroundColor: Colors.red.shade400,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.red.shade100,
                              disabledForegroundColor: Colors.white70,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final name =
                                  'Quick ${DateTime.now().toIso8601String()}';
                              final Map<String, dynamic> preset = {
                                'master': _masterVolume,
                                'sounds': {},
                              };
                              for (final s in _sounds) {
                                preset['sounds'][s.id] = s.toJson();
                              }
                              final all = _prefs.getStringList('presets') ?? [];
                              all.add(
                                json.encode({'name': name, 'data': preset}),
                              );
                              await _prefs.setStringList('presets', all);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Quick preset saved'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.flash_on),
                            label: const Text('Quick save'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              backgroundColor: teal1,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: _sounds.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) => _buildSoundTile(_sounds[i]),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tip: Combine soft rain + distant ocean or OM chant at a very low volume for meditation.',
                style: TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
