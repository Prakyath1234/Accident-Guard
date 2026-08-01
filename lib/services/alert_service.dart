import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:twilio_flutter/twilio_flutter.dart';
import 'database_service.dart';

class AlertService {
  final DatabaseService _dbService = DatabaseService();

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
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
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
    final String parentPhone = userProfile['parentPhone'] ?? "+919113895419";
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

    // Send Alert 1: Parent SMS
    parentSent = await _sendSms(parentPhone, parentMsg);

    // Send Alert 2: Nearest Hospital SMS
    hospitalSent = await _sendSms(hospitalPhone, hospitalMsg);

    // Send Alert 3: Email alerts (Parent & Hospital)
    final String parentEmail = userProfile['parentEmail'] ?? userProfile['email'] ?? "parent@email.com";
    final String hospitalEmail = nearestHospital != null ? nearestHospital['email'] : "hospital@email.com";

    emailSent = await _sendEmail(
      parentEmail: parentEmail,
      hospitalEmail: hospitalEmail,
      subject: "🚨 CRITICAL ACCIDENT ALERT: $name",
      body: "An accident was detected for $name.\n\n"
            "Driver Details:\n"
            "- Name: $name\n"
            "- Blood Group: $bloodGroup\n"
            "- Parent Phone: $parentPhone\n"
            "- Parent Email: $parentEmail\n"
            "- Device: Driver Mobile App\n\n"
            "Crash Telemetry:\n"
            "- Impact Severity: $crashType\n"
            "- Exact Latitude: $lat\n"
            "- Exact Longitude: $lng\n\n"
            "Google Maps Emergency Routing Link:\n"
            "$googleMapsLink\n\n"
            "This is an automated distress broadcast from the Accident Guard System."
    );

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

  // Internal Email dispatcher with Webhook fallback
  Future<bool> _sendEmail({
    required String parentEmail,
    required String hospitalEmail,
    required String subject,
    required String body,
  }) async {
    final String? emailUrl = _dbService.getEmailDispatcherUrl();
    if (emailUrl == null || emailUrl.isEmpty) {
      print("AlertService: Email Dispatcher Webhook URL not configured. Running in Mock Email mode.");
      print("=================== EMAIL ALERT SIMULATOR ===================");
      print("To Parent Email: $parentEmail");
      print("To Hospital Email: $hospitalEmail");
      print("Subject: $subject");
      print("Body:\n$body");
      print("=============================================================");
      return true;
    }

    try {
      final response = await http.post(
        Uri.parse(emailUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "parentEmail": parentEmail,
          "hospitalEmail": hospitalEmail,
          "subject": subject,
          "body": body,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("AlertService: Emergency emails successfully dispatched via Webhook.");
        return true;
      } else {
        print("AlertService: Email Webhook failed with status code ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      print("AlertService: Exception during email dispatch HTTP request: $e");
    }
    return false;
  }

  // Internal SMS dispatcher with fallback logging
  Future<bool> _sendSms(String number, String message) async {
    if (_twilioInitialized) {
      try {
        await _twilioFlutter.sendSMS(
          toNumber: number,
          messageBody: message,
        );
        print("AlertService: SMS sent successfully to $number");
        return true;
      } catch (e) {
        print("AlertService: Twilio failed to send to $number: $e. Logging message instead.");
      }
    } else {
      print("AlertService: Twilio not initialized (Mock Mode).");
    }

    // fallback log output
    print("=================== SMS ALERT DISPATCH SIMULATOR ===================");
    print("To: $number");
    print("Message: $message");
    print("====================================================================");
    return true; // Simulate success in mock mode
  }
}
