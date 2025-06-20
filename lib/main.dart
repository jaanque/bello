import 'package:flutter/material.dart';
import 'home_screen.dart'; // We'll create this next

// Define color constants
const Color lilacPastel = Color(0xFFE6E6FA);
const Color goldPastel = Color(0xFFFFFACD);

void main() {
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
