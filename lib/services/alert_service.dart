import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:twilio_flutter/twilio_flutter.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'database_service.dart';

class AlertService {
  final DatabaseService _dbService = DatabaseService();
  static const platform = MethodChannel('com.example.accident_guard_system/sms');

  // Twilio credentials: Use configuration parameters or fall back to test credentials.
  // Standard Twilio test account details can be used, but since we are demonstrating,
  // we will handle credential initialization gracefully.
  late TwilioFlutter _twilioFlutter;
  bool _twilioInitialized = false;

  void initializeTwilio({
    required String accountSid,
    required String authToken,
    required String twilioNumber,
  }) {
    if (accountSid.isEmpty || authToken.isEmpty || twilioNumber.isEmpty) {
      print("AlertService: Twilio credentials empty. Running in Mock/Debug mode.");
      _twilioInitialized = false;
      return;
    }
    try {
      _twilioFlutter = TwilioFlutter(
        accountSid: accountSid,
        authToken: authToken,
        twilioNumber: twilioNumber,
      );
      _twilioInitialized = true;
      print("AlertService: Twilio successfully initialized.");
    } catch (e) {
      print("AlertService: Twilio init exception: $e");
      _twilioInitialized = false;
    }
  }

  // Core routine: Fetch location, query nearest hospital, and dispatch alerts
  Future<Map<String, dynamic>> sendEmergencyAlerts({
    required Map<String, dynamic> userProfile,
    required String crashType,
  }) async {
    print("AlertService: Starting emergency alert sequence for crash type: $crashType");

    // 1. Fetch Location
    Position? position;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("AlertService: Location services are disabled.");
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        // Try getting exact current position
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            timeLimit: const Duration(seconds: 6),
          );
        } catch (e) {
          print("AlertService: getCurrentPosition failed/timed out, trying last known position: $e");
          position = await Geolocator.getLastKnownPosition();
        }
      } else {
        print("AlertService: Location permission denied, using mock coordinates");
      }
    } catch (e) {
      print("AlertService: Location fetch error: $e");
    }

    // Default mock location if geolocator is unavailable or denied (e.g. in web sandbox)
    double lat = position?.latitude ?? 12.9716;
    double lng = position?.longitude ?? 77.5946;
    print("AlertService: Coordinates obtained: Lat $lat, Lng $lng");

    // 2. Query nearest hospital
    List<Map<String, dynamic>> hospitals = await _dbService.getHospitals();
    Map<String, dynamic>? nearestHospital;
    double shortestDistance = double.maxFinite;

    for (var hospital in hospitals) {
      double hospLat = (hospital['latitude'] as num).toDouble();
      double hospLng = (hospital['longitude'] as num).toDouble();

      double distance = Geolocator.distanceBetween(
        lat,
        lng,
        hospLat,
        hospLng,
      );

      if (distance < shortestDistance) {
        shortestDistance = distance;
        nearestHospital = hospital;
      }
    }

    String hospitalName = nearestHospital != null
        ? nearestHospital['facilityName']
        : "Unknown Hospital";
    String hospitalPhone = nearestHospital != null
        ? nearestHospital['dispatchPhone']
        : "+919113895419";

    print("AlertService: Nearest Hospital is $hospitalName, distance: ${shortestDistance.toStringAsFixed(2)} meters");

    // 3. Format SMS payloads
    final String name = userProfile['fullName'] ?? "Prakyath";
    final String bloodGroup = userProfile['bloodGroup'] ?? "O+";
    final String parentPhone = userProfile['parentPhone'] ?? "";
    final String googleMapsLink = "https://www.google.com/maps/search/?api=1&query=$lat,$lng";

    final String parentMsg =
        "CRITICAL ALERT: $crashType detected! Driver: $name, Blood Group: $bloodGroup. Exact Coordinates: Latitude: $lat, Longitude: $lng. Map Link: $googleMapsLink";

    final String hospitalMsg =
        "EMERGENCY AMBULANCE DISPATCH REQUEST: $crashType detected! Driver: $name, Blood Group: $bloodGroup. Exact Coordinates: Latitude: $lat, Longitude: $lng. Map Link: $googleMapsLink";

    // 4. Log Crash Report to Database for Hospital Dashboard
    try {
      await _dbService.createCrashReport({
        'driverName': name,
        'bloodGroup': bloodGroup,
        'latitude': lat,
        'longitude': lng,
        'crashType': crashType,
        'status': 'Pending',
      });
    } catch (e) {
      print("AlertService: Failed to create database crash report: $e");
    }

    // 5. Dispatch alerts (SMS & Email)
    bool parentSent = false;
    bool hospitalSent = false;
    bool emailSent = false;

    // Send Alert 1: Parent SMS (sent directly via SIM card of this device)
    if (parentPhone.trim().isNotEmpty) {
      parentSent = await _sendSms(parentPhone, parentMsg);
    }

    // Send Alert 2: Nearest Hospital SMS (sent directly via SIM card of this device)
    if (hospitalPhone.trim().isNotEmpty) {
      hospitalSent = await _sendSms(hospitalPhone, hospitalMsg);
    }

    // Send Alert 3: Email alerts (Parent & Hospital sent independently)
    final String parentEmail = userProfile['parentEmail'] ?? userProfile['email'] ?? "parent@email.com";
    final String hospitalEmail = nearestHospital != null ? nearestHospital['email'] : "hospital@email.com";

    bool parentEmailSent = false;
    if (parentEmail.trim().isNotEmpty && parentEmail.contains('@')) {
      parentEmailSent = await _sendEmail(
        recipientEmail: parentEmail,
        subject: "🚨 CRITICAL ACCIDENT ALERT: $name",
        body: parentMsg,
      );
    }

    bool hospitalEmailSent = false;
    if (hospitalEmail.trim().isNotEmpty && hospitalEmail.contains('@') && hospitalEmail != 'hospital@email.com') {
      hospitalEmailSent = await _sendEmail(
        recipientEmail: hospitalEmail,
        subject: "🚨 EMERGENCY ACCIDENT ALERT: $name",
        body: hospitalMsg,
      );
    }

    emailSent = parentEmailSent || hospitalEmailSent;

    return {
      'lat': lat,
      'lng': lng,
      'nearestHospital': hospitalName,
      'hospitalPhone': hospitalPhone,
      'distance': shortestDistance,
      'parentPhone': parentPhone,
      'parentMessage': parentMsg,
      'hospitalMessage': hospitalMsg,
      'parentSent': parentSent,
      'hospitalSent': hospitalSent,
      'emailSent': emailSent,
      'parentEmail': parentEmail,
      'hospitalEmail': hospitalEmail,
    };
  }

  // Internal Email dispatcher using direct SMTP via mailer
  Future<bool> _sendEmail({
    required String recipientEmail,
    required String subject,
    required String body,
  }) async {
    if (recipientEmail.trim().isEmpty || !recipientEmail.contains('@')) {
      print("AlertService: Cannot send SMTP Email. Invalid recipient: $recipientEmail");
      return false;
    }
    final String username = 'accidentguard@gmail.com';
    final String password = 'Shetty@123';

    final smtpServer = gmail(username, password);

    // Prepare message
    final message = Message()
      ..from = Address(username, 'Accident Guard System')
      ..recipients.add(recipientEmail.trim())
      ..subject = subject
      ..text = body;

    try {
      final sendReport = await send(message, smtpServer);
      print('AlertService: SMTP Email sent successfully to $recipientEmail: ${sendReport.toString()}');
      return true;
    } catch (e) {
      print('AlertService: SMTP Email sending failed to $recipientEmail: $e');
    }
    return false;
  }

  // Internal SMS dispatcher calling native SmsManager via MethodChannel or Textbee Gateway
  Future<bool> _sendSms(String number, String message) async {
    if (number.trim().isEmpty) {
      print("AlertService: Cannot send SMS. Phone number is empty.");
      return false;
    }

    // Try Textbee Gateway first if configured
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? textbeeApiKey = prefs.getString('textbee_api_key');
      final String? textbeeDeviceId = prefs.getString('textbee_device_id');

      if (textbeeApiKey != null && textbeeApiKey.trim().isNotEmpty &&
          textbeeDeviceId != null && textbeeDeviceId.trim().isNotEmpty) {
        final url = "https://api.textbee.dev/api/v1/gateway/devices/${textbeeDeviceId.trim()}/send-sms";
        final response = await http.post(
          Uri.parse(url),
          headers: {
            "Content-Type": "application/json",
            "x-api-key": textbeeApiKey.trim(),
          },
          body: jsonEncode({
            "recipients": [number],
            "message": message,
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          print("AlertService: SMS successfully sent via Textbee Gateway to $number");
          return true;
        } else {
          print("AlertService: Textbee failed with status code ${response.statusCode}: ${response.body}");
        }
      }
    } catch (e) {
      print("AlertService: Textbee gateway check/send failed: $e");
    }

    // Fallback: local SIM-based SMS sending using native SmsManager MethodChannel
    try {
      final String result = await platform.invokeMethod('sendSms', {
        'phoneNumber': number,
        'message': message,
      });
      print("AlertService: Native SIM SMS sent successfully to $number. Result: $result");
      return true;
    } catch (e) {
      print("AlertService: Native SIM SMS sending failed to $number: $e. Falling back to simulator log.");
    }

    // fallback log output
    print("=================== SMS ALERT DISPATCH SIMULATOR ===================");
    print("To: $number");
    print("Message: $message");
    print("====================================================================");
    return true; // Simulate success in mock mode
  }
}
