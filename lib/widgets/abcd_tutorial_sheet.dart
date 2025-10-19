// lib/widgets/abcd_tutorial_sheet.dart
// Extracted ABCD tutorial sheet (modal) from the main page.
// Usage: import this file and call `showAbcdTutorialSheet(context, ...);`

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

// Local copy of palette (keeps the widget self-contained).
const Color teal1 = Color(0xFFC6EDED);
const Color teal2 = Color(0xFF79C2BF);
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF007A78);
const Color teal5 = Color(0xFF005E5C);
const Color teal6 = Color(0xFF004E4D);

// Dark surfaces for theme
const Color surfaceDark = Color(0xFF071617);
const Color cardDark = Color(0xFF072726);
const Color mutedText = Color(0xFFBFDCDC);
const Color dimText = Color(0xFFA3CFCB);

/// Show the extracted tutorial as a draggable bottom sheet.
///
/// - [initialHindi] optional initial language toggle state.
/// - [onCreate] called when user presses "Create worksheet" in the sheet.
/// - [onLanguageChanged] optional callback to notify parent of language toggle.
Future<void> showAbcdTutorialSheet(
  BuildContext context, {
  bool initialHindi = false,
  VoidCallback? onCreate,
  ValueChanged<bool>? onLanguageChanged,
}) {
  bool _tutorialInHindi = initialHindi;

  String t(String en, String hi) => _tutorialInHindi ? hi : en;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
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
              builder: (sheetCtx, sheetSetState) {
                String tLocal(String en, String hi) =>
                    _tutorialInHindi ? hi : en;

                void _setLang(bool v) {
                  sheetSetState(() => _tutorialInHindi = v);
                  if (onLanguageChanged != null) onLanguageChanged(v);
                }

                return SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 6,
                        width: 60,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tLocal(
                                'ABCD Worksheet — Detailed CBT Tutorial',
                                'ABCD वर्कशीट — विस्तृत CBT मार्गदर्शिका',
                              ),
                              style: TextStyle(
                                color: mutedText,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
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
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Text(
                            _tutorialInHindi
                                ? 'Switch to EN'
                                : 'Switch to हिंदी',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: _tutorialInHindi,
                            activeColor: teal3,
                            onChanged: (v) => _setLang(v),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              final enChecklist = [
                                '1) Identify activating event (A).',
                                '2) Notice automatic thought (B).',
                                '3) Record consequences (C): feelings & actions.',
                                '4) Examine evidence for/against (Socratic questions).',
                                '5) Generate alternative balanced thought (D).',
                                '6) Rate mood again and plan a behavioural experiment / reminder.',
                              ].join('\n');
                              final hiChecklist = [
                                '1) घटना (A) पहचानें।',
                                '2) स्वचालित विचार (B) नोट करें।',
                                '3) परिणाम (C): भावनाएँ और क्रियाएँ लिखें।',
                                '4) प्रमाण के लिए/विरुद्ध जाँचें (सॉक्रेटिक प्रश्न)।',
                                '5) वैकल्पिक संतुलित विचार (D) बनाएं।',
                                '6) फिर से मूड रेट करें और व्यवहारिक प्रयोग/नोट तय करें।',
                              ].join('\n');
                              Clipboard.setData(
                                ClipboardData(
                                  text: _tutorialInHindi
                                      ? hiChecklist
                                      : enChecklist,
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    tLocal(
                                      'Checklist copied',
                                      'चेकलिस्ट कॉपी हो गई',
                                    ),
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
                              tLocal('Copy checklist', 'चेकलिस्ट कॉपी करें'),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Text(
                        tLocal(
                          'What is this and why CBT?',
                          'यह क्या है और CBT क्यों?',
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tLocal(
                          'The ABCD worksheet is a practical CBT (Cognitive Behavioural Therapy) tool. CBT helps us notice how our thoughts influence feelings and behaviour. By writing them down we can test and change unhelpful automatic thoughts and plan actions that reduce distress.',
                          'ABCD वर्कशीट एक व्यवहारिक CBT (कॉग्निटिव बिहेवियरल थेरेपी) उपकरण है। CBT यह समझने में मदद करता है कि हमारे विचार हमारी भावनाओं और व्यवहार को कैसे प्रभावित करते हैं। लिखने से हम उन स्वचालित विचारों का परीक्षण कर सकते हैं और उन्हें बदलने के तरीके ढूंढ सकते हैं।',
                        ),
                        style: const TextStyle(color: Colors.white70),
                      ),

                      const SizedBox(height: 12),

                      _sectionHeader(
                        tLocal(
                          'Core CBT ideas (short)',
                          'CBT के मुख्य विचार (संक्षेप)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      _bulletItem(
                        Icons.lightbulb,
                        tLocal(
                          'Automatic thoughts are quick, often unexamined reactions to events.',
                          'स्वचालित विचार तीव्र, जल्दी आने वाले और अक्सर बिना जाँच के होते हैं।',
                        ),
                      ),
                      _bulletItem(
                        Icons.filter_alt,
                        tLocal(
                          'Cognitive distortions are predictable thinking errors (e.g. all-or-nothing, mind-reading, catastrophising).',
                          'कॉग्निटिव डिस्टॉर्शन सोच की सामान्य गलतियाँ हैं (जैसे सब-या-कुछ नहीं, दिमाग पढ़ना, तबाही का अनुमान)।',
                        ),
                      ),
                      _bulletItem(
                        Icons.search,
                        tLocal(
                          'Socratic questioning helps you examine evidence for and against a thought.',
                          'सॉक्रेटिक प्रश्न आपको किसी विचार के पक्ष/विपक्ष के प्रमाण जांचने में मदद करते हैं।',
                        ),
                      ),
                      _bulletItem(
                        Icons.build,
                        tLocal(
                          'Behavioural experiments test beliefs by trying small actions and observing results.',
                          'व्यवहारिक प्रयोग छोटे कदम उठाकर और परिणाम देखकर विश्वास का परीक्षण करते हैं।',
                        ),
                      ),

                      const SizedBox(height: 12),

                      _sectionHeader(
                        tLocal(
                          'How to use this worksheet (practical steps)',
                          'वर्कशीट कैसे प्रयोग करें (व्यवहारिक कदम)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      _numberedItem(
                        1,
                        tLocal(
                          'A — Activating event: briefly describe the situation (who, what, when, where). Be specific; avoid interpretations here — facts only.',
                          'A — घटना: संक्षेप में स्थिति बताएं (कौन, क्या, कब, कहाँ)। विशिष्ट रहें; यहाँ केवल तथ्य लिखें, व्याख्या नहीं।',
                        ),
                      ),
                      _numberedItem(
                        2,
                        tLocal(
                          'B — Belief / Automatic thought: the immediate thought that came to mind (often short — e.g. "I messed up", "They don’t like me").',
                          'B — विश्वास/स्वचालित विचार: तत्क्षण जो विचार आया (अक्सर छोटा — जैसे "मैंने गलती कर दी", "उसे मैं पसंद नहीं हूँ").',
                        ),
                      ),
                      _numberedItem(
                        3,
                        tLocal(
                          'C — Consequences: list emotional & behavioural outcomes (e.g. anxiety 8/10, avoided calling, felt tearful). Rate mood (before).',
                          'C — परिणाम: भावनात्मक और व्यवहारिक परिणाम लिखें (जैसे चिंता 8/10, कॉल करने से बचा, दुख हुआ)। पहले मूड रेट करें।',
                        ),
                      ),
                      _numberedItem(
                        4,
                        tLocal(
                          'D — Dispute / Alternative thought: examine evidence for and against the belief using Socratic questions (below) and write a kinder, balanced alternative thought.',
                          'D — विवाद/वैकल्पिक विचार: सॉक्रेटिक प्रश्न का उपयोग करके विश्वास के पक्ष/विपक्ष के प्रमाण जांचें और एक दयालु/संतुलित वैकल्पिक विचार लिखें।',
                        ),
                      ),

                      const SizedBox(height: 10),

                      _sectionHeader(
                        tLocal(
                          'Socratic prompts (use these while filling D)',
                          'सॉक्रेटिक प्रश्न (D भरते समय उपयोग करें)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      _bulletItem(
                        Icons.help_outline,
                        tLocal(
                          'What is the evidence that supports this thought?',
                          'किस बात का प्रमाण है जो इस विचार का समर्थन करता है?',
                        ),
                      ),
                      _bulletItem(
                        Icons.help_outline,
                        tLocal(
                          'What is the evidence that does NOT support it?',
                          'ऐसा क्या प्रमाण है जो इसका विरोध करता है?',
                        ),
                      ),
                      _bulletItem(
                        Icons.help_outline,
                        tLocal(
                          'Am I jumping to conclusions or mind-reading?',
                          'क्या मैं निष्कर्ष तक जल्दी पहुँच रहा/रही हूँ या दिमाग पढ़ रहा/रही हूँ?',
                        ),
                      ),
                      _bulletItem(
                        Icons.help_outline,
                        tLocal(
                          'Is there a less catastrophic way to view this?',
                          'क्या इसे कम भयावह तरीके से देखा जा सकता है?',
                        ),
                      ),
                      _bulletItem(
                        Icons.help_outline,
                        tLocal(
                          'What would I tell a friend who had this thought?',
                          'यदि कोई दोस्त ऐसा कहे तो मैं उसे क्या सलाह दूँगा/दूँगी?',
                        ),
                      ),

                      const SizedBox(height: 12),

                      _sectionHeader(
                        tLocal(
                          'Behavioural experiments and follow-up',
                          'व्यवहारिक प्रयोग और फॉलो-अप',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tLocal(
                          'After you write a balanced alternative thought, consider a small experiment you can try this week to test the belief (e.g. make one phone call, speak briefly to a colleague). Note results and re-rate your mood.',
                          'एक बार वैकल्पिक विचार लिखने के बाद, एक छोटा व्यवहारिक प्रयोग सोचें जिसे आप इस सप्ताह कर सकते हैं (जैसे एक फोन कॉल करना, सहकर्मी से संक्षेप में बात करना)। परिणाम नोट करें और मूड फिर से रेट करें।',
                        ),
                        style: const TextStyle(color: Colors.white70),
                      ),

                      const SizedBox(height: 12),

                      _sectionHeader(
                        tLocal(
                          'Common cognitive distortions (examples)',
                          'सामान्य संज्ञानात्मक विकृतियाँ (उदाहरण)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      _bulletItem(
                        Icons.block,
                        tLocal(
                          'All-or-nothing thinking — "If it’s not perfect, it’s a failure."',
                          'सभी-या-कुछ नहीं सोच — "यदि यह परिपूर्ण नहीं है, तो यह विफलता है"',
                        ),
                      ),
                      _bulletItem(
                        Icons.visibility_off,
                        tLocal(
                          'Mind-reading — assuming someone thinks badly of you.',
                          'दिमाग पढ़ना — मान लेना कि कोई आपके बारे में बुरा सोचता है।',
                        ),
                      ),
                      _bulletItem(
                        Icons.warning,
                        tLocal(
                          'Catastrophising — expecting the worst outcome.',
                          'बुरे परिणाम की आशंका — सबसे बुरा सोच लेना।',
                        ),
                      ),
                      _bulletItem(
                        Icons.timeline,
                        tLocal(
                          'Overgeneralisation — using one incident to judge everything.',
                          'अति-व्यापकता — एक घटना के आधार पर सब कुछ जज कर देना।',
                        ),
                      ),

                      const SizedBox(height: 12),

                      _sectionHeader(
                        tLocal(
                          'Worked example (short)',
                          'व्यवहारिक उदाहरण (संक्षेप)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      _exampleBlock(
                        enTitle: 'Situation',
                        enBody:
                            'Left a meeting and noticed two colleagues whispering; thought "They were talking about me — I must have sounded stupid."',
                        hiTitle: 'स्थिति',
                        hiBody:
                            'मीटिंग छोड़ी और दो सहयोगी फुसफुसाते हुए दिखे; सोचा "वे मेरे बारे में बात कर रहे थे — मैं बेवकूफ लगा।"',
                      ),
                      const SizedBox(height: 8),
                      _exampleBlock(
                        enTitle: 'Automatic thought (B)',
                        enBody: '"I sounded stupid; they don’t respect me."',
                        hiTitle: 'स्वचालित विचार (B)',
                        hiBody: '"मैं बेवकूफ लगा; वे मेरी इज्जत नहीं करते।"',
                      ),
                      const SizedBox(height: 8),
                      _exampleBlock(
                        enTitle: 'Evidence for',
                        enBody:
                            'I heard them whisper; my voice shook slightly.',
                        hiTitle: 'समर्थक प्रमाण',
                        hiBody:
                            'मैंने फुसफुसाहट सुनी; मेरी आवाज थोड़ा कांपी थी।',
                      ),
                      const SizedBox(height: 8),
                      _exampleBlock(
                        enTitle: 'Evidence against',
                        enBody:
                            'They often chat; one later smiled and said nothing negative. No one said anything directly critical.',
                        hiTitle: 'विरोधी प्रमाण',
                        hiBody:
                            'वे अक्सर बातें करते हैं; बाद में एक ने मुस्कुराया और कुछ नकारात्मक नहीं कहा। किसी ने सीधे आलोचना नहीं की।',
                      ),
                      const SizedBox(height: 8),
                      _exampleBlock(
                        enTitle: 'Balanced alternative (D)',
                        enBody:
                            'Maybe they were talking about plans; even if I felt awkward, it doesn’t mean I’m stupid. I can follow up if needed.',
                        hiTitle: 'संतुलित वैकल्पिक विचार (D)',
                        hiBody:
                            'शायद वे योजनाओं के बारे में बात कर रहे थे; भले ही मैं थोड़ा असहज महसूस करूँ, इसका मतलब यह नहीं कि मैं बेवकूफ हूँ। ज़रूरत पड़ने पर मैं बाद में बात कर सकता/सकती हूँ।',
                      ),

                      const SizedBox(height: 12),

                      _sectionHeader(
                        tLocal('Safety & limits', 'सुरक्षा और सीमाएँ'),
                      ),
                      const SizedBox(height: 8),
                      _bulletItem(
                        Icons.medical_services,
                        tLocal(
                          'This worksheet is a self-help tool and does not replace therapy. If distress is intense or persistent, contact a mental health professional.',
                          'यह वर्कशीट स्व-मदद का उपकरण है और थेरेपी का विकल्प नहीं है। यदि कष्ट तीव्र या लगातार है, तो किसी मानसिक स्वास्थ्य पेशेवर से संपर्क करें।',
                        ),
                      ),
                      _bulletItem(
                        Icons.error_outline,
                        tLocal(
                          'If a worksheet brings up traumatic memories or severe distress, stop and seek support — don’t try to push through alone.',
                          'यदि वर्कशीट करने से आघात संबंधी यादें या गंभीर कष्ट उठते हैं, तो रोकें और सहायता लें — अकेले इसे दबाने की कोशिश न करें।',
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                if (onCreate != null) onCreate();
                              },
                              icon: const Icon(Icons.add),
                              label: Text(
                                tLocal('Create worksheet', 'वर्कशीट बनाएं'),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: teal3,
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
                              side: BorderSide(color: Colors.white12),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                            ),
                            child: Text(
                              tLocal('Close', 'बंद करें'),
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

Widget _sectionHeader(String text) {
  return Text(
    text,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    ),
  );
}

Widget _bulletItem(IconData icon, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: teal2),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white70)),
        ),
      ],
    ),
  );
}

Widget _numberedItem(int n, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: teal3,
          child: Text(
            '$n',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white70)),
        ),
      ],
    ),
  );
}

Widget _exampleBlock({
  required String enTitle,
  required String enBody,
  String? hiTitle,
  String? hiBody,
}) {
  // This helper expects to be used within the sheet where language toggle state is known.
  // For simplicity here we show only English text; the caller uses language switching earlier.
  final title = enTitle;
  final body = enBody;
  return Container(
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
        Text(body, style: const TextStyle(color: Colors.white70)),
      ],
    ),
  );
}
