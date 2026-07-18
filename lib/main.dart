import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'views/customer_menu_view.dart';
import 'views/waiter_menu_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BiteAndBurpWebApp());
}

class BiteAndBurpWebApp extends StatelessWidget {
  const BiteAndBurpWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    final GoRouter router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashView(),
        ),
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const LandingPageView(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
          ),
        ),
        GoRoute(
          path: '/menu/:hotelId/:tableId',
          builder: (context, state) {
            final hotelId = state.pathParameters['hotelId'] ?? '';
            final tableId = state.pathParameters['tableId'] ?? 'Unknown';
            return CustomerMenuView(hotelId: hotelId, tableId: tableId);
          },
        ),
        GoRoute(
          path: '/waiter/:hotelId',
          builder: (context, state) {
            final hotelId = state.pathParameters['hotelId'] ?? '';
            return WaiterMenuView(hotelId: hotelId);
          },
        ),
      ],
    );

    // 🌟 FIX: File ke ekdum top par imports ke sath yeh line zaroor dalna:
    // import 'package:google_fonts/google_fonts.dart';

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Bite & Burp | Advanced POS Ecosystem',
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8F9FE),
        primaryColor: Colors.deepPurple,
        // 🌟 FIX: Poori app ka global default font ab Poppins ho gaya hai
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
        primaryTextTheme: GoogleFonts.poppinsTextTheme(),
      ),
    );
  }
}

// =========================================================

// =========================================================
// 🌟 1. SPLASH SCREEN
// =========================================================
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.9, curve: Curves.easeOut),
      ),
    );
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic),
          ),
        );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 3500), () {
      if (!mounted) return;
      context.go('/home');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 12,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF673AB7), Color(0xFF311B92)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Container(
                      height: 260,
                      width: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withAlpha(38),
                            blurRadius: 40,
                            spreadRadius: 5,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Transform.scale(
                          scale: 2.3,
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: 180,
                            width: 180,
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) => const Icon(
                              Icons.restaurant_menu,
                              color: Colors.deepPurple,
                              size: 60,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "N A M A S T E",
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.deepPurple,
                                letterSpacing: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          "Welcome to Bite&Burp POS",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// 🌟 2. LANDING PAGE VIEW
// =========================================================
class LandingPageView extends StatefulWidget {
  const LandingPageView({super.key});

  @override
  State<LandingPageView> createState() => _LandingPageViewState();
}

class _LandingPageViewState extends State<LandingPageView> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(
      () => setState(() => _scrollOffset = _scrollController.offset),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 🌟 FIX: The Missing build() method is back!
  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    bool isDesktop = width > 1024;
    bool isTablet = width > 600 && width <= 1024;
    bool isMobile = width <= 600;

    return Scaffold(
      extendBodyBehindAppBar: true,
      endDrawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple.shade50),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.restaurant_menu,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "BITE & BURP",
                    style: TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            _drawerNav(Icons.star_border, "Features"),
            _drawerNav(Icons.devices, "Hardware"),
            _drawerNav(Icons.sell_outlined, "Pricing"),
            const Divider(color: Colors.black12, height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton.icon(
                onPressed: () => _showComingSoonPopup(context),
                icon: const Icon(Icons.login),
                label: const Text("Admin Login"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      appBar: _buildHeader(isDesktop, isTablet),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            left: -100,
            child: _blurOrb(400, Colors.deepPurpleAccent.withAlpha(38))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .move(
                  begin: const Offset(-20, -20),
                  end: const Offset(30, 30),
                  duration: 6.seconds,
                ),
          ),
          Positioned(
            top: 400,
            right: -100,
            child: _blurOrb(500, Colors.orangeAccent.withAlpha(30))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .move(
                  begin: const Offset(20, 0),
                  end: const Offset(-30, -20),
                  duration: 5.seconds,
                ),
          ),

          SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                SizedBox(height: isMobile ? 100 : 140),
                _buildHeroSection(isDesktop, isTablet, isMobile),
                _buildTrustStrip(isDesktop),
                _buildFeatureGrid(isDesktop, isTablet, isMobile),
                _buildPricingSection(isDesktop),
                _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoonPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.rocket_launch, color: Colors.deepPurple),
            SizedBox(width: 10),
            Text(
              "Coming Soon!",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
          ],
        ),
        content: const Text(
          "The Bite & Burp App will be available on the PlayStore very shortly. Stay tuned for the ultimate POS experience!",
          style: TextStyle(
            fontSize: 16,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Got it!",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerNav(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepPurple),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 16,
          color: Colors.black87,
        ),
      ),
      onTap: () {},
    );
  }

  PreferredSizeWidget _buildHeader(bool isDesktop, bool isTablet) {
    return AppBar(
      backgroundColor: Colors.white.withAlpha(230),
      elevation: 0,
      scrolledUnderElevation: 4,
      shadowColor: Colors.deepPurple.withAlpha(50),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/logo.png',
              width: 35,
              height: 35,
              errorBuilder: (c, e, s) => Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: "BITE",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                TextSpan(
                  text: "&",
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(
                  text: "BURP",
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (isDesktop || isTablet) ...[
          _headerNav("Features"),
          _headerNav("Hardware"),
          _headerNav("Pricing"),
          const SizedBox(width: 20),
          OutlinedButton(
            onPressed: () => _showComingSoonPopup(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.deepPurple,
              side: const BorderSide(color: Colors.deepPurple, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              "Contact Us",
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 20),
        ] else ...[
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(
                Icons.menu_rounded,
                color: Colors.deepPurple,
                size: 32,
              ),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ],
    );
  }

  Widget _headerNav(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          color: Colors.black,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildHeroSection(bool isDesktop, bool isTablet, bool isMobile) {
    bool isWide = isDesktop || isTablet;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isWide ? 60 : 20),
      child: Flex(
        direction: isWide ? Axis.horizontal : Axis.vertical,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: isWide
                ? MediaQuery.of(context).size.width * 0.45
                : double.infinity,
            child: Column(
              crossAxisAlignment: isWide
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.deepPurple.withAlpha(102)),
                    borderRadius: BorderRadius.circular(30),
                    color: Colors.deepPurple.withAlpha(20),
                  ),
                  child: const Text(
                    "✨ THE NEXT-GEN RESTAURANT OS",
                    style: TextStyle(
                      color: Colors.deepPurple,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ).animate().fadeIn().slideY(begin: 0.3),
                const SizedBox(height: 25),
                Text(
                  "Run Your Restaurant Like A Masterpiece.",
                  textAlign: isWide ? TextAlign.left : TextAlign.center,
                  style: TextStyle(
                    fontSize: isDesktop ? 60 : (isTablet ? 45 : 38),
                    color: Colors.black,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                  ),
                ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),
                const SizedBox(height: 25),
                Text(
                  "Stop managing multiple tools. Handle Billing, Inventory, Waiter KOTs, and Customer QR Orders from a single, ultra-fast cinematic dashboard.",
                  textAlign: isWide ? TextAlign.left : TextAlign.center,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: isMobile ? 15 : 17,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                  ),
                ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                      onPressed: () => _showComingSoonPopup(context),
                      icon: const Icon(Icons.rocket_launch, size: 20),
                      label: const Text(
                        "Start Free Trial",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 22,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                        shadowColor: Colors.deepPurple.withAlpha(127),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(begin: 1, end: 1.02, duration: 1.seconds)
                    .animate()
                    .fadeIn(delay: 600.ms)
                    .slideY(begin: 0.2),
              ],
            ),
          ),
          if (!isWide) const SizedBox(height: 50),
          SizedBox(
            width: isWide
                ? MediaQuery.of(context).size.width * 0.40
                : double.infinity,
            height: isWide ? 600 : 350,
            child: ClipRect(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _build3DHeroMockup(isDesktop),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _build3DHeroMockup(bool isDesktop) {
    return SizedBox(
      width: 650,
      height: 450,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.002)
                  ..rotateX(-0.1)
                  ..rotateY(-0.15 + (_scrollOffset * 0.0005)),
                alignment: FractionalOffset.center,
                child: Container(
                  width: 550,
                  height: 350,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white, width: 3),
                    color: Colors.white.withAlpha(230),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withAlpha(38),
                        blurRadius: 40,
                        spreadRadius: -5,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withAlpha(13),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            4,
                            (index) => Icon(
                              index == 0
                                  ? Icons.dashboard
                                  : (index == 1
                                        ? Icons.receipt_long
                                        : Icons.inventory_2),
                              color: index == 0
                                  ? Colors.orangeAccent
                                  : Colors.black26,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Live Analytics",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent.withAlpha(51),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    "Online",
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: _mockStatCard(
                                    "Today's Sales",
                                    "₹ 84,280",
                                    Colors.deepPurple,
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: _mockStatCard(
                                    "Active Tables",
                                    "14 / 20",
                                    Colors.orangeAccent,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.withAlpha(8),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.deepPurple.withAlpha(13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: -10, end: 10, duration: 4.seconds),
          Positioned(
            top: 40,
            right: 10,
            child: _floatingTag(
              Icons.notifications_active,
              "New QR Order",
              Colors.orangeAccent,
              3.seconds,
            ),
          ),
          Positioned(
            bottom: 40,
            left: 10,
            child: _floatingTag(
              Icons.check_circle,
              "KOT Printed",
              Colors.green,
              4.seconds,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mockStatCard(String title, String val, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withAlpha(13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            val,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _floatingTag(IconData icon, String text, Color color, Duration dur) {
    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(begin: -8, end: 8, duration: dur);
  }

  Widget _buildFeatureGrid(bool isDesktop, bool isTablet, bool isMobile) {
    final features = [
      {
        "t": "Contactless QR Menu",
        "d":
            "Customers scan, order, and pay directly. Speeds up table turnover by 30%.",
        "i": Icons.qr_code_scanner,
        "c": Colors.orangeAccent.shade700,
      },
      {
        "t": "Captain Waiter Pad",
        "d":
            "Equip staff with mobile devices. Punch KOTs right from the table directly to the kitchen.",
        "i": Icons.touch_app,
        "c": Colors.blueAccent,
      },
      {
        "t": "Smart Inventory",
        "d":
            "Connect recipes to items. Auto-deduct raw materials like Maida/Oil the moment a dish sells.",
        "i": Icons.inventory_2_outlined,
        "c": Colors.green.shade600,
      },
      {
        "t": "Live Cashbook",
        "d":
            "Manage vendor payouts, staff salaries, cash, and UPI settlements in one integrated ledger.",
        "i": Icons.account_balance_wallet,
        "c": Colors.deepPurple,
      },
      {
        "t": "Offline Resilience",
        "d":
            "Internet down? No problem. Continue billing and sync everything when you're back online.",
        "i": Icons.wifi_off,
        "c": Colors.cyan.shade700,
      },
    ];
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 20,
        vertical: 100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            "CORE ECOSYSTEM",
            style: TextStyle(
              color: Colors.deepPurple,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            "Everything you need.\nZero chaos.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontSize: 45,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 60),
          Wrap(
            spacing: 25,
            runSpacing: 25,
            alignment: WrapAlignment.center,
            children: features.map((f) {
              return StatefulBuilder(
                builder: (context, setState) {
                  bool isHovered = false;
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => isHovered = true),
                    onExit: (_) => setState(() => isHovered = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      width: isMobile
                          ? double.infinity
                          : (isTablet ? 300 : 340),
                      height: 280,
                      padding: const EdgeInsets.all(30),
                      transform: Matrix4.identity()
                        ..scale(isHovered ? 1.03 : 1.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: Colors.white,
                        border: Border.all(
                          color: isHovered
                              ? (f['c'] as Color).withAlpha(127)
                              : Colors.black12,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isHovered
                                ? (f['c'] as Color).withAlpha(38)
                                : Colors.black.withAlpha(8),
                            blurRadius: isHovered ? 30 : 15,
                            spreadRadius: isHovered ? 5 : 0,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (f['c'] as Color).withAlpha(25),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              f['i'] as IconData,
                              color: f['c'] as Color,
                              size: 35,
                            ),
                          ),
                          const SizedBox(height: 25),
                          Text(
                            f['t'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: Text(
                              f['d'] as String,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 15,
                                height: 1.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _blurOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 120, spreadRadius: 60)],
      ),
    );
  }

  Widget _buildTrustStrip(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      color: Colors.deepPurple.withAlpha(13),
      child: Opacity(
        opacity: 0.6,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(
              10,
              (i) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  "BITE & BURP POS",
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPricingSection(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60 : 20,
        vertical: 100,
      ),
      child: Column(
        children: [
          const Text(
            "PRICING",
            style: TextStyle(
              letterSpacing: 3,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Scale your restaurant",
            style: TextStyle(
              color: Colors.black,
              fontSize: 40,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 60),
          Wrap(
            spacing: 30,
            runSpacing: 30,
            alignment: WrapAlignment.center,
            children: [
              _pricingCard(
                "Starter",
                "₹999",
                "/mo",
                [
                  "Up to 10 Tables",
                  "QR Menu Generation",
                  "Basic Billing",
                  "Email Support",
                ],
                false,
                isDesktop,
              ),
              _pricingCard(
                "Pro SaaS",
                "₹1,999",
                "/mo",
                [
                  "Unlimited Tables",
                  "Captain Waiter Pad",
                  "Smart Inventory",
                  "Live Cashbook",
                ],
                true,
                isDesktop,
              ),
              _pricingCard(
                "Enterprise",
                "Custom",
                "",
                [
                  "Multi-outlet Sync",
                  "Custom App Whitelabel",
                  "Dedicated Manager",
                  "API Access",
                ],
                false,
                isDesktop,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pricingCard(
    String title,
    String price,
    String suffix,
    List<String> features,
    bool isHighlighted,
    bool isDesktop,
  ) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;
        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isDesktop ? 350 : double.infinity,
            padding: const EdgeInsets.all(40),
            transform: Matrix4.identity()..scale(isHovered ? 1.02 : 1.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isHighlighted ? Colors.deepPurple : Colors.black12,
                width: isHighlighted ? 2 : 1,
              ),
              color: isHighlighted ? Colors.deepPurple : Colors.white,
              boxShadow: isHighlighted
                  ? [
                      BoxShadow(
                        color: Colors.deepPurple.withAlpha(76),
                        blurRadius: 30,
                        spreadRadius: 5,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withAlpha(13),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isHighlighted)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "MOST POPULAR",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                Text(
                  title,
                  style: TextStyle(
                    color: isHighlighted ? Colors.white : Colors.black,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        color: isHighlighted ? Colors.white : Colors.black,
                        fontSize: 45,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      suffix,
                      style: TextStyle(
                        color: isHighlighted ? Colors.white70 : Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Column(
                  children: features
                      .map(
                        (f) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 20,
                                color: isHighlighted
                                    ? Colors.orangeAccent
                                    : Colors.deepPurple,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  f,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isHighlighted
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 40),
                InkWell(
                  onTap: () => _showComingSoonPopup(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: isHighlighted
                          ? Colors.white
                          : Colors.deepPurple.withAlpha(13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        "Choose $title",
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      color: Colors.deepPurple.shade900,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  color: Colors.deepPurple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "BITE & BURP",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Text(
            "The next generation of restaurant operations.",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 40),
          const Text(
            "© 2026 Bite & Burp Technologies. All rights reserved.",
            style: TextStyle(color: Colors.white30, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
