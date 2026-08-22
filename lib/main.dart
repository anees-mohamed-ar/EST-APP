import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'views/login_page.dart';
import 'views/home_page.dart';
import 'views/camera_page.dart';
import 'views/daily_attendance_page.dart';
import 'views/admin_attendance_page.dart';
import 'views/admin_groupings_page.dart';
import 'views/monthly_summary_page.dart';
import 'views/admin_monthly_summary_new_page.dart';
import 'views/admin_dashboard_page.dart';
import 'views/sites_page.dart';
import 'views/splash_screen.dart';
import 'views/holidays_page.dart';
import 'views/leaderboard_page.dart';
import 'views/profile_page.dart';
import 'views/vehicle_page.dart';
import 'views/admin_vehicle_reports_page.dart';
import 'views/leave_page.dart';
import 'views/permission_page.dart';
import 'views/hierarchy_management_page.dart';
import 'views/long_absentees_page.dart';
// import 'views/payroll_download_page.dart'; // commented out — replaced by payslip_page.dart
import 'views/payslip_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  await dotenv.load(fileName: ".env");

  debugPaintBaselinesEnabled = false;
  debugPaintSizeEnabled = false;
  debugPaintPointersEnabled = false;
  debugPaintLayerBordersEnabled = false;
  debugRepaintRainbowEnabled = false;

  // Boost image cache so network images don't re-decode on every navigation
  PaintingBinding.instance.imageCache.maximumSize = 200;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20; // 100 MB

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MyApp(initialRoute: '/splash'));
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'MEPL-Track',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      initialRoute: initialRoute,
      // rightToLeft is GPU-composited (slide layer) — much faster than fadeIn
      defaultTransition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 220),
      // Smooth fling physics everywhere
      scrollBehavior: const _SmoothScrollBehavior(),
      getPages: [
        GetPage(name: '/fleet-reports', page: () => AdminVehicleReportsPage()),
        GetPage(name: '/splash', page: () => SplashScreen()),
        GetPage(name: '/', page: () => LoginPage()),
        GetPage(name: '/login', page: () => LoginPage()),
        GetPage(name: '/home', page: () => HomePage()),
        GetPage(
          name: '/camera',
          page: () => CameraPage(),
          transition: Transition.downToUp,
          transitionDuration: const Duration(milliseconds: 200),
        ),
        GetPage(name: '/daily-attendance', page: () => DailyAttendancePage()),
        GetPage(name: '/admin-attendance', page: () => AdminAttendancePage()),

        GetPage(name: '/admin-dashboard', page: () => AdminDashboardPage()),
        GetPage(name: '/admin-sites', page: () => SitesPage()),
        GetPage(name: '/monthly-summary', page: () => MonthlySummaryPage()),
        GetPage(
          name: '/admin-monthly-summary',
          page: () => AdminMonthlySummaryNewPage(),
        ),
        GetPage(name: '/holidays', page: () => const HolidaysPage()),
        GetPage(name: '/leaderboard', page: () => const LeaderboardPage()),
        GetPage(name: '/profile', page: () => ProfilePage()),
        GetPage(name: '/vehicle', page: () => VehiclePage()),
        GetPage(name: '/leave', page: () => const LeavePage()),
        GetPage(name: '/permission', page: () => const PermissionPage()),
        GetPage(name: '/hierarchy', page: () => const HierarchyManagementPage()),
        GetPage(name: '/long-absentees', page: () => const LongAbsenteesPage()),
        GetPage(
          name: '/payroll',
          page: () {
            final args = Get.arguments as Map<String, dynamic>? ?? {};
            // New payslip page: uses username to fetch admin-uploaded payslips
            return PayslipPage(
              username: args['username'] as String? ?? '',
              displayName: args['displayName'] as String? ?? '',
            );
          },
        ),
      ],
    );
  }

  ThemeData _buildTheme() {
    const primaryBlack = Color(0xFF000000);
    const bgColor = Color(0xFFFAFAFB);
    const cardColor = Color(0xFFFFFFFF);
    const surfaceColor = Color(0xFFFFFFFF);

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgColor,
      primaryColor: primaryBlack,
      colorScheme: const ColorScheme.light(
        primary: primaryBlack,
        secondary: Color(0xFF059669),
        surface: cardColor,
        background: bgColor,
        error: Color(0xFFDC2626),
        onPrimary: Colors.white,
        onSurface: Color(0xFF111827),
        onBackground: Color(0xFF111827),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlack,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.3,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryBlack, width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFF6B7280)),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        prefixIconColor: const Color(0xFF6B7280),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w800,
        ),
        displayMedium: TextStyle(
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: Color(0xFF0F172A)),
        bodyMedium: TextStyle(color: Color(0xFF475569)),
        labelLarge: TextStyle(
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Gives all scrollable widgets smooth bouncing physics on every platform.
class _SmoothScrollBehavior extends ScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}
