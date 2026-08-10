import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() {
  runApp(const FixerApp());
}

class FixerApp extends StatelessWidget {
  const FixerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FIXER TERMINAL',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0A0A0C),
        fontFamily: 'Courier',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF41),
          surface: Color(0xFF141417),
        ),
      ),
      home: const TerminalController(),
    );
  }
}

class FixerManager {
  static final FixerManager _instance = FixerManager._internal();
  factory FixerManager() => _instance;
  FixerManager._internal();

  String? _encryptedGeminiKey;
  String? _encryptedGitHubPat;
  String? _tacticalPinHash;
  
  final String _salt = "LIRIDGE_SECURE_SALT_2026_V1";

  bool get isPinSet => _tacticalPinHash != null;

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin + _salt);
    return sha256.convert(bytes).toString();
  }

  String _cipher(String text, String pin) {
    final keyBytes = utf8.encode(_hashPin(pin));
    final textBytes = utf8.encode(text);
    final result = <int>[];
    for (int i = 0; i < textBytes.length; i++) {
      result.add(textBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    return base64Encode(result);
  }

  String _decipher(String cipherText, String pin) {
    final keyBytes = utf8.encode(_hashPin(pin));
    final textBytes = base64Decode(cipherText);
    final result = <int>[];
    for (int i = 0; i < textBytes.length; i++) {
      result.add(textBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    return utf8.decode(result);
  }

  bool verifyPin(String pin) {
    if (_tacticalPinHash == null) return false;
    return _tacticalPinHash == _hashPin(pin);
  }

  void setupPin(String pin) {
    _tacticalPinHash = _hashPin(pin);
  }

  void armKeys(String gemini, String github, String pin) {
    _encryptedGeminiKey = _cipher(gemini, pin);
    _encryptedGitHubPat = github.isNotEmpty ? _cipher(github, pin) : null;
  }

  // 通信の一瞬だけ平文キーを取り出すメソッド
  String? getDecryptedGeminiKey(String pin) {
    if (_encryptedGeminiKey == null || !verifyPin(pin)) return null;
    return _decipher(_encryptedGeminiKey!, pin);
  }
}

// ----------------------------------------------------
// UI制御：認証画面とチャット画面を切り替えるコントローラー
// ----------------------------------------------------
class TerminalController extends StatefulWidget {
  const TerminalController({super.key});

  @override
  State<TerminalController> createState() => _TerminalControllerState();
}

class _TerminalControllerState extends State<TerminalController> {
  bool _isArmedAndUnlocked = false;
  String _activePin = "";

  void _onUnlocked(String pin) {
    setState(() {
      _activePin = pin;
      _isArmedAndUnlocked = true;
    });
  }

  void _onLock() {
    setState(() {
      _activePin = "";
      _isArmedAndUnlocked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 誤ったスワイプバックによるデータ喪失を防ぐ
    return PopScope(
      canPop: false,
      child: _isArmedAndUnlocked
          ? OpsTerminalScreen(
              activePin: _activePin,
              onLock: _onLock,
            )
          : AuthScreen(
              onUnlocked: _onUnlocked,
            ),
    );
  }
}

// ----------------------------------------------------
// レイヤー1：セキュリティ認証・設定画面
// ----------------------------------------------------
class AuthScreen extends StatefulWidget {
  final Function(String) onUnlocked;
  const AuthScreen({super.key, required this.onUnlocked});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final FixerManager _fixer = FixerManager();
  final TextEditingController _geminiCtrl = TextEditingController();
  final TextEditingController _githubCtrl = TextEditingController();
  
  String _currentPin = "";
  final List<String> _consoleLogs = [
    "SYSTEM: FIXER PROTOCOL INITIALIZED.",
    "STATUS: SECURE AUTHENTICATION REQUIRED.",
  ];

  void _addLog(String log) {
    setState(() {
      _consoleLogs.add(log);
      if (_consoleLogs.length > 5) _consoleLogs.removeAt(0);
    });
  }

  void _onPinKey(String key) {
    HapticFeedback.lightImpact();
    setState(() {
      if (key == "DEL") {
        if (_currentPin.isNotEmpty) _currentPin = _currentPin.substring(0, _currentPin.length - 1);
      } else if (key == "CLR") {
        _currentPin = "";
      } else {
        if (_currentPin.length < 4) _currentPin += key;
      }
    });
  }

  void _processAction() {
    if (_currentPin.length != 4) return;

    if (_fixer.isPinSet) {
      // 既存PINの検証
      if (_fixer.verifyPin(_currentPin)) {
        HapticFeedback.mediumImpact();
        widget.onUnlocked(_currentPin);
      } else {
        _addLog("> ERR: INVALID PIN.");
        setState(() => _currentPin = "");
        HapticFeedback.heavyImpact();
      }
    } else {
      // 新規設定
      final geminiText = _geminiCtrl.text.trim();
      if (geminiText.isEmpty) {
        _addLog("> ERR: GEMINI API KEY IS REQUIRED.");
        setState(() => _currentPin = "");
        HapticFeedback.heavyImpact();
        return;
      }
      _fixer.setupPin(_currentPin);
      _fixer.armKeys(geminiText, _githubCtrl.text.trim(), _currentPin);
      HapticFeedback.mediumImpact();
      widget.onUnlocked(_currentPin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool needsSetup = !_fixer.isPinSet;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      _buildHeader(),
                      _buildConsoleLogs(),
                      Expanded(
                        child: _buildControlPanel(needsSetup),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10, width: 1))),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.security, color: Color(0xFF00FF41), size: 18),
            SizedBox(width: 8),
            Text("LIRIDGE FIXER TERMINAL", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ],
        ),
      ),
    );
  }

  Widget _buildConsoleLogs() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _consoleLogs.map((log) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(log, style: const TextStyle(color: Color(0xFF00FF41), fontSize: 10, fontWeight: FontWeight.bold)),
        )).toList(),
      ),
    );
  }

  Widget _buildControlPanel(bool needsSetup) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(needsSetup ? "INITIAL SETUP: CREATE API & PIN" : "SYSTEM ARMED. ENTER PIN TO UNLOCK.", 
              style: TextStyle(color: needsSetup ? Colors.amber : Colors.white54, fontSize: 11)),
          const SizedBox(height: 12),
          
          if (needsSetup) ...[
            _buildTextField(_geminiCtrl, "Gemini API Key"),
            const SizedBox(height: 6),
            _buildTextField(_githubCtrl, "GitHub PAT (Optional)"),
            const SizedBox(height: 12),
          ],
          
          Text(_currentPin.padRight(4, '-'), style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 8)),
          const SizedBox(height: 12),
          _buildNumpad(),
          const SizedBox(height: 12),
          
          if (_currentPin.length == 4)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF41).withOpacity(0.1), 
                foregroundColor: const Color(0xFF00FF41), 
                side: const BorderSide(color: Color(0xFF00FF41)), 
                minimumSize: const Size(double.infinity, 44)
              ),
              onPressed: _processAction,
              child: Text(needsSetup ? "ENCRYPT & ARM SYSTEM" : "AUTHORIZE", style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 12),
      obscureText: false,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: Colors.black,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF41))),
      ),
    );
  }

  Widget _buildNumpad() {
    return Wrap(
      spacing: 6, runSpacing: 6, alignment: WrapAlignment.center,
      children: [
        for (int i = 1; i <= 9; i++) _padBtn(i.toString()),
        _padBtn("CLR", color: Colors.redAccent.withOpacity(0.2), textColor: Colors.redAccent),
        _padBtn("0"),
        _padBtn("DEL", color: Colors.orangeAccent.withOpacity(0.2), textColor: Colors.orangeAccent),
      ],
    );
  }

  Widget _padBtn(String label, {Color? color, Color? textColor}) {
    return GestureDetector(
      onTap: () => _onPinKey(label),
      child: Container(
        width: 55, height: 40,
        decoration: BoxDecoration(
          color: color ?? Colors.white.withOpacity(0.03), 
          borderRadius: BorderRadius.circular(5), 
          border: Border.all(color: Colors.white10)
        ),
        alignment: Alignment.center,
        child: Text(
          label, 
          style: TextStyle(color: textColor ?? Colors.white70, fontSize: label.length > 1 ? 10 : 15, fontWeight: FontWeight.bold)
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// レイヤー2：AI作戦・チャットインターフェース
// ----------------------------------------------------
class OpsTerminalScreen extends StatefulWidget {
  final String activePin;
  final VoidCallback onLock;

  const OpsTerminalScreen({super.key, required this.activePin, required this.onLock});

  @override
  State<OpsTerminalScreen> createState() => _OpsTerminalScreenState();
}

class _OpsTerminalScreenState extends State<OpsTerminalScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  ChatSession? _chatSession;

  @override
  void initState() {
    super.initState();
    _initializeAI();
  }

  void _initializeAI() {
    final key = FixerManager().getDecryptedGeminiKey(widget.activePin);
    if (key == null || key.isEmpty) {
      _messages.add({"sender": "system", "text": "ERR: API KEY DECRYPTION FAILED."});
      return;
    }
    
    // Gemini 1.5 Flashモデルを使用
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: key);
    _chatSession = model.startChat();
    _messages.add({"sender": "system", "text": "LINK ESTABLISHED. READY FOR QUERY."});
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _chatSession == null) return;

    setState(() {
      _messages.add({"sender": "user", "text": text});
      _isLoading = true;
      _msgCtrl.clear();
    });

    try {
      final response = await _chatSession!.sendMessage(Content.text(text));
      setState(() {
        _messages.add({"sender": "ai", "text": response.text ?? "NO RESPONSE."});
      });
    } catch (e) {
      setState(() {
        _messages.add({"sender": "system", "text": "ERR: $e"});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("OPS TERMINAL", style: TextStyle(color: Color(0xFF00FF41), fontSize: 14, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.lock_outline, color: Colors.redAccent),
          onPressed: widget.onLock,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg["sender"] == "user";
                final isSystem = msg["sender"] == "system";
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF00FF41).withOpacity(0.1) : (isSystem ? Colors.red.withOpacity(0.1) : Colors.white10),
                      border: Border.all(color: isUser ? const Color(0xFF00FF41) : (isSystem ? Colors.red : Colors.white24)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      msg["text"]!,
                      style: TextStyle(
                        color: isUser ? const Color(0xFF00FF41) : (isSystem ? Colors.redAccent : Colors.white),
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(color: Color(0xFF00FF41), backgroundColor: Colors.black),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: "Enter command...",
                  hintStyle: TextStyle(color: Colors.white30),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Color(0xFF00FF41)),
              onPressed: _isLoading ? null : _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}
