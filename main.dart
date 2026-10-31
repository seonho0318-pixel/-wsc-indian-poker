import 'package:flutter/material.dart';
import 'supabase_config.dart';
import 'login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.init();
  runApp(const WSCGlobalApp());
}

class WSCGlobalApp extends StatelessWidget {
  const WSCGlobalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WSC World Indian Poker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber, primary: Colors.brown),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
