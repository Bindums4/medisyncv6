import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Slide {
  final IconData icon;
  final String title, text;
  const _Slide(this.icon, this.title, this.text);
}

/// Three welcome slides, shown only the first time the app opens.
class Welcome extends StatefulWidget {
  final VoidCallback onDone;
  const Welcome({super.key, required this.onDone});
  @override
  State<Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<Welcome> {
  final ctrl = PageController();
  int page = 0;
  static const slides = [
    _Slide(Icons.medical_services, 'Find the right doctor', 'Search by name or specialty and book a time in seconds.'),
    _Slide(Icons.video_call, 'Consult from anywhere', 'Chat or video call your doctor and get digital prescriptions.'),
    _Slide(Icons.favorite, 'Stay on top of your health', 'Medicine reminders, health readings, a health card and emergency help.'),
  ];

  Future<void> finish() async {
    (await SharedPreferences.getInstance()).setBool('seen', true);
    widget.onDone();
  }

  @override
  Widget build(BuildContext c) {
    final last = page == slides.length - 1;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF0B6E5C), Color(0xFF3CCFB0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: SafeArea(
          child: Column(children: [
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: finish, child: const Text('Skip', style: TextStyle(color: Colors.white)))),
            Expanded(
              child: PageView.builder(
                controller: ctrl,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => page = i),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(slides[i].icon, size: 72, color: const Color(0xFF0B6E5C)),
                    ),
                    const SizedBox(height: 32),
                    Text(slides[i].title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Text(slides[i].text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 17)),
                  ]),
                ),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < slides.length; i++)
                Container(
                  margin: const EdgeInsets.all(4),
                  width: i == page ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(color: i == page ? Colors.white : Colors.white54, borderRadius: BorderRadius.circular(8)),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF0B6E5C), padding: const EdgeInsets.all(16)),
                  onPressed: () => last ? finish() : ctrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                  child: Text(last ? 'Get started' : 'Next'),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
