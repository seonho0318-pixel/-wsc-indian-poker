import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://ysqoniyktezzahqtllnl.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlzcW9uaXlrdGV6emFocXRsbG5sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMzOTMyMTUsImV4cCI6MjEwODk2OTIxNX0.plizedd_bPr17fnl0PF-kPYfwgIHDDUK6j0xBSI7TiM';

  static Future<void> init() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
}

final supabase = Supabase.instance.client;
