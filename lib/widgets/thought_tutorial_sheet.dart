// Thought Record Tutorial Sheet (EN/HI bilingual)
// Style + layout aligned with ABCDE sheet (draggable, video, bilingual, cardDark surface)

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:cbt_drktv/widgets/tutorial_video_player.dart';

// --- Palette (reusing from main app) ---
const Color teal1 = Color(0xFFC6EDED);
const Color teal2 = Color(0xFF79C2BF);
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF007A78);
const Color teal5 = Color(0xFF005E5C);
const Color surfaceDark = Color(0xFF071617);
const Color cardDark = Color(0xFF072726);
const Color mutedText = Color(0xFFBFDCDC);
const Color dimText = Color(0xFFA3CFCB);

const Color colorA = Color(0xFFE57373);
const Color colorB = Color(0xFFFDD835);
const Color colorC = Color(0xFF64B5F6);
const Color colorD = Color(0xFF81C784);
const Color colorE = Color(0xFFFFB74D);

/// Show the Thought Record Tutorial sheet (EN/HI toggle)
Future<void> showThoughtTutorialSheet(
  BuildContext context, {
  bool initialHindi = false,
}) {
  bool _inHindi = initialHindi;

  String t(String en, String hi) => _inHindi ? hi : en;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        maxChildSize: 0.9,
        minChildSize: 0.45,
        initialChildSize: 0.7,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: surfaceDark,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border.all(color: Colors.white10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: StatefulBuilder(
              builder: (sheetCtx, setSheet) {
                void _setLang(bool v) => setSheet(() => _inHindi = v);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- drag handle
                    Container(
                      height: 6,
                      width: 60,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),

                    // --- Video player
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final videoHeight = math.min(
                          230.0,
                          math.max(120.0, constraints.maxHeight * 0.45),
                        );
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: videoHeight,
                            child: TutorialYoutubePlayer(
                              videoUrl: 'https://youtu.be/9yl_u5e3i3k',
                              height: videoHeight,
                              autoPlay: false,
                              showControls: true,
                              onFullScreenToggle: (bool isFullScreen) {},
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.zero,
                        physics: const ClampingScrollPhysics(),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  t(
                                    'Thought Record Tutorial',
                                    'विचार रिकॉर्ड ट्यूटोरियल',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: mutedText,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),

                          // --- language toggle + copy tips
                          Row(
                            children: [
                              Text(
                                _inHindi ? 'Switch to EN' : 'Switch to हिंदी',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Switch(
                                value: _inHindi,
                                activeColor: teal3,
                                onChanged: _setLang,
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () {
                                  final enTips = [
                                    '1) Write the situation factually.',
                                    '2) Capture the automatic thought that came up.',
                                    '3) Look for evidence supporting and opposing it.',
                                    '4) Write a balanced, alternative thought.',
                                  ].join('\n');
                                  final hiTips = [
                                    '1) स्थिति को तथ्यों के रूप में लिखें।',
                                    '2) जो स्वचालित विचार आया, उसे लिखें।',
                                    '3) उसके पक्ष और विपक्ष में प्रमाण देखें।',
                                    '4) संतुलित वैकल्पिक विचार लिखें।',
                                  ].join('\n');

                                  Clipboard.setData(
                                    ClipboardData(
                                      text: _inHindi ? hiTips : enTips,
                                    ),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        t(
                                          'Checklist copied',
                                          'चेकलिस्ट कॉपी हो गई',
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.copy,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                                label: Text(
                                  t('Copy checklist', 'चेकलिस्ट कॉपी करें'),
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),
                          Text(
                            t(
                              'Why Thought Records help',
                              'विचार रिकॉर्ड क्यों मददगार हैं',
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
                              'Thought records are a CBT tool to help you observe how your thoughts affect feelings and actions. Writing them builds awareness and allows re-evaluation of unhelpful thinking patterns.',
                              'विचार रिकॉर्ड एक CBT उपकरण है जो यह देखने में मदद करता है कि हमारे विचार भावनाओं और व्यवहार को कैसे प्रभावित करते हैं। इन्हें लिखने से जागरूकता बढ़ती है और अनुपयोगी सोच के पैटर्न को पुनः मूल्यांकित किया जा सकता है।',
                            ),
                            style: const TextStyle(color: Colors.white70),
                          ),

                          const SizedBox(height: 14),
                          _section('Core ideas', t),
                          _bullet(
                            Icons.flash_on,
                            t(
                              'Automatic thoughts come instantly.',
                              'स्वचालित विचार तुरंत आते हैं।',
                            ),
                          ),
                          _bullet(
                            Icons.compare_arrows,
                            t(
                              'We can test thoughts against facts.',
                              'हम विचारों को तथ्यों से परख सकते हैं।',
                            ),
                          ),
                          _bullet(
                            Icons.favorite_outline,
                            t(
                              'Balanced thinking reduces distress.',
                              'संतुलित सोच तनाव कम करती है।',
                            ),
                          ),

                          const SizedBox(height: 14),
                          _section('Steps to fill the record', t),
                          _numbered(
                            1,
                            t(
                              'Describe the situation (when, where, who).',
                              'स्थिति लिखें (कब, कहाँ, कौन)।',
                            ),
                            colorA,
                          ),
                          _numbered(
                            2,
                            t(
                              'Record the automatic thought that appeared.',
                              'जो स्वचालित विचार आया, उसे लिखें।',
                            ),
                            colorC,
                          ),
                          _numbered(
                            3,
                            t(
                              'Write evidence supporting the thought.',
                              'विचार के पक्ष में प्रमाण लिखें।',
                            ),
                            colorD,
                          ),
                          _numbered(
                            4,
                            t(
                              'Write evidence against the thought.',
                              'विचार के खिलाफ प्रमाण लिखें।',
                            ),
                            colorE,
                          ),
                          _numbered(
                            5,
                            t(
                              'Write an alternative, balanced thought.',
                              'एक वैकल्पिक, संतुलित विचार लिखें।',
                            ),
                            teal3,
                          ),

                          const SizedBox(height: 14),
                          _section('Tips for balanced thinking', t),
                          _bullet(
                            Icons.help_outline,
                            t(
                              'What would I tell a friend who had this thought?',
                              'यदि किसी मित्र को यह विचार आए तो मैं क्या कहूँगा?',
                            ),
                          ),
                          _bullet(
                            Icons.help_outline,
                            t(
                              'Is there a less extreme explanation?',
                              'क्या कोई कम चरम व्याख्या हो सकती है?',
                            ),
                          ),
                          _bullet(
                            Icons.help_outline,
                            t(
                              'What evidence truly supports this idea?',
                              'वास्तव में कौन सा प्रमाण इस विचार का समर्थन करता है?',
                            ),
                          ),

                          const SizedBox(height: 16),
                          _section('Example (short)', t),
                          _example(
                            t('Situation', 'स्थिति'),
                            t(
                              'Missed a deadline and thought "I always fail".',
                              'समय सीमा चूक गई और सोचा "मैं हमेशा असफल रहता हूँ"।',
                            ),
                          ),
                          _example(
                            t('Automatic thought', 'स्वचालित विचार'),
                            t(
                              '"I can’t do anything right."',
                              '"मैं कुछ भी सही नहीं कर सकता।"',
                            ),
                          ),
                          _example(
                            t('Evidence against', 'विरोधी प्रमाण'),
                            t(
                              'I met previous deadlines; manager was supportive.',
                              'मैंने पहले समय सीमा पूरी की थी; प्रबंधक सहयोगी था।',
                            ),
                          ),
                          _example(
                            t('Alternative thought', 'वैकल्पिक विचार'),
                            t(
                              'One missed task doesn’t define me.',
                              'एक गलती से मेरी पूरी क्षमता तय नहीं होती।',
                            ),
                          ),

                          const SizedBox(height: 18),
                          _section('Safety & reflection', t),
                          _bullet(
                            Icons.error_outline,
                            t(
                              'This tool complements, not replaces, therapy.',
                              'यह उपकरण थेरेपी का विकल्प नहीं है।',
                            ),
                          ),
                          _bullet(
                            Icons.medical_services,
                            t(
                              'If distress persists, seek professional help.',
                              'यदि कष्ट बना रहे, तो पेशेवर सहायता लें।',
                            ),
                          ),

                          const SizedBox(height: 20),
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.of(ctx).pop(),

                              label: Text(t('Close', 'बंद करें')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: teal3,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      );
    },
  );
}

// ---------- Helper widgets ----------

Widget _section(String title, String Function(String, String) t) => Text(
  title,
  style: const TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w700,
  ),
);

Widget _bullet(IconData icon, String text) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: teal2, size: 18),
      const SizedBox(width: 10),
      Expanded(
        child: Text(text, style: const TextStyle(color: Colors.white70)),
      ),
    ],
  ),
);

Widget _numbered(int n, String text, Color color) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CircleAvatar(
        radius: 12,
        backgroundColor: color,
        child: Text(
          '$n',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(text, style: const TextStyle(color: Colors.white70)),
      ),
    ],
  ),
);

Widget _example(String title, String body) => Container(
  margin: const EdgeInsets.only(bottom: 8),
  padding: const EdgeInsets.all(10),
  decoration: BoxDecoration(
    color: Colors.white10,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: Colors.white12),
  ),
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
      const SizedBox(height: 6),
      Text(body, style: const TextStyle(color: Colors.white70, height: 1.3)),
    ],
  ),
);
