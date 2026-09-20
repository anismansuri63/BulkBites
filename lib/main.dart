
import 'package:bulk_bites/screens/User/SplashScreen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'model/CartItem.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(options:
    FirebaseOptions(apiKey: 'AIzaSyCfc8UKeVkz5bYyK7geeOrtvksMWG9jo84',
        appId: "1:208744369341:web:f83b0a886cc8f9683cbbd4",
        messagingSenderId: "208744369341",
        projectId: 'bulkbites-236a8'));
  } else {
    await Firebase.initializeApp();
  }
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Set system UI overlay style for better edge-to-edge support
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => CartManager()),
      ],
      child: MyApp(),
    ),
  );

}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SwiftOrder',
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        useMaterial3: true,
      ),
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // Dismiss keyboard when tapping outside a text field
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: child,
        );
      },
      home: const SplashScreen(),
      //home: const MyHomePage(title: 'Bulk Bites'),
    );
  }
}