import 'package:sipsdk_flutter/sipsdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import 'bloc/home_bloc.dart';
import 'bloc/sip_bloc.dart';
import 'screens/home_screen.dart';
import 'theme/theme.dart';
import 'theme/util.dart';
import 'watch_ui/watch_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Request required runtime permissions on app launch
  await [
    Permission.microphone,
    Permission.phone,
    Permission.notification,
  ].request();

  // Check if credentials are stored in SDK (via DataStore)
  final client = SipClient.instance;
  final hasCredentials = await client.hasStoredCredentials();
  Map<String, dynamic>? savedConfig;

  if (hasCredentials) {
    savedConfig = await client.getStoredConfig();
  }

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<SipBloc>(
          create: (context) {
            final bloc = SipBloc();
            if (savedConfig != null) {
              final config = SipConfig.fromMap(savedConfig);
              bloc.add(InitializeAndLoginSip(config));
            }
            return bloc;
          },
        ),
        BlocProvider<HomeBloc>(create: (_) => HomeBloc()),
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
