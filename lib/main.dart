import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';

// ⚠️ IMPORTANT: Change this to your computer's IP address when testing on a real phone
const String BASE_URL =
    'http://127.0.0.1:8000'; // Change to http://192.168.1.X:8000 for phone testing

// ============================================
// Device ID Functions
// ============================================

Future<String> getDeviceId() async {
  final deviceInfo = DeviceInfoPlugin();
  try {
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown-ios';
    }
  } catch (e) {
    print('Error getting device ID: $e');
  }
  return 'unknown-device';
}

Future<String> getDeviceModel() async {
  final deviceInfo = DeviceInfoPlugin();
  try {
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return '${androidInfo.manufacturer} ${androidInfo.model}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.model ?? 'iPhone';
    }
  } catch (e) {
    print('Error getting device model: $e');
  }
  return 'Unknown Device';
}

void main() {
  runApp(const IDMApp());
}

class IDMApp extends StatelessWidget {
  const IDMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IDM Portal',
      theme: ThemeData(
        primaryColor: const Color(0xFF0A4DA2),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        fontFamily: 'SF Pro Display',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ================= SplashScreen =================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    await Future.delayed(const Duration(seconds: 2));
    final prefs = await SharedPreferences.getInstance();
    final contact = prefs.getString('contact');
    final firstName = prefs.getString('first_name');

    if (contact != null && firstName != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              DashboardScreen(contact: contact, firstName: firstName),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A4DA2),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/CSALOGO.png',
                    height: 80,
                    width: 80,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'IDM Portal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Digital Identity Management',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================= Welcome Screen (✨ UPDATED: Company Logo) =================
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(flex: 1),
              // ✨ CHANGED: Company Logo instead of icon
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A4DA2).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/CSALOGO.png',
                  height: 120,
                  width: 120,
                ),
              ),
              const SizedBox(height: 48),
              const Text(
                'Welcome to\nIDM Portal',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Secure, Fast, and Contactless\nIdentity Verification',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const Spacer(flex: 2),
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0A4DA2), Color(0xFF0D5BC6)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0A4DA2).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= Login Screen =================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FA),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F4FD),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Image.asset(
                              'assets/CSALOGO.png',
                              height: 60,
                              width: 60,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Hey, good to see you!',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create your account to get started',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 32),
                          TextFormField(
                            controller: firstNameController,
                            style: const TextStyle(fontSize: 15),
                            decoration: InputDecoration(
                              labelText: 'First Name',
                              labelStyle: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8F9FA),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF0A4DA2),
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your first name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: lastNameController,
                            style: const TextStyle(fontSize: 15),
                            decoration: InputDecoration(
                              labelText: 'Last Name',
                              labelStyle: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8F9FA),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF0A4DA2),
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your last name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 80,
                                height: 52,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FA),
                                  border: Border.all(color: Colors.grey[200]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '+233',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: const TextStyle(fontSize: 15),
                                  decoration: InputDecoration(
                                    labelText: 'Phone Number',
                                    labelStyle: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF8F9FA),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Colors.grey[200]!,
                                        width: 1,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF0A4DA2),
                                        width: 2,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    hintText: '547788117',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter phone number';
                                    }
                                    if (value.length < 9) {
                                      return 'Phone number too short';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00C896),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _isLoading ? null : _handleLogin,
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'Continue',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Back',
                      style: TextStyle(
                        color: Color(0xFF0A4DA2),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    String firstName = firstNameController.text.trim();
    String lastName = lastNameController.text.trim();
    String phone = phoneController.text.trim();

    if (!phone.startsWith('0')) {
      phone = '0$phone';
    }

    String deviceId = await getDeviceId();
    String deviceModel = await getDeviceModel();

    try {
      final url = Uri.parse('$BASE_URL/api/verify/');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contact': phone,
          'device_id': deviceId,
          'device_model': deviceModel,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['verified'] == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('first_name', firstName);
          await prefs.setString('last_name', lastName);
          await prefs.setString('contact', phone);
          await prefs.setString('name', data['name'] ?? '');
          await prefs.setString('staff_id', data['staff_id'] ?? '');
          await prefs.setString(
            'functional_area',
            data['functional_area'] ?? '',
          );
          await prefs.setString('device_id', deviceId);

          if (data['photo'] != null) {
            await _cachePhoto('$BASE_URL${data['photo']}', phone);
          }

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DashboardScreen(contact: phone, firstName: firstName),
              ),
            );
          }
        } else {
          _showError(data['message'] ?? 'Phone number not found in database');
        }
      } else if (response.statusCode == 403) {
        final data = jsonDecode(response.body);
        if (data['security_alert'] == true) {
          _showSecurityAlert(data['message']);
        } else {
          _showError(data['message'] ?? 'Access denied');
        }
      } else {
        _showError('Server error. Please try again.');
      }
    } catch (e) {
      _showError('Connection error. Please check your internet.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cachePhoto(String photoUrl, String contact) async {
    try {
      final response = await http.get(Uri.parse(photoUrl));
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/staff_photo_$contact.jpg');
        await file.writeAsBytes(response.bodyBytes);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_photo_path', file.path);
      }
    } catch (e) {
      // Silent fail
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSecurityAlert(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.security, color: Colors.red),
            SizedBox(width: 8),
            Text('Security Alert'),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ================= Dashboard (✨ UPDATED: Profile Button Connected) =================
class DashboardScreen extends StatefulWidget {
  final String contact;
  final String firstName;
  const DashboardScreen({
    super.key,
    required this.contact,
    required this.firstName,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? lastScanTime;
  String? staffName;
  String? cachedPhotoPath;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadRecentEntry();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      staffName = prefs.getString('name');
      cachedPhotoPath = prefs.getString('cached_photo_path');
    });
  }

  Future<void> _loadRecentEntry() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      lastScanTime = prefs.getString('last_scan_time');
    });
  }

  Future<void> _saveRecentEntry(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_scan_time', time);
    setState(() {
      lastScanTime = time;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A4DA2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Color(0xFF0A4DA2),
                      ),
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WelcomeScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Dashboard',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                  ),
                  // ✨ UPDATED: Profile button now opens ProfileScreen
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(
                            contact: widget.contact,
                            firstName: widget.firstName,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0A4DA2), Color(0xFF0D5BC6)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Hello, ${widget.firstName}! 👋',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ready to verify your entry?',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: () async {
                        final scanTime = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ScanScreen(
                              contact: widget.contact,
                              cachedPhotoPath: cachedPhotoPath,
                            ),
                          ),
                        );
                        if (scanTime != null && scanTime is String) {
                          _saveRecentEntry(scanTime);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0A4DA2), Color(0xFF0D5BC6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0A4DA2).withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.qr_code_scanner_rounded,
                                size: 80,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Scan QR Code',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to scan at the gate',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Activity',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text(
                            'View All',
                            style: TextStyle(
                              color: Color(0xFF0A4DA2),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    lastScanTime == null
                        ? Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.history_rounded,
                                    size: 48,
                                    color: Colors.grey[300],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No recent scans yet',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _buildEntryCard(
                            location: 'Main Entrance',
                            time: lastScanTime!,
                            status: 'Granted',
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard({
    required String location,
    required String time,
    required String status,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: Colors.green[600],
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= Scan Screen (✨ UPDATED: Only Works with Gate QR) =================
class ScanScreen extends StatefulWidget {
  final String contact;
  final String? cachedPhotoPath;
  const ScanScreen({super.key, required this.contact, this.cachedPhotoPath});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool scanned = false;
  static const String GATE_QR_SECRET =
      "IDM_GATE_ENTRY_2026"; // ✨ NEW: Must match gate QR

  Future<void> _verifyAndShowID() async {
    if (widget.cachedPhotoPath != null) {
      final file = File(widget.cachedPhotoPath!);
      if (await file.exists()) {
        await _showStaffIDFromCache(file);
        return;
      }
    }

    String deviceId = await getDeviceId();
    String deviceModel = await getDeviceModel();

    try {
      final url = Uri.parse('$BASE_URL/api/verify/');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contact': widget.contact,
          'device_id': deviceId,
          'device_model': deviceModel,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['verified'] == true) {
          await _logScan(deviceId, deviceModel);
          await _showStaffIDFromAPI(data);
        } else {
          _showError('Verification failed');
        }
      } else if (response.statusCode == 403) {
        final data = jsonDecode(response.body);
        _showError(data['message'] ?? 'Access denied');
      }
    } catch (e) {
      _showError('Connection error');
    }
  }

  Future<void> _logScan(String deviceId, String deviceModel) async {
    try {
      await http.post(
        Uri.parse('$BASE_URL/api/scan/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contact': widget.contact,
          'device_id': deviceId,
          'device_model': deviceModel,
          'location': 'Main Entrance',
        }),
      );
    } catch (e) {
      print('Failed to log scan: $e');
    }
  }

  Future<void> _showStaffIDFromCache(File photoFile) async {
    final prefs = await SharedPreferences.getInstance();
    await _showStaffID(
      context,
      name: prefs.getString('name') ?? 'Unknown',
      staffId: prefs.getString('staff_id') ?? 'N/A',
      functionalArea: prefs.getString('functional_area') ?? 'N/A',
      photoFile: photoFile,
    );
  }

  Future<void> _showStaffIDFromAPI(Map<String, dynamic> data) async {
    await _showStaffID(
      context,
      name: data['name'] ?? 'Unknown',
      staffId: data['staff_id'] ?? 'N/A',
      functionalArea: data['functional_area'] ?? 'N/A',
      photoUrl: data['photo'],
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showStaffID(
    BuildContext context, {
    required String name,
    required String staffId,
    required String functionalArea,
    File? photoFile,
    String? photoUrl,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0A4DA2), Color(0xFF0D5BC6)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'STAFF IDENTITY CARD',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: photoFile != null
                                ? Image.file(
                                    photoFile,
                                    height: 320,
                                    width: 260,
                                    fit: BoxFit.cover,
                                  )
                                : (photoUrl != null
                                      ? Image.network(
                                          '$BASE_URL$photoUrl',
                                          height: 320,
                                          width: 260,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _buildPlaceholder(),
                                        )
                                      : _buildPlaceholder()),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow('ID', staffId),
                              const SizedBox(height: 8),
                              _buildInfoRow('Department', functionalArea),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                color: Colors.green[600],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Verified',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 28),
                      onPressed: () => Navigator.pop(context),
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

  Widget _buildPlaceholder() {
    return Container(
      height: 320,
      width: 260,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(Icons.person_rounded, size: 100, color: Colors.grey[400]),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (barcodeCapture) async {
              if (scanned) return;

              final List<Barcode> barcodes = barcodeCapture.barcodes;

              // ✨ NEW: Only accept the gate QR code
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;

                if (code == GATE_QR_SECRET) {
                  setState(() => scanned = true);
                  await _verifyAndShowID();
                  if (mounted) setState(() => scanned = false);
                  Navigator.pop(context, TimeOfDay.now().format(context));
                  return;
                }
              }

              // ✨ NEW: Show error if wrong QR scanned
              if (!scanned) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Invalid QR Code. Please scan the gate QR code.',
                    ),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  if (!scanned)
                    Column(
                      children: [
                        Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 48,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Point camera at gate QR code',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  else
                    Column(
                      children: const [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                          size: 48,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Scan Successful!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= Profile Screen (✨ NEW) =================
class ProfileScreen extends StatefulWidget {
  final String contact;
  final String firstName;

  const ProfileScreen({
    super.key,
    required this.contact,
    required this.firstName,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? fullName;
  String? staffId;
  String? functionalArea;
  String? deviceId;
  String? lastName;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      fullName = prefs.getString('name');
      staffId = prefs.getString('staff_id');
      functionalArea = prefs.getString('functional_area');
      deviceId = prefs.getString('device_id');
      lastName = prefs.getString('last_name');
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: Colors.white),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0A4DA2), Color(0xFF0D5BC6)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        widget.firstName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$fullName',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    functionalArea ?? 'Staff Member',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  _buildInfoTile(
                    icon: Icons.badge_outlined,
                    label: 'Staff ID',
                    value: staffId ?? 'N/A',
                  ),
                  _buildDivider(),
                  _buildInfoTile(
                    icon: Icons.phone_outlined,
                    label: 'Phone Number',
                    value: widget.contact,
                  ),
                  _buildDivider(),
                  _buildInfoTile(
                    icon: Icons.business_outlined,
                    label: 'Department',
                    value: functionalArea ?? 'N/A',
                  ),
                  _buildDivider(),
                  _buildInfoTile(
                    icon: Icons.devices_outlined,
                    label: 'Device ID',
                    value: deviceId != null
                        ? '${deviceId!.substring(0, 8)}...'
                        : 'Not registered',
                    subtitle: 'This device is registered to your account',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  _buildActionTile(
                    icon: Icons.lock_outline,
                    label: 'Change Device',
                    subtitle: 'Register a new device',
                    onTap: () => _showChangeDeviceDialog(),
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    icon: Icons.help_outline,
                    label: 'Help & Support',
                    subtitle: 'Get help with the app',
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Help & Support'),
                          content: const Text(
                            'For assistance, please contact:\n\nEmail: abaajike.nss@csa.gov.gh\nPhone: +233 54 778 8117',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    icon: Icons.info_outline,
                    label: 'About',
                    subtitle: 'App version 1.0.0',
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'IDM Portal',
                        applicationVersion: '1.0.0',
                        applicationLegalese: '© 2026 Your Company',
                        children: [
                          const SizedBox(height: 16),
                          const Text('Digital Identity Management System'),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red[700],
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _handleLogout,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.logout_rounded),
                      SizedBox(width: 8),
                      Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    String? subtitle,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0A4DA2).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF0A4DA2)),
      ),
      title: Text(
        label,
        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.grey[700]),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A1A),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            )
          : null,
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, indent: 72, color: Colors.grey[200]);
  }

  void _showChangeDeviceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Device'),
        content: const Text(
          'To change your registered device, please contact your administrator.\n\n'
          'Your current device is securely linked to your account for security purposes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
