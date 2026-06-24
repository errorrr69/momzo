import 'package:flutter/material.dart';

import 'core/supabase/supabase_init.dart';
import 'core/theme/momzo_colors.dart';
import 'core/theme/momzo_text.dart';
import 'services/auth_service.dart';

// Onboarding
import 'features/onboarding/welcome_screen.dart';
import 'features/onboarding/sign_in_screen.dart';
import 'features/onboarding/child_basics_screen.dart';
import 'features/onboarding/child_temperament_screen.dart';
import 'features/onboarding/all_set_screen.dart';
import 'features/onboarding/consent_screen.dart';
import 'features/onboarding/delete_child_screen.dart';
// Home & daily
import 'features/home/home_screen.dart';
import 'features/daily/daily_card_screen.dart';
import 'features/daily/daily_slides_screen.dart';
import 'features/daily/library_screen.dart';
// AI
import 'features/ai/ai_home_screen.dart';
import 'features/ai/ai_chat_screen.dart';
import 'features/ai/situational_screen.dart';
import 'features/ai/refer_out_screen.dart';
// Activities
import 'features/activities/activities_list_screen.dart';
import 'features/activities/activity_detail_screen.dart';
import 'features/activities/activity_complete_screen.dart';
// Bonding
import 'features/bonding/together_hub_screen.dart';
import 'features/bonding/daily_question_screen.dart';
import 'features/bonding/quiz_match_screen.dart';
// Wishes
import 'features/wishes/wish_wall_screen.dart';
import 'features/wishes/schedule_wish_screen.dart';
import 'features/wishes/calendar_screen.dart';
// Continuity
import 'features/timeline/memory_timeline_screen.dart';
import 'features/timeline/weekly_recap_screen.dart';
import 'features/reminders/reminders_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Connects to Supabase when build-time env is provided; otherwise the app
  // runs UI-only so the screen gallery still works without a backend.
  final connected = await initSupabase();
  // Keep the parent's profile row in sync on every sign-in (Task 5).
  if (connected) AuthService.startProfileSync();
  runApp(const MomzoApp());
}

class MomzoApp extends StatelessWidget {
  const MomzoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Momzo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: MomzoColors.cream,
        colorScheme: ColorScheme.fromSeed(
          seedColor: MomzoColors.coral,
          primary: MomzoColors.coral,
          surface: MomzoColors.cream,
        ),
        useMaterial3: true,
      ),
      // The gallery is a dev entry point to preview every screen.
      // In production, start at WelcomeScreen().
      home: const ScreenGallery(),
    );
  }
}

class _Entry {
  final String number;
  final String label;
  final WidgetBuilder builder;
  const _Entry(this.number, this.label, this.builder);
}

class _Section {
  final String letter;
  final String title;
  final List<_Entry> entries;
  const _Section(this.letter, this.title, this.entries);
}

/// A simple index of all 25 screens, grouped by feature area.
class ScreenGallery extends StatelessWidget {
  const ScreenGallery({super.key});

  static final _sections = <_Section>[
    _Section('A', 'Onboarding & Child Profile', [
      _Entry('01', 'Welcome', (_) => const WelcomeScreen()),
      _Entry('02', 'Sign up / log in', (_) => const SignInScreen()),
      _Entry('03', 'About your child', (_) => const ChildBasicsScreen()),
      _Entry('04', 'Temperament & focus',
          (_) => const ChildTemperamentScreen(childName: 'Aarav')),
      _Entry('05', 'All set', (_) => const AllSetScreen(childName: 'Aarav')),
      _Entry('C1', 'Parental consent (COPPA)', (_) => const ConsentScreen()),
      _Entry('C2', 'Delete child & all data',
          (_) => const DeleteChildScreen(childName: 'Aarav')),
    ]),
    _Section('B', 'Home & Daily Learning', [
      _Entry('06', 'Home · Today', (_) => const HomeScreen()),
      _Entry('07', 'Daily card · read', (_) => const DailyCardScreen()),
      _Entry('08', 'Card · slide format', (_) => const DailySlidesScreen()),
      _Entry('09', 'Learn · library', (_) => const LibraryScreen()),
    ]),
    _Section('C', 'AI Child Expert', [
      _Entry('10', 'Ask · home', (_) => const AiHomeScreen()),
      _Entry('11', 'Ask · grounded answer', (_) => const AiChatScreen()),
      _Entry('12', 'Right now · calm script', (_) => const SituationalScreen()),
      _Entry('13', 'Safety · refer-out', (_) => const ReferOutScreen()),
    ]),
    _Section('D', 'Activities', [
      _Entry('14', 'Activities · time filter',
          (_) => const ActivitiesListScreen()),
      _Entry('15', 'Activity · how to do it',
          (_) => const ActivityDetailScreen()),
      _Entry('16', 'Did it · photo & note',
          (_) => const ActivityCompleteScreen()),
    ]),
    _Section('E', 'Bonding & Together-Games', [
      _Entry('17', 'Together · hub', (_) => const TogetherHubScreen()),
      _Entry('18', 'Question · reveal', (_) => const DailyQuestionScreen()),
      _Entry('19', 'Know-each-other · match', (_) => const QuizMatchScreen()),
    ]),
    _Section('F', 'Kid Wish Wall & Together-Time', [
      _Entry('20', 'Kid mode · Wish Wall', (_) => const WishWallScreen()),
      _Entry('21', 'Plan a together-time', (_) => const ScheduleWishScreen()),
      _Entry('22', 'Calendar · together-time', (_) => const CalendarScreen()),
    ]),
    _Section('G', 'Memories, Recap & Reminders', [
      _Entry('23', 'Memory Timeline', (_) => const MemoryTimelineScreen()),
      _Entry('24', 'Weekly recap', (_) => const WeeklyRecapScreen()),
      _Entry('25', 'Reminders & quiet hours', (_) => const RemindersScreen()),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9E1D6),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Text.rich(
              TextSpan(
                text: 'momzo',
                style: MomzoText.sans(32,
                    color: MomzoColors.coral, weight: FontWeight.w900, spacing: -1),
                children: [
                  TextSpan(
                    text: '.',
                    style: MomzoText.sans(32,
                        color: MomzoColors.sage, weight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text('Screen gallery · 25 screens · tap any to preview',
                style: MomzoText.sans(13,
                    color: const Color(0xFF8C7E76), weight: FontWeight.w700)),
            const SizedBox(height: 24),
            for (final section in _sections) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('${section.letter} · ${section.title}',
                    style: MomzoText.sans(13,
                        color: const Color(0xFF7A6B61), weight: FontWeight.w900)
                        .copyWith(letterSpacing: 1)),
              ),
              for (final e in section.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _row(context, e),
                ),
              const SizedBox(height: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, _Entry e) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: e.builder),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x0F342F30), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Text(e.number,
                style: MomzoText.sans(14,
                    color: MomzoColors.coral, weight: FontWeight.w900)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(e.label,
                  style: MomzoText.sans(15,
                      color: MomzoColors.ink, weight: FontWeight.w700)),
            ),
            const Icon(Icons.chevron_right_rounded, color: MomzoColors.faint),
          ],
        ),
      ),
    );
  }
}
