import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/api_client.dart';
import '../../api/ontology_api.dart';
import '../../providers/hive_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _fastApiUrlCtrl = TextEditingController();
  final _hiveUrlCtrl = TextEditingController();

  bool _fastApiConnected = false;
  bool _fastApiChecking = false;
  bool _hiveConnected = false;
  bool _hiveChecking = false;

  @override
  void initState() {
    super.initState();
    _fastApiUrlCtrl.text = ref.read(apiClientProvider).baseUrl;
    _hiveUrlCtrl.text = ref.read(hiveUrlProvider);
    _checkFastApi();
  }

  @override
  void dispose() {
    _fastApiUrlCtrl.dispose();
    _hiveUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkFastApi() async {
    setState(() => _fastApiChecking = true);
    final ok = await ref.read(apiClientProvider).checkConnection();
    setState(() {
      _fastApiConnected = ok;
      _fastApiChecking = false;
    });
  }

  Future<void> _checkHive() async {
    setState(() => _hiveChecking = true);
    final url = _hiveUrlCtrl.text.trim();
    final ok = await HiveApi(url).checkConnection();
    setState(() {
      _hiveConnected = ok;
      _hiveChecking = false;
    });
  }

  Future<void> _save() async {
    // FastAPI URL 저장
    await ref
        .read(apiClientProvider)
        .setBaseUrl(_fastApiUrlCtrl.text.trim());

    // Hive URL 저장
    final hiveUrl = _hiveUrlCtrl.text.trim();
    ref.read(hiveUrlProvider.notifier).state = hiveUrl;
    await saveHiveUrl(hiveUrl);

    // 연결 재확인
    await Future.wait([_checkFastApi(), _checkHive()]);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정이 저장됐습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('서버 설정')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── FastAPI 서버 ───────────────────────────────────────────────
            _SectionTitle('FastAPI 서버 (v4.0)'),
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

            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 16),

            // ── Hive DB 서버 (v3.0) ───────────────────────────────────────
            _SectionTitle('Hive DB 서버 (v3.0)'),
            const SizedBox(height: 6),
            _ConnectionStatus(
              checking: _hiveChecking,
              connected: _hiveConnected,
              label: 'Hive DB',
              onRecheck: _checkHive,
            ),
            const SizedBox(height: 10),
            const Text(
              '구술기록 입력 시 Hive DB 탭에서 사용합니다.\n'
              '미사용 시 빈칸으로 두세요.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _hiveUrlCtrl,
              decoration: const InputDecoration(
                hintText: 'http://192.168.0.x:8000',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 32),
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

            // ── 앱 정보 ───────────────────────────────────────────────────
            _SectionTitle('앱 정보'),
            const SizedBox(height: 12),
            _InfoRow('버전', 'v4.0.0'),
            _InfoRow('백엔드', 'FastAPI + uvicorn'),
            _InfoRow('AI 모델', 'Claude Sonnet 4.6'),
            _InfoRow('플랫폼', 'Windows / Android / iOS'),
          ],
        ),
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
    return Text(text,
        style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Theme.of(context).colorScheme.primary));
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
            : connected
                ? Icons.check_circle
                : Icons.error,
        color: checking
            ? Colors.grey
            : connected
                ? Colors.green
                : Colors.red,
        size: 18,
      ),
      const SizedBox(width: 8),
      Text(
        checking
            ? '연결 확인 중...'
            : connected
                ? '$label 연결됨'
                : '$label 연결 실패',
        style: TextStyle(
            color: checking
                ? Colors.grey
                : connected
                    ? Colors.green
                    : Colors.red),
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
          child: Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ),
        Text(value, style: const TextStyle(fontSize: 13)),
      ]),
    );
  }
}
