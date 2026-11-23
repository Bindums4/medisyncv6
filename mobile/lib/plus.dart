import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';

const _mint = Color(0xFF0F8F76);
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _day(dynamic iso) {
  final d = DateTime.tryParse('$iso')?.toLocal();
  return d == null ? '' : '${d.day} ${_months[d.month - 1]} ${d.year}';
}

// ---------------------------------------------------------------- Health timeline
class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});
  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  List items = [];
  bool loading = true;
  String err = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await apiGet('/plus/timeline');
      final j = jsonOf(r);
      if (!mounted) return;
      setState(() {
        items = ok(r) && j is List ? j : [];
        err = ok(r) ? '' : errOf(r);
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        err = 'Could not reach the server';
        loading = false;
      });
    }
  }

  IconData icon(String k) {
    switch (k) {
      case 'visit':
        return Icons.event;
      case 'prescription':
        return Icons.description_outlined;
      case 'reading':
        return Icons.monitor_heart_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Health timeline')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: load,
                child: ListView(children: [
                  if (err.isNotEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(err, style: const TextStyle(color: Colors.red))),
                  if (items.isEmpty && err.isEmpty)
                    const Padding(padding: EdgeInsets.all(24), child: Text('Nothing here yet. Book a visit or add a reading to start your timeline.')),
                  for (final x in items)
                    ListTile(
                      leading: CircleAvatar(backgroundColor: _mint.withOpacity(0.15), child: Icon(icon('${x['kind']}'), color: _mint)),
                      title: Text('${x['title']}'),
                      subtitle: Text([_day(x['at']), '${x['detail'] ?? ''}'].where((e) => e.isNotEmpty).join('  |  ')),
                    ),
                ]),
              ),
      );
}

// ---------------------------------------------------------------- Daily wellness: water, tip, BMI
class WellnessPage extends StatefulWidget {
  const WellnessPage({super.key});
  @override
  State<WellnessPage> createState() => _WellnessPageState();
}

class _WellnessPageState extends State<WellnessPage> {
  static const tips = [
    'Drink a glass of water first thing in the morning.',
    'A 20 minute walk a day keeps your heart happier.',
    'Sleep 7 to 8 hours. Your body repairs itself at night.',
    'Wash hands for 20 seconds before meals.',
    'Add one extra fruit or vegetable to every meal.',
    'Take short breaks from screens. Look far away for 20 seconds.',
    'Stretch for 5 minutes after sitting for a long time.',
    'Take your medicines at the same time every day.',
    'Breathe in for 4 seconds, hold 4, breathe out 6. Repeat 5 times.',
    'Limit sugary drinks. Water is the best choice.',
  ];
  int glasses = 0;
  final height = TextEditingController(), weight = TextEditingController();
  String bmiText = '';

  String get key {
    final d = DateTime.now();
    return 'water-${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    loadWater();
  }

  @override
  void dispose() {
    height.dispose();
    weight.dispose();
    super.dispose();
  }

  Future<void> loadWater() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => glasses = p.getInt(key) ?? 0);
  }

  Future<void> setWater(int v) async {
    final x = v < 0 ? 0 : (v > 20 ? 20 : v);
    setState(() => glasses = x);
    final p = await SharedPreferences.getInstance();
    await p.setInt(key, x);
  }

  void calcBmi() {
    final h = double.tryParse(height.text.trim()), w = double.tryParse(weight.text.trim());
    if (h == null || w == null || h < 50 || h > 250 || w < 2 || w > 400) {
      setState(() => bmiText = 'Enter height in cm (50 to 250) and weight in kg (2 to 400).');
      return;
    }
    final b = w / ((h / 100) * (h / 100));
    final band = b < 18.5 ? 'below the usual range' : (b < 25 ? 'in the usual range' : (b < 30 ? 'above the usual range' : 'well above the usual range'));
    setState(() => bmiText = 'BMI ${b.toStringAsFixed(1)} ($band). This is a general guide, not a diagnosis.');
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Daily wellness')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Tip of the day', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(tips[DateTime.now().day % tips.length]),
              ]),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Water today', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text('Goal: 8 glasses'),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 6, children: [
                  for (var i = 0; i < 8; i++) Icon(Icons.local_drink, color: i < glasses ? _mint : Colors.grey.shade400),
                ]),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  IconButton(tooltip: 'Remove a glass', icon: const Icon(Icons.remove_circle_outline), onPressed: () => setWater(glasses - 1)),
                  Text('$glasses / 8', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(tooltip: 'Add a glass', icon: const Icon(Icons.add_circle, color: _mint), onPressed: () => setWater(glasses + 1)),
                ]),
              ]),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('BMI calculator', style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(controller: height, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Height (cm)')),
                TextField(controller: weight, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Weight (kg)')),
                const SizedBox(height: 10),
                FilledButton(onPressed: calcBmi, child: const Text('Calculate')),
                if (bmiText.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(bmiText)),
              ]),
            ),
          ),
        ]),
      );
}

// ---------------------------------------------------------------- Emergency numbers
class EmergencyNumbersPage extends StatelessWidget {
  const EmergencyNumbersPage({super.key});
  static const numbers = [
    ['National emergency', '112'],
    ['Ambulance', '108'],
    ['Police', '100'],
    ['Fire', '101'],
    ['Ambulance (maternal and child)', '102'],
    ['Women helpline', '1091'],
    ['Childline', '1098'],
  ];

  Future<void> call(BuildContext c, String n) async {
    final done = await launchUrl(Uri.parse('tel:$n'));
    if (!done && c.mounted) snackOn(c, 'Could not open the phone app. Dial $n yourself.');
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Emergency numbers')),
        body: ListView(children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Tap a number to open the phone app. These are Indian helpline numbers.')),
          for (final n in numbers)
            ListTile(
              leading: const Icon(Icons.call, color: Colors.red),
              title: Text(n[0]),
              trailing: Text(n[1], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              onTap: () => call(c, n[1]),
            ),
        ]),
      );
}

// ---------------------------------------------------------------- Medicine information
const _meds = [
  ['Paracetamol', 'Fever and mild pain', 'Do not exceed the dose on the label. Be careful with liver problems and alcohol.'],
  ['Ibuprofen', 'Pain, inflammation and fever', 'Take after food. Avoid with stomach ulcers, kidney problems or in late pregnancy.'],
  ['Aspirin', 'Pain, fever and blood thinning', 'Can irritate the stomach. Not for children with fever. Tell your doctor if you bleed easily.'],
  ['Amoxicillin', 'Bacterial infections', 'Finish the full course. Tell your doctor about penicillin allergy.'],
  ['Azithromycin', 'Bacterial infections', 'Usually taken for a few days. Report rashes or severe diarrhoea.'],
  ['Cetirizine', 'Allergies, sneezing, itching', 'May cause sleepiness. Be careful when driving.'],
  ['Loratadine', 'Allergies', 'Usually causes less sleepiness. Check the dose for children.'],
  ['Omeprazole', 'Acidity and stomach ulcers', 'Best taken before breakfast. Long use needs a doctor\'s advice.'],
  ['Pantoprazole', 'Acidity and reflux', 'Take before food. Do not use for long without advice.'],
  ['Metformin', 'Type 2 diabetes', 'Take with food. Report severe stomach upset. Kidney checks are needed.'],
  ['Amlodipine', 'High blood pressure', 'May cause ankle swelling. Do not stop suddenly.'],
  ['Atorvastatin', 'High cholesterol', 'Report unexplained muscle pain. Avoid large amounts of grapefruit.'],
  ['Salbutamol', 'Asthma relief inhaler', 'Use for quick relief. If you need it often, see your doctor.'],
  ['ORS', 'Dehydration from diarrhoea or vomiting', 'Mix with clean water exactly as the pack says. Seek help if it does not improve.'],
  ['Vitamin D3', 'Bone health and vitamin D deficiency', 'Take as advised. Too much can raise calcium.'],
  ['Iron tablets', 'Low iron or anaemia', 'May darken stools. Take with water or vitamin C, away from tea and milk.'],
  ['Domperidone', 'Nausea and vomiting', 'Short courses only. Check with your doctor if you have heart problems.'],
  ['Montelukast', 'Asthma and allergic rhinitis', 'Report mood or sleep changes, especially in children.'],
  ['Diclofenac', 'Pain and inflammation', 'Take after food. Avoid with stomach ulcers, heart or kidney disease unless advised.'],
  ['Levothyroxine', 'Underactive thyroid', 'Take on an empty stomach, same time daily. Do not stop without advice.'],
];

class MedicineInfoPage extends StatefulWidget {
  const MedicineInfoPage({super.key});
  @override
  State<MedicineInfoPage> createState() => _MedicineInfoPageState();
}

class _MedicineInfoPageState extends State<MedicineInfoPage> {
  String q = '';

  @override
  Widget build(BuildContext c) {
    final shown = _meds.where((m) => '${m[0]} ${m[1]}'.toLowerCase().contains(q.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Medicine info')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search a medicine or a use', border: OutlineInputBorder()),
          ),
        ),
        Expanded(
          child: ListView(children: [
            if (shown.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No match. Ask your doctor or pharmacist.')),
            for (final m in shown)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                child: ListTile(title: Text(m[0]), subtitle: Text('Used for: ${m[1]}\n${m[2]}'), isThreeLine: true),
              ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('General information only, not medical advice. Always follow your doctor\'s prescription.', style: TextStyle(fontSize: 12)),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Doctor: private notes about a patient
class PatientNotesPage extends StatefulWidget {
  final String patientId, name;
  const PatientNotesPage({super.key, required this.patientId, required this.name});
  @override
  State<PatientNotesPage> createState() => _PatientNotesPageState();
}

class _PatientNotesPageState extends State<PatientNotesPage> {
  List notes = [];
  bool loading = true;
  final text = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final r = await apiGet('/plus/notes/${widget.patientId}');
      final j = jsonOf(r);
      if (!mounted) return;
      setState(() {
        notes = ok(r) && j is List ? j : [];
        loading = false;
      });
      if (!ok(r)) snackOn(context, errOf(r));
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      snackOn(context, 'Could not reach the server');
    }
  }

  Future<void> add() async {
    final t = text.text.trim();
    if (t.isEmpty) return;
    final r = await apiSend('POST', '/plus/notes/${widget.patientId}', {'text': t});
    if (!mounted) return;
    if (ok(r)) {
      text.clear();
      load();
    } else {
      snackOn(context, errOf(r));
    }
  }

  Future<void> remove(String id) async {
    await apiSend('DELETE', '/plus/notes/$id');
    if (mounted) load();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Text('Notes: ${widget.name}')),
        body: Column(children: [
          const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: Text('Private notes. Only you can see these.')),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(children: [
                    if (notes.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No notes yet.')),
                    for (final n in notes)
                      ListTile(
                        title: Text('${n['text']}'),
                        subtitle: Text(_day(n['createdAt'])),
                        trailing: IconButton(tooltip: 'Delete note', icon: const Icon(Icons.delete_outline), onPressed: () => remove('${n['_id']}')),
                      ),
                  ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(child: TextField(controller: text, maxLength: 500, decoration: const InputDecoration(hintText: 'Write a note', counterText: ''))),
              const SizedBox(width: 8),
              FilledButton(onPressed: add, child: const Text('Save')),
            ]),
          ),
        ]),
      );
}

// ---------------------------------------------------------------- shared date helper
String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ---------------------------------------------------------------- Reschedule a booked visit
Future<void> rescheduleVisit(BuildContext c, Map a, VoidCallback done) async {
  final docId = a['doctor']?['_id'];
  if (docId == null) {
    snackOn(c, 'Doctor not found');
    return;
  }
  final now = DateTime.now();
  final d = await showDatePicker(
    context: c,
    initialDate: now.add(const Duration(days: 1)),
    firstDate: now,
    lastDate: now.add(const Duration(days: 90)),
    helpText: 'Choose a new date',
  );
  if (d == null || !c.mounted) return;
  final date = _iso(d);
  try {
    final r = await apiGet('/doctors/$docId/slots?date=$date');
    final slots = jsonOf(r);
    if (!c.mounted) return;
    if (!ok(r) || slots is! List || slots.isEmpty) {
      snackOn(c, 'No free times on $date. Try another date.');
      return;
    }
    final t = await showModalBottomSheet<String>(
      context: c,
      builder: (bc) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Free times on $date', style: Theme.of(bc).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in slots) ActionChip(label: Text('$s'), onPressed: () => Navigator.pop(bc, '$s')),
            ]),
          ]),
        ),
      ),
    );
    if (t == null || !c.mounted) return;
    final m = await apiSend('PATCH', '/appointments/${a['_id']}/reschedule', {'date': date, 'time': t});
    if (!c.mounted) return;
    snackOn(c, ok(m) ? 'Visit moved to $date at $t' : errOf(m));
    if (ok(m)) done();
  } catch (_) {
    if (c.mounted) snackOn(c, 'Could not reach the server');
  }
}

// ---------------------------------------------------------------- Vaccinations (patient)
class VaccinesPage extends StatefulWidget {
  const VaccinesPage({super.key});
  @override
  State<VaccinesPage> createState() => _VaccinesPageState();
}

class _VaccinesPageState extends State<VaccinesPage> {
  List items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await apiGet('/plus/vaccines');
      final j = jsonOf(r);
      if (!mounted) return;
      setState(() {
        items = ok(r) && j is List ? j : [];
        loading = false;
      });
      if (!ok(r)) snackOn(context, errOf(r));
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      snackOn(context, 'Could not reach the server');
    }
  }

  Future<void> add() async {
    final name = TextEditingController(), notes = TextEditingController();
    DateTime? taken, next;
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dc, setD) => AlertDialog(
          title: const Text('Add vaccine'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, maxLength: 80, decoration: const InputDecoration(labelText: 'Vaccine name', counterText: '')),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date taken'),
                subtitle: Text(taken == null ? 'Choose a date' : _iso(taken!)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final d = await showDatePicker(context: dc, initialDate: taken ?? DateTime.now(), firstDate: DateTime(1950), lastDate: DateTime.now());
                  if (d != null) setD(() => taken = d);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Next dose due (optional)'),
                subtitle: Text(next == null ? 'Not set' : _iso(next!)),
                trailing: const Icon(Icons.event),
                onTap: () async {
                  final d = await showDatePicker(context: dc, initialDate: next ?? DateTime.now(), firstDate: DateTime(1950), lastDate: DateTime(2100));
                  if (d != null) setD(() => next = d);
                },
              ),
              TextField(controller: notes, maxLength: 200, decoration: const InputDecoration(labelText: 'Notes (optional)', counterText: '')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dc, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (go != true || !mounted) return;
    if (name.text.trim().isEmpty || taken == null) {
      snackOn(context, 'Enter the vaccine name and the date taken');
      return;
    }
    final r = await apiSend('POST', '/plus/vaccines', {
      'name': name.text.trim(),
      'date': _iso(taken!),
      'nextDue': next == null ? '' : _iso(next!),
      'notes': notes.text.trim(),
    });
    if (!mounted) return;
    if (ok(r)) {
      load();
    } else {
      snackOn(context, errOf(r));
    }
  }

  Future<void> remove(String id) async {
    await apiSend('DELETE', '/plus/vaccines/$id');
    if (mounted) load();
  }

  String taken(Map v) {
    final note = v['notes'] == null ? '' : v['notes'].toString();
    final when = _day(v['date'].toString() + 'T00:00:00');
    return note.isEmpty ? 'Taken ' + when : 'Taken ' + when + ' - ' + note;
  }

  Widget due(Map v) {
    final s = '${v['status']}';
    if (v['nextDue'] == null || '${v['nextDue']}'.isEmpty || s == 'none') return const SizedBox.shrink();
    final label = s == 'overdue' ? 'Overdue' : s == 'soon' ? 'Due soon' : 'Next dose planned';
    final col = s == 'overdue' ? Colors.red : s == 'soon' ? Colors.orange : _mint;
    return Text(label + ': ' + _day(v['nextDue'].toString() + 'T00:00:00'), style: TextStyle(color: col, fontWeight: FontWeight.w600));
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Vaccinations')),
        floatingActionButton: FloatingActionButton.extended(onPressed: add, icon: const Icon(Icons.add), label: const Text('Add vaccine')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: load,
                child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
                  if (items.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No vaccines saved yet. Tap Add vaccine.')),
                  for (final v in items)
                    Card(
                      child: ListTile(
                        title: Text('${v['name']}'),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(taken(v)),
                          due(v),
                        ]),
                        trailing: IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: () => remove('${v['_id']}')),
                      ),
                    ),
                ]),
              ),
      );
}

// ---------------------------------------------------------------- Days off (doctor)
class DaysOffPage extends StatefulWidget {
  const DaysOffPage({super.key});
  @override
  State<DaysOffPage> createState() => _DaysOffPageState();
}

class _DaysOffPageState extends State<DaysOffPage> {
  List days = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await apiGet('/doctors/me/daysoff');
      final j = jsonOf(r);
      if (!mounted) return;
      setState(() {
        days = ok(r) && j is List ? j : [];
        loading = false;
      });
      if (!ok(r)) snackOn(context, errOf(r));
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      snackOn(context, 'Could not reach the server');
    }
  }

  Future<void> add() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: now, firstDate: now, lastDate: now.add(const Duration(days: 365)), helpText: 'Choose a day off');
    if (d == null || !mounted) return;
    final r = await apiSend('POST', '/doctors/me/daysoff', {'date': _iso(d)});
    if (!mounted) return;
    final j = jsonOf(r);
    if (ok(r) && j is Map) {
      final n = j['affected'] is int ? j['affected'] as int : 0;
      setState(() => days = j['daysOff'] is List ? j['daysOff'] : days);
      snackOn(context, n > 0 ? 'Saved. $n patient(s) were asked to reschedule.' : 'Day off saved');
    } else {
      snackOn(context, errOf(r));
    }
  }

  Future<void> remove(String d) async {
    final r = await apiSend('DELETE', '/doctors/me/daysoff/$d');
    final j = jsonOf(r);
    if (mounted && ok(r) && j is List) setState(() => days = j);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Days off')),
        floatingActionButton: FloatingActionButton.extended(onPressed: add, icon: const Icon(Icons.add), label: const Text('Add day off')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.only(bottom: 90), children: [
                const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 8), child: Text('Patients cannot book these dates. Patients who already booked that day are asked to reschedule.')),
                if (days.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No days off added.')),
                for (final d in days)
                  ListTile(
                    leading: const Icon(Icons.event_busy),
                    title: Text(_day(d.toString() + 'T00:00:00')),
                    trailing: IconButton(tooltip: 'Remove', icon: const Icon(Icons.delete_outline), onPressed: () => remove('$d')),
                  ),
              ]),
      );
}
