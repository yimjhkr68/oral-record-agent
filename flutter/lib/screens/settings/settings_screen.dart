import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/api_client.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _urlController = TextEditingController();
  bool _isConnected = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    final client = ref.read(apiClientProvider);
    _urlController.text = client.baseUrl;
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    setState(() => _checking = true);
    final client = ref.read(apiClientProvider);
    final ok = await client.checkConnection();
    setState(() {
      _isConnected = ok;
      _checking = false;
    });
  }

  Future<void> _save() async {
    final client = ref.read(apiClientProvider);
    await client.setBaseUrl(_urlController.text.trim());
    await _checkConnection();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정이 저장됐습니다.')),
      );
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('서버 설정')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(
                _checking
                    ? Icons.sync
                    : _isConnected
                        ? Icons.check_circle
                        : Icons.error,
                color: _checking
                    ? Colors.grey
                    : _isConnected
                        ? Colors.green
                        : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(_checking
                  ? '연결 확인 중...'
                  : _isConnected
                      ? 'FastAPI 서버 연결됨'
                      : '서버에 연결할 수 없음'),
              const SizedBox(width: 16),
              TextButton(
                  onPressed: _checkConnection, child: const Text('재연결')),
            ]),
            const SizedBox(height: 24),
            const Text('FastAPI 서버 주소',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
                'Windows: http://127.0.0.1:9000\nAndroid/iOS: http://PC의IP주소:9000',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText: 'http://127.0.0.1:9000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              child: const Text('저장 및 연결 확인'),
            ),
          ],
        ),
      ),
    );
  }
}
