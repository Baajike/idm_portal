import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';

// ⚠️ IMPORTANT: Change this to your server IP when deploying
const String BASE_URL = 'https://192.168.31.146:8443';

// ============================================
// Device ID Functions (Hidden from UI)
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
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(50),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/CSALOGO.png', height: 120),
                  const SizedBox(height: 30),
                  const Text(
                    'Welcome To The IDM Portal',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A4DA2),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'GET STARTED',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController secondNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    double inputFontSize = 22;
    FontWeight inputWeight = FontWeight.w600;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 26,
                        color: Colors.black,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 40),
                const Text(
                  'Welcome',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Login to securely access your account",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                ),
                const SizedBox(height: 50),
                _inputLabel(
                  'First Name',
                  fontSize: inputFontSize,
                  weight: inputWeight,
                ),
                _textField(
                  controller: firstNameController,
                  fontSize: inputFontSize,
                  weight: inputWeight,
                ),
                const SizedBox(height: 20),
                _inputLabel(
                  'Second Name',
                  fontSize: inputFontSize,
                  weight: inputWeight,
                ),
                _textField(
                  controller: secondNameController,
                  fontSize: inputFontSize,
                  weight: inputWeight,
                ),
                const SizedBox(height: 20),
                _inputLabel(
                  'Phone Number',
                  fontSize: inputFontSize,
                  weight: inputWeight,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 50,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+233',
                          style: TextStyle(
                            fontSize: inputFontSize,
                            fontWeight: inputWeight,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: TextField(
                          controller: phoneController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 12,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: inputFontSize,
                            fontWeight: inputWeight,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 50),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A4DA2),
                    ),
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'LOGIN',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    String firstName = firstNameController.text.trim();
    String secondName = secondNameController.text.trim();
    String phone = phoneController.text.trim();

    if (firstName.isEmpty || secondName.isEmpty || phone.isEmpty) {
      _showError('Please fill all fields');
      return;
    }

    // Add 0 prefix if not present
    if (!phone.startsWith('0')) {
      phone = '0$phone';
    }

    setState(() => _isLoading = true);

    // Get device ID and model silently
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
          // Save user info locally
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('first_name', firstName);
          await prefs.setString('second_name', secondName);
          await prefs.setString('contact', phone);
          await prefs.setString('name', data['name'] ?? '');
          await prefs.setString('staff_id', data['staff_id'] ?? '');
          await prefs.setString(
            'functional_area',
            data['functional_area'] ?? '',
          );
          await prefs.setString('device_id', deviceId);

          // Cache photo
          if (data['photo'] != null) {
            await _cachePhoto('$BASE_URL${data['photo']}', phone);
          }

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => DashboardScreen(firstName: firstName),
              ),
            );
          }
        } else {
          _showError(data['message'] ?? 'Login failed');
        }
      } else if (response.statusCode == 403) {
        final data = jsonDecode(response.body);
        _showError(data['message'] ?? 'Access denied');
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
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final String firstName;
  const DashboardScreen({super.key, required this.firstName});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? lastScanTime;
  String? cachedPhotoPath;
  String? contact;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      cachedPhotoPath = prefs.getString('cached_photo_path');
      contact = prefs.getString('contact');
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 26,
                        color: Colors.black,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Dashboard',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.person_outline,
                        size: 28,
                        color: Colors.black,
                      ),
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Hello, Sir ${widget.firstName}\nReady to verify your entry today?',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                GestureDetector(
                  onTap: () async {
                    final scanTime = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScanScreen(
                          contact: contact ?? '',
                          cachedPhotoPath: cachedPhotoPath,
                        ),
                      ),
                    );
                    if (scanTime != null && scanTime is String) {
                      _saveRecentEntry(scanTime);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: const [
                        Icon(
                          Icons.qr_code_scanner,
                          size: 100,
                          color: Color(0xFF0A4DA2),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Verify At Gate',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Approach the entry gate and scan the QR to reveal your Digital Identity.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 50),
                Row(
                  children: const [
                    Text(
                      'Recent Entries',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Spacer(),
                    Text(
                      'View All',
                      style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                lastScanTime == null
                    ? const Text(
                        'No Recent Scan yet',
                        style: TextStyle(color: Colors.grey),
                      )
                    : _entryCard(
                        location: 'Main Entrance',
                        time: lastScanTime!,
                        status: 'Granted',
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _entryCard({
  required String location,
  required String time,
  required String status,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Row(
      children: [
        const Icon(Icons.location_on, color: Colors.grey, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                location,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(time, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status,
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

class ScanScreen extends StatefulWidget {
  final String contact;
  final String? cachedPhotoPath;

  const ScanScreen({super.key, required this.contact, this.cachedPhotoPath});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool scanned = false;
  static const String GATE_QR_SECRET = "IDM_GATE_ENTRY_2026";

  Future<void> _verifyAndShowID() async {
    // Try cache first
    if (widget.cachedPhotoPath != null) {
      final file = File(widget.cachedPhotoPath!);
      if (await file.exists()) {
        await _showFullImageFromCache(file);
        return;
      }
    }

    // Get from server
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
          // Log the scan
          await _logScan(deviceId, deviceModel);

          if (data['photo'] != null) {
            await _showFullImageFromUrl('$BASE_URL${data['photo']}');
          } else {
            await _showFullImagePlaceholder();
          }
        }
      }
    } catch (e) {
      await _showFullImagePlaceholder();
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

  Future<void> _showFullImageFromCache(File photoFile) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      builder: (_) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Image.file(
                    photoFile,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showFullImageFromUrl(String imageUrl) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      builder: (_) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.person, size: 200, color: Colors.grey),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showFullImagePlaceholder() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      builder: (_) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                const Center(
                  child: Icon(Icons.person, size: 200, color: Colors.grey),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              height: MediaQuery.of(context).size.height * 0.45,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              clipBehavior: Clip.hardEdge,
              child: MobileScanner(
                onDetect: (barcodeCapture) async {
                  if (scanned) return;

                  final List<Barcode> barcodes = barcodeCapture.barcodes;

                  for (final barcode in barcodes) {
                    final String? code = barcode.rawValue;

                    if (code == GATE_QR_SECRET) {
                      setState(() => scanned = true);
                      await Future.delayed(const Duration(milliseconds: 300));
                      await _verifyAndShowID();

                      if (mounted) {
                        setState(() => scanned = false);
                        Navigator.pop(context, TimeOfDay.now().format(context));
                      }
                      return;
                    }
                  }

                  // Wrong QR code
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
            ),
            const SizedBox(height: 30),
            scanned
                ? Column(
                    children: const [
                      Icon(Icons.check_circle, color: Colors.green, size: 50),
                      SizedBox(height: 12),
                      Text(
                        'Scan Successful',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Point camera at QR code',
                    style: TextStyle(color: Colors.grey),
                  ),
          ],
        ),
      ),
    );
  }
}

Widget _textField({
  required TextEditingController controller,
  double fontSize = 16,
  FontWeight weight = FontWeight.normal,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    height: 50,
    child: TextField(
      controller: controller,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      style: TextStyle(fontSize: fontSize, fontWeight: weight),
    ),
  );
}

Widget _inputLabel(
  String text, {
  double fontSize = 16,
  FontWeight weight = FontWeight.normal,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(fontWeight: weight, fontSize: fontSize),
    ),
  );
}
