import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';
import 'turismo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://sodlregonixbebwnvdxf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvZGxyZWdvbml4YmVid252ZHhmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgyOTcyNTgsImV4cCI6MjA2Mzg3MzI1OH0.eyan4TXu8A1vo5YkedqofqvgC_NvmEkkgbBIXHGndak',
  );

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDvOBWeYMwHPnHfGvrHyRnKxnlHamVaZ_c",
      authDomain: "fir-flutter-c379e.firebaseapp.com",
      projectId: "fir-flutter-c379e",
      storageBucket: "fir-flutter-c379e.firebasestorage.app",
      messagingSenderId: "872025376242",
      appId: "1:872025376242:web:5fe1a741d0e4e8e854976b",
    )

  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supabase Upload App',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/turismo': (context) => const TurismoPage(),
      },
    );
  }
}