# Run the full MediSync on a real phone

Want ONE link your mam can click? See DEPLOY.md.
After you run `npm run seed` again you get 8 doctors and a demo patient. Any doctor can also sign up on the
login page ("I am a doctor" -> Create account) and then sees their own appointments.

The website (client) is the FULL project: patient, doctor and admin pages, chat, video call,
prescriptions, reminders and more. The Flutter app is a lighter patient app plus a doctor
appointments screen. Pick the way you want to show it.

## Way 1 - Website on the phone with the USB cable (recommended, works like localhost)
1. One time: server\.env exists, `npm install` done in server and client, `npm run seed` done.
2. Phone: Developer options -> USB debugging ON. Plug in the cable, tap Allow.
   Samsung: turn Auto Blocker OFF (Settings -> Security and privacy).
3. Double-click `start-demo.bat` (starts server + website + phone link).
4. On the phone open Chrome and go to  http://localhost:5173
5. Log in:
   - Patient: register a new account on the sign-up page
   - Doctor : ananya@medisync.com / Doctor@123
   - Admin  : admin@medisync.com  / Admin@123
Camera and video call work because localhost counts as a secure address.

## Way 2 - Website on the phone with Wi-Fi only (no cable)
1. Laptop and phone on the SAME Wi-Fi. Start the server and the website (npm start / npm run dev).
2. On the laptop run `ipconfig` and note the IPv4 Address, for example 192.168.1.5.
3. On the phone open Chrome and go to  http://192.168.1.5:5173
   If it does not open, allow Node.js through Windows Firewall (Private networks).
Video call may not work on plain http over Wi-Fi; use Way 1 for that.

## Way 3 - Flutter app on the phone (patient screens + doctor appointments)
cd mobile
flutter create --platforms=android .        (first time only, adds the android folder)
Add to android\app\src\main\AndroidManifest.xml: the INTERNET permission, and
android:usesCleartextTraffic="true" inside the <application tag.
adb reverse tcp:5000 tcp:5000
flutter run -d <your device id>
The app logs in by role: doctors see "Doctor - Appointments", patients see the patient pages.
