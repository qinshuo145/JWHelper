import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/auth_provider.dart';
import 'providers/data_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProxyProvider<AuthProvider, DataProvider>(
          create: (_) => DataProvider(),
          update: (_, auth, data) => data!..updateUsername(auth.currentUsername),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: '教务小助手',
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF409EFF),
                primary: const Color(0xFF409EFF),
                surface: const Color(0xFFF5F7FA),
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: const Color(0xFFF5F7FA),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
              ),
              navigationBarTheme: const NavigationBarThemeData(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
              ),
              cardTheme: const CardThemeData(
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
              ),
              useMaterial3: true,
              textTheme: GoogleFonts.notoSansTextTheme(),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF409EFF),
                primary: const Color(0xFF409EFF),
                brightness: Brightness.dark,
                surface: const Color(0xFF121212),
              ),
              scaffoldBackgroundColor: const Color(0xFF121212),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF1E1E1E),
                surfaceTintColor: Colors.transparent,
              ),
              navigationBarTheme: const NavigationBarThemeData(
                backgroundColor: Color(0xFF1E1E1E),
                surfaceTintColor: Colors.transparent,
              ),
              cardTheme: const CardThemeData(
                color: Color(0xFF1E1E1E),
                surfaceTintColor: Colors.transparent,
              ),
              useMaterial3: true,
              textTheme: GoogleFonts.notoSansTextTheme(ThemeData.dark().textTheme),
            ),
            home: const LoginScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
