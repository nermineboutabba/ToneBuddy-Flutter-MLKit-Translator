import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_smart_reply/google_mlkit_smart_reply.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _slateDark = Color(0xFF0F172A);
  static const Color _slateMuted = Color(0xFF475569);
  static const Color _tealPrimary = Color(0xFF0D9488);
  static const Color _tealDark = Color(0xFF0F766E);
  static const Color _tealSoft = Color(0xFFCCFBF1);
  static const Color _borderSlate = Color(0xFFCBD5E1);

  static const String _defaultSampleChat =
      '[09:42] Client: Hi! Are we still meeting tomorrow at 2 PM to review the prototype?\n'
      '[09:43] You: Yes, let me confirm the room booking.\n'
      '[09:44] Client: Sounds good, let me know when you are free!';

  late final TextEditingController _inputController;

  String selectedLanguage = 'English';
  String selectedTone = 'Professional';
  String toneResult = '';
  List<String> smartSuggestions = [];
  bool isGenerating = false;

  final SmartReply smartReply = SmartReply();
  final modelManager = OnDeviceTranslatorModelManager();

  final List<String> languages = ['English', 'French', 'Spanish', 'Arabic'];
  final List<String> toneContexts = ['Professional', 'Friendly', 'Neutral'];

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(text: _defaultSampleChat);
  }

  String getLanguageCode(String language) {
    switch (language) {
      case 'French':
        return 'fr';
      case 'Spanish':
        return 'es';
      case 'Arabic':
        return 'ar';
      default:
        return 'en';
    }
  }

  TranslateLanguage getTargetLanguage(String language) {
    switch (language) {
      case 'French':
        return TranslateLanguage.french;
      case 'Spanish':
        return TranslateLanguage.spanish;
      case 'Arabic':
        return TranslateLanguage.arabic;
      default:
        return TranslateLanguage.english;
    }
  }

  Future<bool> ensureModelIsReady(String languageCode) async {
    try {
      final isDownloaded = await modelManager.isModelDownloaded(languageCode);
      if (isDownloaded) return true;
      return await modelManager
          .downloadModel(languageCode, isWifiRequired: false)
          .timeout(const Duration(seconds: 6), onTimeout: () => false);
    } catch (_) {
      return false;
    }
  }

  String _applyToneAndFallbackLocale(String reply, String language, String tone) {
    final lower = reply.toLowerCase();
    if (language == 'French') {
      if (tone == 'Friendly') {
        if (lower.contains('great')) return 'Super, merci beaucoup !';
        if (lower.contains('okay') || lower == 'ok') return 'Ça marche pour moi !';
        if (lower.contains('will do')) return 'Je m’en occupe tout de suite !';
        if (lower.contains('yes')) return 'Oui, avec grand plaisir !';
      } else {
        if (lower.contains('great')) return 'Parfait, merci pour votre retour.';
        if (lower.contains('okay') || lower == 'ok') return 'Très bien, c’est noté.';
        if (lower.contains('will do')) return 'Je confirme et je m’en charge.';
        if (lower.contains('yes')) return 'Oui, tout à fait.';
      }
    } else if (language == 'Spanish') {
      if (lower.contains('great')) return '¡Genial, muchas gracias!';
      if (lower.contains('okay') || lower == 'ok') return 'De acuerdo, perfecto.';
      if (lower.contains('will do')) return 'Me encargo de ello enseguida.';
    } else if (language == 'Arabic') {
      if (lower.contains('great')) return 'رائع، شكراً جزيلاً لك.';
      if (lower.contains('okay') || lower == 'ok') return 'حسناً، تم التأكيد.';
      if (lower.contains('will do')) return 'سأقوم بذلك على الفور.';
    }
    return reply;
  }

  /// Parses WhatsApp `[timestamp] Sender: message` exports and falls back
  /// cleanly to treating plain lines as incoming remote messages.
  List<Map<String, dynamic>> parseWhatsAppChat(String rawChat) {
    final lines = rawChat
        .trim()
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    final List<Map<String, dynamic>> messages = [];

    for (final line in lines) {
      final match = RegExp(r'^\[.*?\]\s(.*?):\s(.*)$').firstMatch(line);
      if (match != null && match.groupCount == 2) {
        final sender = match.group(1)!;
        final text = match.group(2)!;
        final isLocal = sender.toLowerCase() == 'you';
        messages.add({'text': text, 'isLocalUser': isLocal});
      } else {
        messages.add({'text': line, 'isLocalUser': false});
      }
    }

    return messages;
  }

  void addMessagesToSmartReply(List<Map<String, dynamic>> messages) {
    smartReply.clearConversation();
    final now = DateTime.now();

    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      final text = msg['text'] as String;
      final isLocal = msg['isLocalUser'] as bool;
      final timestamp =
          now.subtract(Duration(minutes: messages.length - i)).millisecondsSinceEpoch;

      if (isLocal) {
        smartReply.addMessageToConversationFromLocalUser(text, timestamp);
      } else {
        smartReply.addMessageToConversationFromRemoteUser(text, timestamp, 'user1');
      }
    }
  }

  Future<void> generateSmartReply() async {
    final inputText = _inputController.text.trim();
    if (inputText.isEmpty || isGenerating) return;

    setState(() {
      isGenerating = true;
    });

    OnDeviceTranslator? translator;
    try {
      final parsedMessages = parseWhatsAppChat(inputText);
      addMessagesToSmartReply(parsedMessages);

      final response = await smartReply.suggestReplies();
      final rawSuggestions = response.suggestions.isNotEmpty
          ? response.suggestions
          : const [
              'Yes, 2 PM tomorrow works well for me.',
              'Confirmed, I will share the agenda shortly.',
              'Sounds good, see you tomorrow afternoon!',
            ];

      final targetLanguageCode = getLanguageCode(selectedLanguage);
      List<String> finalSuggestions = List<String>.from(rawSuggestions);
      bool usedOfflineFallback = false;

      if (selectedLanguage != 'English') {
        final ready = await ensureModelIsReady(targetLanguageCode);
        if (ready) {
          translator = OnDeviceTranslator(
            sourceLanguage: TranslateLanguage.english,
            targetLanguage: getTargetLanguage(selectedLanguage),
          );

          final List<String> translatedList = [];
          for (final suggestion in rawSuggestions) {
            translatedList.add(await translator.translateText(suggestion));
          }
          finalSuggestions = translatedList;
        } else {
          usedOfflineFallback = true;
          finalSuggestions = rawSuggestions
              .map((s) => _applyToneAndFallbackLocale(s, selectedLanguage, selectedTone))
              .toList();
        }
      }

      if (!mounted) return;
      setState(() {
        smartSuggestions = finalSuggestions;
        final modeLabel = usedOfflineFallback ? 'local fallback' : 'on-device ML Kit';
        toneResult =
            '$selectedTone tone profile prepared in ${selectedLanguage.toUpperCase()} ($modeLabel, ${parsedMessages.length} turn${parsedMessages.length == 1 ? '' : 's'} analyzed)';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to generate reply: $e')),
      );
    } finally {
      await translator?.close();
      if (mounted) {
        setState(() {
          isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _slateDark,
        foregroundColor: Colors.white,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum_outlined, color: Color(0xFF5EEAD4), size: 22),
            const SizedBox(width: 8),
            Text(
              'ToneBuddy',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Conversation Context',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _slateDark,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _inputController.clear();
                      toneResult = '';
                      smartSuggestions = [];
                    });
                  },
                  icon: const Icon(Icons.clear_rounded, size: 16, color: _slateMuted),
                  label: Text(
                    'Clear',
                    style: GoogleFonts.poppins(fontSize: 13, color: _slateMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _inputController,
              maxLines: 5,
              style: GoogleFonts.poppins(color: _slateDark, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Paste a chat thread or type a message you received...',
                hintStyle: TextStyle(color: _slateMuted.withValues(alpha: 0.75)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _borderSlate),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _tealPrimary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    label: 'Language',
                    value: selectedLanguage,
                    items: languages,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedLanguage = value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildDropdown(
                    label: 'Tone Context',
                    value: selectedTone,
                    items: toneContexts,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedTone = value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: isGenerating ? null : generateSmartReply,
              icon: isGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome_outlined, color: Colors.white, size: 20),
              style: ElevatedButton.styleFrom(
                backgroundColor: _tealPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              label: Text(
                isGenerating ? 'Analyzing On-Device...' : 'Generate Smart Reply',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 22),
            if (toneResult.isNotEmpty)
              Card(
                color: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _tealSoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.tune_rounded, color: _tealDark, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Tone & Language Analysis',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _slateDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        toneResult,
                        style: GoogleFonts.lato(fontSize: 15, color: _slateMuted),
                      ),
                      const Divider(height: 28, color: Color(0xFFE2E8F0)),
                      Row(
                        children: [
                          const Icon(Icons.lightbulb_outline_rounded, color: _tealPrimary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Smart Reply Suggestions',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _slateDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...smartSuggestions.map(
                        (suggestion) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  suggestion,
                                  style: GoogleFonts.lato(
                                    fontSize: 15,
                                    color: _slateDark,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Copy reply',
                                icon: const Icon(Icons.copy_rounded, size: 18, color: _tealDark),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: suggestion));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Copied to clipboard')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(canvasColor: Colors.white),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        icon: const Icon(Icons.expand_more_rounded, color: _slateDark),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: _slateMuted, fontSize: 13),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _borderSlate),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _tealPrimary, width: 2),
          ),
        ),
        style: GoogleFonts.poppins(color: _slateDark, fontSize: 15),
        borderRadius: BorderRadius.circular(14),
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(item, style: GoogleFonts.poppins(fontSize: 14, color: _slateDark)),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    smartReply.close();
    super.dispose();
  }
}
