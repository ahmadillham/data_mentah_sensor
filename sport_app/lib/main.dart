import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'data/models/user_profile.dart';
import 'data/repositories/workout_repository.dart';
import 'providers/workout_provider.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Initialize Repositories
  final workoutRepo = WorkoutRepository();
  await workoutRepo.init();

  final profileRepo = UserProfileRepository();
  await profileRepo.init();

  runApp(
    ProviderScope(
      overrides: [
        workoutRepositoryProvider.overrideWithValue(workoutRepo),
        userProfileRepoProvider.overrideWithValue(profileRepo),
      ],
      child: SportApp(isOnboarded: profileRepo.isOnboarded, profileRepo: profileRepo),
    ),
  );
}

class SportApp extends StatelessWidget {
  final bool isOnboarded;
  final UserProfileRepository profileRepo;

  const SportApp({
    super.key,
    required this.isOnboarded,
    required this.profileRepo,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SportTracker',
      theme: AppTheme.darkTheme,
      home: isOnboarded
          ? const HomeScreen()
          : OnboardingScreen(
              onComplete: () async {
                await profileRepo.setOnboarded();
              },
            ),
      debugShowCheckedModeBanner: false,
    );
  }
}
