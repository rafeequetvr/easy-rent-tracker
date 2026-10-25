import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() => runApp(const EasyRentApp());

const _blue = Color(0xFF2563EB);

class EasyRentApp extends StatelessWidget {
  const EasyRentApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'EasyRent Tracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: _blue, useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFF7F8FA)),
        home: const PropertyHome(),
      );
}