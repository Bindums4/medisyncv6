import 'dart:convert';
import 'package:flutter/material.dart';
import 'main.dart';
import 'extras.dart';
import 'plus.dart';
import 'rx.dart';

class DoctorHome extends StatefulWidget {
  const DoctorHome({super.key});
  @override
  State<DoctorHome> createState() => _DoctorHomeState();
}

class _DoctorHomeState extends State<DoctorHome> {
  int tab = 0;
  List items = [];
  Map me = {}, stats = {}, prof = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final r = await apiGet('/appointments/doctor');
    final m = await apiGet('/auth/me');
    final s = await apiGet('/extras/doctor-stats');
    final p = await apiGet('/doctors/me/profile');
    final j = jsonOf(r), u = jsonOf(m), sj = jsonOf(s), pj = jsonOf(p);
    if (!mounted) return;
    setState(() {
      items = ok(r) && j is List ? j : [];
      me = ok(m) && u is Map ? u : {};
      stats = ok(s) && sj is Map ? sj : {};
      prof = ok(p) && pj is Map ? pj : {};
      loading = false;
    });
  }

  Future<void> done(String id) async {
    final r = await apiSend('PATCH', '/appointments/$id/done');
    if (!mounted) return;
    snackOn(context, ok(r) ? 'Marked as done' : errOf(r));
    load();
  }

  Color statusColor(String s) => s == 'done' ? Colors.green : (s == 'cancelled' ? Colors.red : Colors.orange);

  Widget stat(String label, String v) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              Text(v, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              Text(label),
            ]),
          ),
        ),
      );

  String patientName(dynamic a) {
    final p = a['patient'];
    final n = p is Map ? '${p['name'] ?? 'Patient'}' : 'Patient';
    return n.isEmpty ? 'Patient' : n;
  }

  String patientId(dynamic a) {
    final p = a['patient'];
    return p is Map ? '${p['_id'] ?? ''}' : '';
  }

  dynamic patientPhoto(dynamic a) {
    final p = a['patient'];
    return p is Map ? p['avatar'] : null;
  }

  Widget appointments() {
    final booked = items.where((a) => a['status'] == 'booked').length;
    final finished = items.where((a) => a['status'] == 'done').length;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        Row(children: [stat('Total', '${items.length}'), stat('Upcoming', '$booked'), stat('Done', '$finished')]),
        Row(children: [stat('Today', '${stats['today'] ?? 0}'), stat('Earned', '\u20B9${stats['earnings'] ?? 0}')]),
        const SizedBox(height: 8),
        if (items.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No appointments yet'))),
        for (final a in items)
          Card(
            child: ListTile(
              leading: face(patientPhoto(a), patientName(a)),
              title: Text(patientName(a)),
              subtitle: Text('${a['date']} at ${a['time']}  |  ${a['status']}${a['paid'] == true ? '  |  paid' : ''}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (a['status'] != 'cancelled')
                  IconButton(tooltip: 'Video call', icon: const Icon(Icons.videocam), onPressed: () => joinVideo(context, '${a['_id']}')),
                if (a['status'] != 'cancelled')
                  IconButton(
                    tooltip: 'Write prescription',
                    icon: const Icon(Icons.medication_outlined),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PrescriptionPage(appointmentId: '${a['_id']}', patientName: patientName(a)))),
                  ),
                if (patientId(a).isNotEmpty)
                  IconButton(
                    tooltip: 'Private notes',
                    icon: const Icon(Icons.sticky_note_2_outlined),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PatientNotesPage(patientId: patientId(a), name: patientName(a)))),
                  ),
                a['status'] == 'booked'
                    ? FilledButton(onPressed: () => done('${a['_id']}'), child: const Text('Done'))
                    : Icon(Icons.circle, size: 14, color: statusColor('${a['status']}')),
              ]),
            ),
          ),
      ]),
    );
  }

  Future<void> edit() async {
    final qual = TextEditingController(text: '${prof['qualification'] ?? ''}');
    final clinic = TextEditingController(text: '${prof['clinic'] ?? ''}');
    final fee = TextEditingController(text: '${prof['fee'] ?? 500}');
    final exp = TextEditingController(text: '${prof['experience'] ?? 0}');
    final langs = TextEditingController(text: prof['languages'] is List ? (prof['languages'] as List).join(', ') : '');
    final bio = TextEditingController(text: '${prof['bio'] ?? ''}');
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit professional details'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: qual, decoration: const InputDecoration(labelText: 'Qualification')),
            TextField(controller: clinic, decoration: const InputDecoration(labelText: 'Clinic or hospital')),
            TextField(controller: fee, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Consultation fee (100 to 10000)')),
            TextField(controller: exp, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Years of experience')),
            TextField(controller: langs, decoration: const InputDecoration(labelText: 'Languages (comma separated)')),
            TextField(controller: bio, maxLines: 3, maxLength: 500, decoration: const InputDecoration(labelText: 'About you')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final r = await apiSend('PUT', '/doctors/me/profile', {
      'qualification': qual.text.trim(),
      'clinic': clinic.text.trim(),
      'fee': fee.text.trim(),
      'experience': exp.text.trim(),
      'languages': langs.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      'bio': bio.text.trim(),
    });
    if (!mounted) return;
    snackOn(context, ok(r) ? 'Profile saved' : errOf(r));
    load();
  }

  Future<void> changePassword() async {
    final cur = TextEditingController(), next = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change password'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: cur, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')),
          TextField(controller: next, obscureText: true, decoration: const InputDecoration(labelText: 'New password (6+ characters)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Change')),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final r = await apiSend('POST', '/auth/change-password', {'current': cur.text, 'password': next.text});
    if (!mounted) return;
    snackOn(context, ok(r) ? 'Password changed' : errOf(r));
  }

  Widget row(IconData i, String label, dynamic v) => ListTile(
        dense: true,
        leading: Icon(i),
        title: Text(label),
        subtitle: Text(v == null || '$v'.isEmpty ? 'Not added yet' : '$v'),
      );

  Widget profile(BuildContext c) {
    final n = '${prof['name'] ?? me['name'] ?? 'Doctor'}';
    final langs = prof['languages'] is List ? (prof['languages'] as List).join(', ') : '';
    return ListView(padding: const EdgeInsets.all(16), children: [
      Center(child: ProfilePhoto(photo: me['avatar'], name: n)),
      const SizedBox(height: 10),
      Center(child: Text(n, style: Theme.of(c).textTheme.headlineSmall)),
      Center(child: Text('${me['email'] ?? ''}')),
      const SizedBox(height: 8),
      row(Icons.local_hospital_outlined, 'Specialty', prof['specialty']),
      row(Icons.school_outlined, 'Qualification', prof['qualification']),
      row(Icons.business_outlined, 'Clinic or hospital', prof['clinic']),
      row(Icons.currency_rupee, 'Consultation fee', prof['fee'] == null ? null : '\u20B9${prof['fee']}'),
      row(Icons.workspace_premium_outlined, 'Experience', prof['experience'] == null ? null : '${prof['experience']} years'),
      row(Icons.translate, 'Languages', langs),
      row(Icons.info_outline, 'About', prof['bio']),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: edit, icon: const Icon(Icons.edit), label: const Text('Edit professional details')),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: changePassword, icon: const Icon(Icons.lock_reset), label: const Text('Change password')),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const WorkingHoursPage())), icon: const Icon(Icons.schedule), label: const Text('Working hours')),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const DaysOffPage())), icon: const Icon(Icons.event_busy), label: const Text('Days off')),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const RxTemplatesPage())), icon: const Icon(Icons.bookmarks_outlined), label: const Text('Prescription templates')),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: () => logout(c), icon: const Icon(Icons.logout), label: const Text('Log out')),
    ]);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(
          title: Text(tab == 0 ? 'My appointments' : 'My profile'),
          actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: load)],
        ),
        body: loading ? const Center(child: CircularProgressIndicator()) : (tab == 0 ? appointments() : profile(c)),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (v) => setState(() => tab = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.event_note), label: 'Appointments'),
            NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      );
}
