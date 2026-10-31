import 'package:flutter/material.dart';
import 'supabase_config.dart';
import 'lobby_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedCountry = 'KR 🇰🇷';
  bool _isLoading = false;

  final List<String> _countries = ['KR 🇰🇷', 'US 🇺🇸', 'JP 🇯🇵', 'CN 🇨🇳', 'GB 🇬🇧', 'DE 🇩🇪'];

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showMsg('아이디와 비밀번호를 입력해 주세요.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await supabase
          .from('users')
          .select()
          .eq('username', username)
          .eq('password', password)
          .maybeSingle();

      if (response != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LobbyScreen(userData: response)),
        );
      } else {
        _showMsg('아이디 또는 비밀번호가 올바르지 않습니다.');
      }
    } catch (e) {
      _showMsg('DB 접속 오류: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegister() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showMsg('아이디와 비밀번호를 입력해 주세요.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // pre / bignaughty 계정은 자동으로 관리자 👑 부여
      final bool isAdmin = (username == 'pre' && password == 'bignaughty');

      await supabase.from('users').insert({
        'username': username,
        'password': password,
        'country': _selectedCountry,
        'is_admin': isAdmin,
        'wins': 0,
        'draws': 0,
        'losses': 0,
        'points': 0,
      });

      _showMsg(isAdmin ? '👑 WSC 관리자 계정 생성 완료!' : '회원가입 성공! 로그인해 주세요.');
    } catch (e) {
      _showMsg('이미 존재하는 아이디이거나 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMsg(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('☕ WSC World Indian Poker')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.public, size: 80, color: Colors.brown),
              const SizedBox(height: 12),
              const Text(
                'World Study Cafe Championship',
                style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              const Text(
                'WSC Global Indian Poker',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _selectedCountry,
                decoration: const InputDecoration(labelText: '국가 선택 (Country)', border: OutlineInputBorder()),
                items: _countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setState(() => _selectedCountry = val!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: '선수 닉네임 (Username)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '비밀번호 (Password)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white),
                        onPressed: _isLoading ? null : _handleLogin,
                        child: const Text('로그인'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        child: const Text('회원가입'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
