import 'package:flutter/material.dart';

import 'screens/genealogy_home_screen.dart';

class GenealogyApp extends StatefulWidget {
  const GenealogyApp({super.key});

  @override
  State<GenealogyApp> createState() => _GenealogyAppState();
}

class _GenealogyAppState extends State<GenealogyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      title: 'Gia Phả',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: GenealogyHomeScreen(
        navigatorKey: _navigatorKey,
        messengerKey: _messengerKey,
      ),
    );
  }
}
