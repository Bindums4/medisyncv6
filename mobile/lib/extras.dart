import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';

String _v(dynamic x, String d) {
  final s = x == null ? '' : '$x';
  return s.isEmpty ? d : s;
}

/// Digital health card with a QR code a doctor can scan in an emergency.
class HealthCardPage extends StatefulWidget {
  const HealthCardPage({super.key});
  @override
  State<HealthCardPage> createState() => _HealthCardPageState();
}

class _HealthCardPageState extends State<HealthCardPage> {
  Map u = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final r = await apiGet('/auth/me');
    final j = jsonOf(r);
    if (!mounted) return;
    setState(() {
      u = ok(r) && j is Map ? j : {};
      loading = false;
    });
  }

  String get contact {
    final ec = u['emergencyContact'];
    return ec is Map ? '${_v(ec['name'], '-')} ${_v(ec['phone'], '')}' : '-';
  }

  String get text =>
      'MEDISYNC HEALTH CARD\nName: ${_v(u['name'], '-')}\nBlood group: ${_v(u['bloodGroup'], 'not set')}\nAllergies: ${_v(u['allergies'], 'none noted')}\nConditions: ${_v(u['conditions'], 'none noted')}\nDOB: ${_v(u['dob'], '-')}\nEmergency contact: $contact';

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Health card')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0B6E5C), Color(0xFF3CCFB0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('MEDISYNC HEALTH CARD', style: TextStyle(color: Colors.white70, letterSpacing: 1.2)),
                    const SizedBox(height: 6),
                    Text(_v(u['name'], '-'), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Text('Blood group: ${_v(u['bloodGroup'], 'not set')}', style: const TextStyle(color: Colors.white)),
                    Text('Allergies: ${_v(u['allergies'], 'none noted')}', style: const TextStyle(color: Colors.white)),
                    Text('Conditions: ${_v(u['conditions'], 'none noted')}', style: const TextStyle(color: Colors.white)),
                    Text('Emergency contact: $contact', style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.white,
                        child: QrImageView(data: text, size: 190, backgroundColor: Colors.white),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                const Text('A doctor can scan this code in an emergency. Fill in your blood group, allergies and emergency contact in My profile to complete the card.'),
              ]),
      );
}

/// Opens Google Maps with the closest hospitals, pharmacies and more.
class NearbyPage extends StatelessWidget {
  const NearbyPage({super.key});
  static const places = [
    ['Hospitals', 'hospitals', Icons.local_hospital],
    ['Pharmacies', 'pharmacies', Icons.medication],
    ['Clinics', 'clinics', Icons.medical_services],
    ['Blood banks', 'blood bank', Icons.bloodtype],
    ['Diagnostic labs', 'diagnostic lab', Icons.science],
    ['Ambulance services', 'ambulance service', Icons.emergency],
  ];

  Future<void> open(BuildContext c, String q) async {
    final done = await launchUrl(Uri.parse('https://www.google.com/maps/search/${Uri.encodeComponent('$q near me')}'), mode: LaunchMode.externalApplication);
    if (!done && c.mounted) snackOn(c, 'Could not open Maps.');
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Nearby help')),
        body: ListView(children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Tap to open Google Maps with the closest places to you. In an emergency call 112.')),
          for (final p in places)
            ListTile(
              leading: Icon(p[2] as IconData, color: const Color(0xFF0F8F76)),
              title: Text('${p[0]}'),
              subtitle: const Text('Open in Maps'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => open(c, '${p[1]}'),
            ),
        ]),
      );
}

/// Family members a patient can book visits for.
class FamilyPage extends StatefulWidget {
  const FamilyPage({super.key});
  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  List items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final r = await apiGet('/extras/family');
    final j = jsonOf(r);
    if (!mounted) return;
    setState(() {
      items = ok(r) && j is List ? j : [];
      loading = false;
    });
  }

  Future<void> add() async {
    final name = TextEditingController(), rel = TextEditingController(), age = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add family member'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          TextField(controller: rel, decoration: const InputDecoration(labelText: 'Relation (Mother, Son...)')),
          TextField(controller: age, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Age')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final r = await apiSend('POST', '/extras/family', {'name': name.text.trim(), 'relation': rel.text.trim(), 'age': age.text.trim()});
    if (!mounted) return;
    if (!ok(r)) snackOn(context, errOf(r));
    load();
  }

  Future<void> remove(String id) async {
    await apiSend('DELETE', '/extras/family/$id');
    load();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Family')),
        floatingActionButton: FloatingActionButton.extended(onPressed: add, icon: const Icon(Icons.person_add), label: const Text('Add')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : items.isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No family members yet. Add one, then choose them when you book a visit.', textAlign: TextAlign.center)))
                : ListView(children: [
                    for (final m in items)
                      ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text('${m['name']}'),
                        subtitle: Text('${_v(m['relation'], 'Family')}${m['age'] != null ? ' | ${m['age']} years' : ''}'),
                        trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => remove('${m['_id']}')),
                      ),
                  ]),
      );
}

/// Turns a stored "data:image/...;base64,..." photo into something CircleAvatar can show.
ImageProvider? avatarImage(dynamic d) {
  if (d == null) return null;
  final s = '$d';
  if (!s.startsWith('data:image')) return null;
  try {
    return MemoryImage(base64Decode(s.substring(s.indexOf(',') + 1)));
  } catch (_) {
    return null;
  }
}

/// A round face: the photo if there is one, otherwise the first letter of the name.
Widget face(dynamic photo, String name, {double radius = 20}) {
  final img = avatarImage(photo);
  final n = name.replaceFirst('Dr. ', '').trim();
  return CircleAvatar(
    radius: radius,
    backgroundImage: img,
    child: img == null ? Text(n.isEmpty ? '?' : n[0].toUpperCase(), style: TextStyle(fontSize: radius * 0.9)) : null,
  );
}

/// Profile photo with a camera button. Picks from the gallery and saves it to the account.
class ProfilePhoto extends StatefulWidget {
  final dynamic photo;
  final String name;
  const ProfilePhoto({super.key, required this.photo, required this.name});
  @override
  State<ProfilePhoto> createState() => _ProfilePhotoState();
}

class _ProfilePhotoState extends State<ProfilePhoto> {
  dynamic photo;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    photo = widget.photo;
  }

  Future<void> pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 200, maxHeight: 200, imageQuality: 70);
    if (x == null) return;
    setState(() => busy = true);
    final bytes = await x.readAsBytes();
    final p = x.path.toLowerCase();
    final mime = p.endsWith('.png') ? 'png' : (p.endsWith('.webp') ? 'webp' : 'jpeg');
    final data = 'data:image/$mime;base64,${base64Encode(bytes)}';
    final r = await apiSend('PATCH', '/auth/me', {'avatar': data});
    if (!mounted) return;
    setState(() {
      busy = false;
      if (ok(r)) photo = data;
    });
    snackOn(context, ok(r) ? 'Photo saved' : errOf(r));
  }

  Future<void> remove() async {
    setState(() => busy = true);
    final r = await apiSend('PATCH', '/auth/me', {'avatar': ''});
    if (!mounted) return;
    setState(() {
      busy = false;
      if (ok(r)) photo = null;
    });
  }

  @override
  Widget build(BuildContext c) => Column(children: [
        Stack(alignment: Alignment.bottomRight, children: [
          face(photo, widget.name, radius: 52),
          Material(
            color: const Color(0xFF0F8F76),
            shape: const CircleBorder(),
            child: IconButton(
              icon: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.camera_alt, color: Colors.white, size: 20),
              onPressed: busy ? null : pick,
            ),
          ),
        ]),
        if (photo != null && '$photo'.isNotEmpty) TextButton(onPressed: busy ? null : remove, child: const Text('Remove photo')),
      ]);
}
