import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/common/app_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _fastApiUrlCtrl = TextEditingController();
  late TextEditingController _apiKeyCtrl;

  bool _fastApiConnected = false;
  bool _fastApiChecking = false;
  bool _isApiKeyVisible = false;
  bool _isApiKeyValid = false;
  bool _apiKeyReady = false; // initState 비동기 완료 여부

  @override
  void initState() {
    super.initState();
    _apiKeyCtrl = TextEditingController();
    _fastApiUrlCtrl.text = ref.read(apiClientProvider).baseUrl;
    _checkFastApi();
    _loadApiKey();
  }

  @override
  void dispose() {
    _fastApiUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('anthropic_api_key') ?? '';
    if (!mounted) return;
    setState(() {
      _apiKeyCtrl.text = key;
      _isApiKeyValid = key.startsWith('sk-ant-');
      _apiKeyReady = true;
    });
  }

  Future<void> _checkFastApi() async {
    setState(() => _fastApiChecking = true);
    final ok = await ref.read(apiClientProvider).checkConnection();
    if (!mounted) return;
    setState(() {
      _fastApiConnected = ok;
      _fastApiChecking = false;
    });
  }

  Future<void> _save() async {
    await ref.read(apiClientProvider).setBaseUrl(_fastApiUrlCtrl.text.trim());
    await _checkFastApi();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정이 저장됐습니다.')),
      );
    }
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyCtrl.text.trim();

    if (key.isNotEmpty && !key.startsWith('sk-ant-')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('올바른 Anthropic API 키 형식이 아닙니다. (sk-ant-... 로 시작)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // SharedPreferences 저장
    final prefs = await SharedPreferences.getInstance();
    if (key.isEmpty) {
      await prefs.remove('anthropic_api_key');
    } else {
      await prefs.setString('anthropic_api_key', key);
    }

    // 서버에 API 키 전달
    try {
      await ref.read(apiClientProvider).post(
        '/api/settings/api-key',
        data: {'api_key': key},
      );
      if (!mounted) return;
      setState(() => _isApiKeyValid = key.startsWith('sk-ant-'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(key.isEmpty ? 'API 키가 제거됐습니다.' : 'API 키가 저장됐습니다.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isApiKeyValid = key.startsWith('sk-ant-'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            key.isEmpty
                ? 'API 키 제거됨 (서버 적용 실패 — 재시작 필요)'
                : 'API 키 저장됨 (서버 적용 실패 — 재시작 필요)\n$e',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── FastAPI 서버 ─────────────────────────────────────────────
            const _SectionTitle('FastAPI 서버 (v4.0)'),
            const SizedBox(height: 6),
            _ConnectionStatus(
              checking: _fastApiChecking,
              connected: _fastApiConnected,
              label: 'FastAPI',
              onRecheck: _checkFastApi,
            ),
            const SizedBox(height: 10),
            const Text(
              'Windows: http://127.0.0.1:9000\n'
              'Android/iOS: http://PC의IP주소:9000',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _fastApiUrlCtrl,
              decoration: const InputDecoration(
                hintText: 'http://127.0.0.1:9000',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('저장 및 연결 확인'),
              ),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // ── Anthropic API 키 ─────────────────────────────────────────
            const _SectionTitle('AI 설정'),
            const SizedBox(height: 12),
            if (!_apiKeyReady)
              const Center(child: CircularProgressIndicator())
            else
              AppCard(
                elevated: true,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.key, size: 17,
                          color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Anthropic API 키',
                          style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(width: 8),
                      _ApiKeyBadge(valid: _isApiKeyValid),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      'AI 온톨로지 생성 · 트리플 추출에 사용됩니다.',
                      style: AppTypography.caption,
                    ),
                      const SizedBox(height: 12),

                      // API 키 입력창 + 저장 버튼
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _apiKeyCtrl,
                            obscureText: !_isApiKeyVisible,
                            decoration: InputDecoration(
                              hintText: 'sk-ant-api03-...',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isApiKeyVisible
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  size: 18,
                                ),
                                onPressed: () => setState(
                                    () => _isApiKeyVisible = !_isApiKeyVisible),
                              ),
                            ),
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 13),
                            onChanged: (v) => setState(() =>
                                _isApiKeyValid = v.trim().startsWith('sk-ant-')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saveApiKey,
                          child: const Text('저장'),
                        ),
                      ]),

                      const SizedBox(height: 12),
                      Text(
                        '• Anthropic Console(console.anthropic.com)에서 발급\n'
                        '• 저장 즉시 서버에 적용됩니다\n'
                        '• 키는 이 기기에만 저장됩니다 (서버 전송 없음)',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
              ),

            const SizedBox(height: 32),

            const Divider(),
            const SizedBox(height: 16),

            // ── 앱 정보 ─────────────────────────────────────────────────
            const _SectionTitle('앱 정보'),
            const SizedBox(height: 12),
            const _InfoRow('버전', 'v4.0.0'),
            const _InfoRow('백엔드', 'FastAPI + SQLite'),
            const _InfoRow('AI 모델', 'Claude Sonnet 4.6'),
            const _InfoRow('플랫폼', 'Windows / Android / iOS'),
          ],
        ),
      ),
    );
  }
}

// ── API 키 배지 ───────────────────────────────────────────────────────────────

class _ApiKeyBadge extends StatelessWidget {
  final bool valid;
  const _ApiKeyBadge({required this.valid});

  @override
  Widget build(BuildContext context) {
    final color = valid ? AppColors.confirmed : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        valid ? '설정됨' : '미설정',
        style: AppTypography.badge.copyWith(color: color),
      ),
    );
  }
}

// ── 보조 위젯 ─────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 3, height: 16,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(text, style: AppTypography.heading2),
    ]);
  }
}

class _ConnectionStatus extends StatelessWidget {
  final bool checking;
  final bool connected;
  final String label;
  final VoidCallback onRecheck;
  const _ConnectionStatus({
    required this.checking,
    required this.connected,
    required this.label,
    required this.onRecheck,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(
        checking
            ? Icons.sync
            : connected ? Icons.check_circle : Icons.error,
        color: checking
            ? AppColors.textMuted
            : connected ? AppColors.confirmed : AppColors.error,
        size: 17,
      ),
      const SizedBox(width: 8),
      Text(
        checking
            ? '연결 확인 중...'
            : connected ? '$label 연결됨' : '$label 연결 실패',
        style: AppTypography.body.copyWith(
            color: checking
                ? AppColors.textMuted
                : connected ? AppColors.confirmed : AppColors.error),
      ),
      const SizedBox(width: 12),
      TextButton(onPressed: onRecheck, child: const Text('재확인')),
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(
          width: 80,
          child: Text(label, style: AppTypography.caption),
        ),
        Text(value, style: AppTypography.body.copyWith(
            color: AppColors.textPrimary)),
      ]),
    );
  }
}
