import 'package:sipsdk_flutter/sipsdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/home_bloc.dart';
import 'bloc/sip_bloc.dart';
import 'screens/home_screen.dart';
import 'theme/theme.dart';
import 'theme/util.dart';
import 'watch_ui/watch_home_screen.dart';
import 'features/user_profiles/bloc/user_profiles_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Read saved config asynchronously during startup
  // (without permission requests blocking main to prevent black screen)
  final client = SipClient.instance;
  Map<String, dynamic>? savedConfig;
  try {
    if (await client.hasStoredCredentials()) {
      savedConfig = await client.getStoredConfig();
    }
  } catch (e) {
    debugPrint('Error reading stored credentials on startup: $e');
  }

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<SipBloc>(
          create: (context) {
            final bloc = SipBloc();
            if (savedConfig != null) {
              final config = SipConfig.fromMap(
                Map<String, dynamic>.from(savedConfig),
              );
              bloc.add(InitializeAndLoginSip(config));
            }
            // Request permissions after app UI mounts
            bloc.add(const RequestPermissionsSip());
            return bloc;
          },
        ),
        BlocProvider<HomeBloc>(create: (_) => HomeBloc()),
        BlocProvider<UserProfilesBloc>(
          create: (_) => UserProfilesBloc()..add(const UserProfilesLoad()),
        ),
      ],
      child: const SipApp(),
    ),
  );
}

class SipApp extends StatelessWidget {
  const SipApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = createTextTheme(context, "Roboto Slab", "Poppins");
    return MaterialApp(
      title: 'Sip VoIP',
      debugShowCheckedModeBanner: false,
      theme: MaterialTheme(textTheme).light(),
      darkTheme: MaterialTheme(textTheme).dark(),
      themeMode: ThemeMode.system,
      home: LayoutBuilder(
        builder: (context, constraints) {
          // Detect watch based on typical screen width (< 350)
          if (constraints.maxWidth < 350) {
            return const WatchHomeScreen();
          }
          return const HomeScreen();
        },
      ),
    );
  }
}
