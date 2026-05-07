import 'package:flutter/material.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/progress.dart';
import 'services/scraper.dart';
import 'services/daily.dart';
import 'services/dictionary.dart';
import 'services/pronunciation.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

late final ProgressService progress;
late final Scraper scraper;
late final DailyService daily;
late final DictionaryService dictionary;
late final PronunciationService pronunciation;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env missing — dictionary lookups will surface a clear error
  }
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.speech());
  progress = ProgressService();
  await progress.load();
  scraper = Scraper();
  daily = DailyService(scraper: scraper, progress: progress);
  dictionary = DictionaryService();
  pronunciation = PronunciationService();
  runApp(const DictationApp());
}

class DictationApp extends StatelessWidget {
  const DictationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dictation Loop',
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}
