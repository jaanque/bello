import 'package:bello/notification_service.dart'; // Adjust import path if necessary
import 'package:flutter/material.dart';
import 'home_screen.dart';

// Define color constants
const Color lilacPastel = Color(0xFFE6E6FA);
const Color goldPastel = Color(0xFFFFFACD);

Future<void> main() async { // Make main async
  WidgetsFlutterBinding.ensureInitialized(); // Required before calling native code
  await NotificationService.initialize(); // Initialize notifications
  // Optional: Schedule reminder on app startup if not already handled robustly
  // This ensures it's set if the app was closed and reopened.
  // However, if _hasRecordedToday is true, we should not schedule it.
  // This logic is better placed in HomeScreen's initState after checking _hasRecordedToday.
  runApp(const BelloApp());
}

class BelloApp extends StatelessWidget {
  const BelloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bello',
      theme: ThemeData(
        primarySwatch: Colors.grey, // Base for shades
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.white,
        canvasColor: Colors.grey[100], // Soft grey for backgrounds
        // Define a text theme for elegance
        textTheme: const TextTheme(
          headlineLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(color: Colors.black87),
        ),
        // Define specific themes for recap banners if needed later
        // For now, colors are defined as constants
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0, // Clean look
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(),
    );
  }
}
