import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';

String isoDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ---------------------------------------------------------------- Video call (doctor and patient)
Future<void> joinVideo(BuildContext c, String appointmentId) async {
  try {
    final r = await apiGet('/appointments/$appointmentId/video');
    final j = jsonOf(r);
    if (!c.mounted) return;
    if (!ok(r) || j is! Map || j['url'] == null) {
      snackOn(c, ok(r) ? 'Could not start the call' : errOf(r));
      return;
    }
    final opened = await launchUrl(Uri.parse('${j['url']}'), mode: LaunchMode.externalApplication);
    if (!opened && c.mounted) snackOn(c, 'Could not open the video call');
  } catch (_) {
    if (c.mounted) snackOn(c, 'Could not reach the server');
  }
}

// ---------------------------------------------------------------- Write a prescription (doctor)
class _MedRow {
  final name = TextEditingController(), dose = TextEditingController(), days = TextEditingController(text: '5');
  void dispose() {
    name.dispose();
    dose.dispose();
    days.dispose();
  }
}

class PrescriptionPage extends StatefulWidget {
  final String appointmentId, patientName;
  const PrescriptionPage({super.key, required this.appointmentId, required this.patientName});
  @override
  State<PrescriptionPage> createState() => _PrescriptionPageState();
}

class _PrescriptionPageState extends State<PrescriptionPage> {
  final dx = TextEditingController(), tests = TextEditingController(), notes = TextEditingController();
  final List<_MedRow> rows = [_MedRow()];
  final List<_MedRow> retired = [];
  String followUp = '';
  List templates = [];
  bool saving = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    dx.dispose();
    tests.dispose();
    notes.dispose();
    for (final r in [...rows, ...retired]) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    try {
      final r = await apiGet('/prescriptions/for/${widget.appointmentId}');
      final t = await apiGet('/prescriptions/templates');
      final pj = jsonOf(r), tj = jsonOf(t);
      if (!mounted) return;
      setState(() {
        templates = ok(t) && tj is List ? tj : [];
        if (ok(r) && pj is Map) {
          fill(pj);
          followUp = '${pj['followUp'] ?? ''}';
        }
      });
    } catch (_) {}
  }

  void fill(Map p) {
    dx.text = '${p['diagnosis'] ?? ''}';
    tests.text = '${p['tests'] ?? ''}';
    notes.text = '${p['notes'] ?? ''}';
    retired.addAll(rows);
    rows.clear();
    final meds = p['medicines'];
    if (meds is List && meds.isNotEmpty) {
      for (final m in meds) {
        final row = _MedRow();
        row.name.text = '${m['name'] ?? ''}';
        row.dose.text = '${m['dose'] ?? ''}';
        row.days.text = '${m['days'] ?? 5}';
        rows.add(row);
      }
    } else {
      rows.add(_MedRow());
    }
  }

  List<Map> meds() => [
        for (final r in rows)
          if (r.name.text.trim().isNotEmpty) {'name': r.name.text.trim(), 'dose': r.dose.text.trim(), 'days': int.tryParse(r.days.text.trim()) ?? 1},
      ];

  Map body() => {'diagnosis': dx.text.trim(), 'tests': tests.text.trim(), 'notes': notes.text.trim(), 'medicines': meds()};

  Future<void> save() async {
    if (meds().isEmpty) {
      snackOn(context, 'Add at least one medicine');
      return;
    }
    setState(() => saving = true);
    try {
      final r = await apiSend('POST', '/prescriptions', {...body(), 'appointment': widget.appointmentId, 'followUp': followUp});
      if (!mounted) return;
      setState(() => saving = false);
      if (ok(r)) {
        snackOn(context, 'Prescription saved. The patient can see it now.');
        Navigator.pop(context, true);
      } else {
        snackOn(context, errOf(r));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => saving = false);
      snackOn(context, 'Could not reach the server');
    }
  }

  Future<void> pickFollowUp() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: now.add(const Duration(days: 7)), firstDate: now, lastDate: now.add(const Duration(days: 365)), helpText: 'Follow-up visit');
    if (d != null) setState(() => followUp = isoDate(d));
  }

  Future<void> useTemplate() async {
    if (templates.isEmpty) {
      snackOn(context, 'No templates yet. Write a prescription and tap Save as template.');
      return;
    }
    final t = await showModalBottomSheet<Map>(
      context: context,
      builder: (bc) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Choose a template', style: TextStyle(fontWeight: FontWeight.bold))),
          for (final tpl in templates)
            ListTile(
              leading: const Icon(Icons.bookmark_outline),
              title: Text('${tpl['name']}'),
              subtitle: Text('${(tpl['medicines'] as List?)?.length ?? 0} medicine(s)'),
              onTap: () => Navigator.pop(bc, tpl as Map),
            ),
        ]),
      ),
    );
    if (t != null) setState(() => fill(t));
  }

  Future<void> saveTemplate() async {
    if (meds().isEmpty) {
      snackOn(context, 'Add at least one medicine first');
      return;
    }
    final name = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: const Text('Save as template'),
        content: TextField(controller: name, maxLength: 60, decoration: const InputDecoration(labelText: 'Template name, e.g. Viral fever')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dc, true), child: const Text('Save')),
        ],
      ),
    );
    final n = name.text.trim();
    name.dispose();
    if (go != true || !mounted) return;
    if (n.isEmpty) {
      snackOn(context, 'Give the template a name');
      return;
    }
    final r = await apiSend('POST', '/prescriptions/templates', {...body(), 'name': n});
    if (!mounted) return;
    if (ok(r)) {
      final t = await apiGet('/prescriptions/templates');
      final tj = jsonOf(t);
      if (mounted) setState(() => templates = ok(t) && tj is List ? tj : templates);
      if (mounted) snackOn(context, 'Template saved');
    } else {
      snackOn(context, errOf(r));
    }
  }

  Widget medCard(int i) {
    final r = rows[i];
    return Card(
      key: ObjectKey(r),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Expanded(child: TextField(controller: r.name, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: 'Medicine ${i + 1}'))),
            if (rows.length > 1)
              IconButton(
                tooltip: 'Remove medicine',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() {
                  retired.add(rows.removeAt(i));
                }),
              ),
          ]),
          Row(children: [
            Expanded(child: TextField(controller: r.dose, decoration: const InputDecoration(labelText: 'Dose, e.g. 1 tablet twice a day'))),
            const SizedBox(width: 12),
            SizedBox(width: 80, child: TextField(controller: r.days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Days'))),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Prescription')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text('For ${widget.patientName}', style: Theme.of(c).textTheme.titleMedium),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: useTemplate, icon: const Icon(Icons.bookmarks_outlined), label: const Text('Use a template'))),
          const SizedBox(height: 8),
          TextField(controller: dx, maxLength: 300, decoration: const InputDecoration(labelText: 'Diagnosis (optional)', counterText: '')),
          for (var i = 0; i < rows.length; i++) medCard(i),
          if (rows.length < 10)
            Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => setState(() => rows.add(_MedRow())), icon: const Icon(Icons.add), label: const Text('Add medicine'))),
          TextField(controller: tests, maxLength: 300, decoration: const InputDecoration(labelText: 'Lab tests advised (optional)', counterText: '')),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_available),
            title: const Text('Follow-up visit (optional)'),
            subtitle: Text(followUp.isEmpty ? 'Not set' : followUp),
            trailing: followUp.isEmpty ? null : IconButton(tooltip: 'Clear', icon: const Icon(Icons.close), onPressed: () => setState(() => followUp = '')),
            onTap: pickFollowUp,
          ),
          TextField(controller: notes, maxLength: 500, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes for the patient (optional)')),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.check), label: Text(saving ? 'Saving...' : 'Save prescription')),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: saving ? null : saveTemplate, icon: const Icon(Icons.bookmark_add_outlined), label: const Text('Save as template')),
        ]),
      );
}

// ---------------------------------------------------------------- Prescription templates (doctor)
class RxTemplatesPage extends StatefulWidget {
  const RxTemplatesPage({super.key});
  @override
  State<RxTemplatesPage> createState() => _RxTemplatesPageState();
}

class _RxTemplatesPageState extends State<RxTemplatesPage> {
  List items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await apiGet('/prescriptions/templates');
      final j = jsonOf(r);
      if (!mounted) return;
      setState(() {
        items = ok(r) && j is List ? j : [];
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      snackOn(context, 'Could not reach the server');
    }
  }

  Future<void> remove(String id) async {
    await apiSend('DELETE', '/prescriptions/templates/$id');
    if (mounted) load();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Prescription templates')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(children: [
                const Padding(padding: EdgeInsets.all(16), child: Text('Templates are saved from the prescription screen (Save as template). Use them to fill a prescription in one tap.')),
                if (items.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No templates yet.')),
                for (final t in items)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.bookmark_outline),
                      title: Text('${t['name']}'),
                      subtitle: Text(((t['medicines'] as List?) ?? []).map((m) => '${m['name']}').join(', ')),
                      trailing: IconButton(tooltip: 'Delete template', icon: const Icon(Icons.delete_outline), onPressed: () => remove('${t['_id']}')),
                    ),
                  ),
              ]),
      );
}

// ---------------------------------------------------------------- Working hours (doctor)
class WorkingHoursPage extends StatefulWidget {
  const WorkingHoursPage({super.key});
  @override
  State<WorkingHoursPage> createState() => _WorkingHoursPageState();
}

class _WorkingHoursPageState extends State<WorkingHoursPage> {
  static const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  List<int> days = [];
  String start = '09:00', end = '17:00';
  int slot = 30;
  bool loading = true, saving = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await apiGet('/doctors/me/availability');
      final j = jsonOf(r);
      if (!mounted) return;
      setState(() {
        if (ok(r) && j is Map) {
          days = [for (final d in (j['workDays'] as List? ?? [])) (d as num).toInt()];
          start = '${j['startTime'] ?? start}';
          end = '${j['endTime'] ?? end}';
          slot = (j['slotMinutes'] as num?)?.toInt() ?? 30;
        }
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      snackOn(context, 'Could not reach the server');
    }
  }

  String two(int n) => n.toString().padLeft(2, '0');

  Future<void> pick(bool isStart) async {
    final cur = (isStart ? start : end).split(':');
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.tryParse(cur[0]) ?? 9, minute: int.tryParse(cur[1]) ?? 0));
    if (t == null) return;
    setState(() {
      final s = '${two(t.hour)}:${two(t.minute)}';
      if (isStart) {
        start = s;
      } else {
        end = s;
      }
    });
  }

  Future<void> save() async {
    setState(() => saving = true);
    final r = await apiSend('PUT', '/doctors/me/availability', {'workDays': days, 'startTime': start, 'endTime': end, 'slotMinutes': slot});
    if (!mounted) return;
    setState(() => saving = false);
    snackOn(context, ok(r) ? 'Working hours saved' : errOf(r));
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Working hours')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                const Text('Working days', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  for (var i = 0; i < 7; i++)
                    FilterChip(
                      label: Text(names[i]),
                      selected: days.contains(i),
                      onSelected: (v) => setState(() {
                        v ? days.add(i) : days.remove(i);
                        days.sort();
                      }),
                    ),
                ]),
                const SizedBox(height: 12),
                ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.schedule), title: const Text('From'), trailing: Text(start), onTap: () => pick(true)),
                ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.schedule), title: const Text('To'), trailing: Text(end), onTap: () => pick(false)),
                Row(children: [
                  const Text('Time for each visit'),
                  const Spacer(),
                  DropdownButton<int>(
                    value: [15, 20, 30, 45, 60].contains(slot) ? slot : 30,
                    items: [for (final m in [15, 20, 30, 45, 60]) DropdownMenuItem(value: m, child: Text('$m min'))],
                    onChanged: (v) => setState(() => slot = v ?? 30),
                  ),
                ]),
                const SizedBox(height: 16),
                FilledButton(onPressed: saving || days.isEmpty ? null : save, child: Text(saving ? 'Saving...' : 'Save working hours')),
              ]),
      );
}
