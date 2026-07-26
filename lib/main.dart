// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Screens
import 'screens/home_screen.dart';
import 'screens/send_options_screen.dart';
import 'screens/discovery_screen.dart';
import 'screens/payment_input_screen.dart';
import 'screens/receive_screen.dart';
import 'screens/custom_qr_screen.dart';
import 'screens/qr_scanner_screen.dart';

// Services & Models
import 'services/bluetooth_service.dart';
import 'models/wallet_model.dart';
import 'models/transaction_model.dart';
import 'models/trusted_contact.dart';
import 'screens/security_settings_screen.dart';
import 'screens/appearance_screen.dart';
import 'screens/pin_settings_screen.dart';
import 'screens/about_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/contacts_screen.dart';

import 'screens/login_screen.dart';
import 'services/profile_service.dart';
import 'services/reward_service.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(TransactionModelAdapter());
  }

  // Initialize Trusted Contacts Hive box & Rewards Service
  await TrustedContactService.init();
  await RewardService.init();
  
  final bool isLoggedIn = await ProfileService.isLoggedIn();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => OffpayBluetoothService(),
        ),
        ChangeNotifierProvider(
          create: (context) => WalletModel(),
        ),
        ChangeNotifierProvider(
          create: (context) => ThemeProvider(),
        ),
      ],
      child: OffPayApp(isLoggedIn: isLoggedIn),
    ),
  );
}

class OffPayApp extends StatelessWidget {
  final bool isLoggedIn;
  const OffPayApp({super.key, this.isLoggedIn = false});

  ThemeData _buildLightTheme(Color accentColor, double fontScale, bool useAppleFont) {
    final String? family = useAppleFont ? '.SF Pro Display' : 'Roboto';
    final List<String>? fallbacks = useAppleFont
        ? const [
            '.SF UI Display',
            '.SF UI Text',
            '-apple-system',
            'BlinkMacSystemFont',
            'SF Pro Display',
            'SF Pro Text',
            'CupertinoSystemDisplay',
            'CupertinoSystemText',
            'Helvetica Neue',
            'Helvetica',
            'Arial',
            'sans-serif',
          ]
        : const ['sans-serif'];

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: accentColor,
      scaffoldBackgroundColor: Colors.white,
      fontFamily: family,
      fontFamilyFallback: fallbacks,
      appBarTheme: AppBarTheme(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: ThemeData.light().textTheme.apply(
        fontSizeFactor: fontScale,
        fontFamily: family,
        fontFamilyFallback: fallbacks,
      ),
    );
  }

  ThemeData _buildDarkTheme(Color accentColor, double fontScale, bool useAppleFont) {
    final String? family = useAppleFont ? '.SF Pro Display' : 'Roboto';
    final List<String>? fallbacks = useAppleFont
        ? const [
            '.SF UI Display',
            '.SF UI Text',
            '-apple-system',
            'BlinkMacSystemFont',
            'SF Pro Display',
            'SF Pro Text',
            'CupertinoSystemDisplay',
            'CupertinoSystemText',
            'Helvetica Neue',
            'Helvetica',
            'Arial',
            'sans-serif',
          ]
        : const ['sans-serif'];

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: accentColor,
      scaffoldBackgroundColor: const Color(0xFF000000), // Pure AMOLED Black
      fontFamily: family,
      fontFamilyFallback: fallbacks,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF000000),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E2C),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: accentColor,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white54),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
        ),
      ),
      textTheme: ThemeData.dark().textTheme.apply(
        fontSizeFactor: fontScale,
        fontFamily: family,
        fontFamilyFallback: fallbacks,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'OFF-PAY',
      theme: _buildLightTheme(
        themeProvider.accentColor,
        themeProvider.fontSizeScale,
        themeProvider.useAppleFont,
      ),
      darkTheme: _buildDarkTheme(
        themeProvider.accentColor,
        themeProvider.fontSizeScale,
        themeProvider.useAppleFont,
      ),
      themeMode: themeProvider.themeMode,

      initialRoute: isLoggedIn ? '/home' : '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),

        // static route: SendOptions and others that don't require constructor args
        '/send_options': (context) => const SendOptionsScreen(),
        '/discovery': (context) => const DiscoveryScreen(),
        '/payment_input': (context) => const PaymentInputScreen(),
        '/receive': (context) => const ReceiveScreen(),
        '/custom_qr': (context) => const CustomQrScreen(),
        '/qr_scanner': (context) => const QRScannerScreen(),
        '/security_settings': (context) => const SecuritySettingsScreen(),
        '/appearance': (context) => const AppearanceScreen(),
        '/pin_settings': (context) => const PinSettingsScreen(),
        '/about': (context) => const AboutScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/contacts': (context) => const ContactsScreen(),

        // NOTE: PaymentSuccessScreen often needs runtime arguments (amount, recipient, etc.)
        // It's safer to navigate to that screen using MaterialPageRoute and pass required args:
        // Navigator.push(context, MaterialPageRoute(
        //   builder: (_) => PaymentSuccessScreen(amount: 100.0, recipientName: 'Alex'),
        // ));
        //
        // Keep the named route out if your PaymentSuccessScreen requires constructor args.
      },
    );
  }
}
