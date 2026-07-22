# Accident Guard

A premium, state-of-the-art cross-platform Flutter application built to detect vehicle accidents using real-time accelerometer telemetry, determine the closest emergency facility, and instantly dispatch SMS alerts with precise GPS locations.

---

## 🚀 Key Features

1. **Impact Telemetry**: Monitors G-Force forces in real-time. Detects collisions exceeding a $\ge 35.0\text{ m/s}^2$ threshold.
2. **Safety Countdown**: Sounds a customizable emergency alarm during a 30-second warning countdown, allowing drivers to override the dispatch if they are safe.
3. **Nearest Hospital Dispatch**: Performs distance matrix calculations to find the closest registered hospital hub using high-precision GPS.
4. **Automated SMS Alerts**: Uses the Twilio API to dispatch immediate SMS alerts containing:
   - Driver name and blood group.
   - Exact location coordinates with a direct Google Maps routing link.
5. **Stateful Offline Persistence**: Uses `shared_preferences` to persist accounts, login credentials, and user sessions on the device.
6. **Robust Firebase Integration**: Integrates Cloud Firestore and Firebase Auth, with a graceful offline mockup fallback.

---

## 🛠️ Technology Stack

- **Frontend**: Flutter (Dart)
- **Database/Backend**: Google Cloud Firestore & Firebase Auth (Fallback to persistent local storage)
- **APIs**: Twilio SMS Gateway
- **Hardware Integration**: Accelerometer Sensor & GPS Location services

---

## 🏃 How to Run the Project

### Prerequisites
Make sure you have the [Flutter SDK](https://docs.flutter.dev/get-started/learn-flutter) installed on your system.

### Steps
1. **Get Dependencies**:
   Open a terminal in the project directory and run:
   ```bash
   flutter pub get
   ```

2. **Run the Application**:
   Select your target device (Chrome, Android, or iOS) and execute:
   ```bash
   # Run on Chrome
   flutter run -d chrome

   # Run on a connected Android phone
   flutter run -d android

   # Run as a local Web Server
   flutter run -d web-server --web-port=8080 --web-hostname=127.0.0.1
   ```

---

## ⚙️ Configuration & Twilio Setup

To configure Twilio SMS capabilities:
1. Open the application and log in as a **Driver** (default credentials: `driver@guard.com` / `Password123!`).
2. Go to the **Control Panel**.
3. Under **Twilio Config**, enter your:
   - **Account SID**
   - **Auth Token**
   - **Sender Phone Number** (Your Twilio virtual number)
4. Click **Apply Config**. Telemetry crash alerts will now use your active Twilio credentials!

---

## 📱 How to Build the Release APK

To build a production-ready Android APK (`.apk`):
```bash
flutter build apk --release
```
The compiled output is located at:
`build/app/outputs/flutter-apk/app-release.apk`
