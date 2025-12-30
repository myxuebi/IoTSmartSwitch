import 'package:flutter/material.dart';
import 'package:mobile/page/firstPage.dart';
import 'package:mobile/page/indexPage.dart';

void main() {
  // WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Esp32 APP',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue),
          ),
        ),
        cardTheme: const CardThemeData(color: Colors.white),
      ),
      onGenerateRoute: (RouteSettings settings) {
        return _generateRoute(settings);
      },
      initialRoute: '/',
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    final String? routeName = settings.name;

    if (routeName == null) {
      return _buildRoute(NotFoundPage(), settings);
    }
    if (routeName == '/') {
      return _buildRoute(firstPage(), settings);
    }
    if (routeName == '/index'){
      return _buildRoute(Indexpage(), settings);
    }

    return _buildRoute(NotFoundPage(), settings);
  }

  PageRoute _buildRoute(Widget page, RouteSettings settings) {
    return MaterialPageRoute(builder: (context) => page, settings: settings);
  }
}

class NotFoundPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('页面未找到')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('404 - 页面未找到', style: TextStyle(fontSize: 24)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed:
                  () => Navigator.pushReplacementNamed(context, '/'),
              child: Text('返回首页'),
            ),
          ],
        ),
      ),
    );
  }
}