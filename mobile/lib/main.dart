import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'pages.dart';
import 'doctor.dart';
import 'welcome.dart';
import 'extras.dart';

// USB cable: the phone reaches your laptop at 127.0.0.1 (RUN-MOBILE.bat sets this up).
// Online link: build with  --dart-define=API=https://your-api.onrender.com/api
const _defaultBase = String.fromEnvironment('API', defaultValue: 'http://127.0.0.1:5000/api');

/// The server address. The person can change it on the login screen (Server button), so the phone can
/// use the laptop over Wi-Fi without a cable. The choice is saved on the phone.
String base = _defaultBase;

Future<void> loadServer() async {
  final p = await SharedPreferences.getInstance();
  final s = p.getString('server');
  if (s != null && s.isNotEmpty) base = s;
}

/// Turns "192.168.1.5", "192.168.1.5:5000" or a full link into an API address, or null if it is not valid.
String? normalizeServer(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;
  if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'http://$s';
  s = s.replaceAll(RegExp(r'/+$'), '');
  final u = Uri.tryParse(s);
  if (u == null || u.host.isEmpty) return null;
  if (!u.hasPort && u.scheme == 'http') s = '$s:5000';
  if (!s.endsWith('/api')) s = '$s/api';
  return s;
}

String serverShown() => base.replaceAll(RegExp(r'/api$'), '').replaceFirst('http://', '');

Future<void> serverDialog(BuildContext c) async {
  final ctl = TextEditingController(text: serverShown());
  final pick = await showDialog<String>(
    context: c,
    builder: (dc) => AlertDialog(
      title: const Text('Server address'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Wi-Fi: type your laptop address, for example 192.168.1.5 (phone and laptop on the same Wi-Fi).\nUSB cable: use 127.0.0.1.'),
        TextField(controller: ctl, keyboardType: TextInputType.url, autocorrect: false, decoration: const InputDecoration(labelText: 'Address')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(dc, '#reset'), child: const Text('Reset')),
        FilledButton(onPressed: () => Navigator.pop(dc, ctl.text), child: const Text('Save')),
      ],
    ),
  );
  if (pick == null) return;
  final p = await SharedPreferences.getInstance();
  if (pick == '#reset') {
    await p.remove('server');
    base = _defaultBase;
  } else {
    final n = normalizeServer(pick);
    if (n == null) {
      if (c.mounted) snackOn(c, 'That address does not look right. Example: 192.168.1.5');
      return;
    }
    await p.setString('server', n);
    base = n;
  }
  try {
    final r = await http.get(Uri.parse('$base/health')).timeout(const Duration(seconds: 5));
    if (c.mounted) snackOn(c, r.statusCode == 200 ? 'Connected to the server' : 'Saved, but the server answered with an error');
  } catch (_) {
    if (c.mounted) snackOn(c, 'Saved, but cannot reach ${serverShown()}. Is RUN-MEDISYNC.bat running?');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadServer();
  runApp(const MediSync());
}

class MediSync extends StatelessWidget {
  const MediSync({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        title: 'MediSync',
        theme: ThemeData(colorSchemeSeed: const Color(0xFF17A88A), useMaterial3: true),
        darkTheme: ThemeData(colorSchemeSeed: const Color(0xFF17A88A), brightness: Brightness.dark, useMaterial3: true),
        themeMode: ThemeMode.system,
        home: const Gate(),
      );
}

Future<Map<String, String>> headers() async {
  final p = await SharedPreferences.getInstance();
  return {'Content-Type': 'application/json', 'Authorization': 'Bearer ${p.getString('token') ?? ''}'};
}

// ---------- shared request helpers (used by more.dart) ----------
Future<http.Response> apiGet(String path) async => http.get(Uri.parse('$base$path'), headers: await headers());

Future<http.Response> apiSend(String method, String path, [Map? body]) async {
  final req = http.Request(method, Uri.parse('$base$path'))..headers.addAll(await headers());
  if (body != null) req.body = jsonEncode(body);
  return http.Response.fromStream(await req.send());
}

bool ok(http.Response r) => r.statusCode >= 200 && r.statusCode < 300;

dynamic jsonOf(http.Response r) {
  try {
    return jsonDecode(r.body);
  } catch (_) {
    return null;
  }
}

String errOf(http.Response r) {
  final j = jsonOf(r);
  return j is Map && j['error'] != null ? '${j['error']}' : 'Something went wrong';
}

void snackOn(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

/// Clears the saved login and returns to the login screen.
Future<void> logout(BuildContext c) async {
  final p = await SharedPreferences.getInstance();
  await p.remove('token');
  if (c.mounted) Navigator.of(c).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const Gate()), (_) => false);
}

class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  bool? loggedIn;
  bool seen = true;
  String role = 'patient';

  @override
  void initState() {
    super.initState();
    check();
  }

  Future<void> check() async {
    final p = await SharedPreferences.getInstance();
    final has = p.getString('token') != null;
    final sawIntro = p.getBool('seen') ?? false;
    var r = 'patient';
    if (has) {
      try {
        final res = await apiGet('/auth/me');
        final j = jsonOf(res);
        if (ok(res) && j is Map && j['role'] != null) r = j['role'].toString();
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        loggedIn = has;
        seen = sawIntro;
        role = r;
      });
    }
  }

  @override
  Widget build(BuildContext c) {
    if (loggedIn == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!seen) return Welcome(onDone: check);
    if (!loggedIn!) return Login(onDone: check);
    return role == 'doctor' ? const DoctorHome() : const Shell();
  }
}

class Login extends StatefulWidget {
  final VoidCallback onDone;
  const Login({super.key, required this.onDone});
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final name = TextEditingController(), email = TextEditingController(), pass = TextEditingController();
  final specialty = TextEditingController(), fee = TextEditingController(), exp = TextEditingController();
  bool doctor = false, signup = false, hide = true, busy = false;
  String err = '';

  Future<void> send(String path, Map body) async {
    setState(() {
      busy = true;
      err = '';
    });
    try {
      final r = await http.post(Uri.parse('$base/auth/$path'),
          headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
      final d = jsonDecode(r.body);
      if (r.statusCode == 200 || r.statusCode == 201) {
        (await SharedPreferences.getInstance()).setString('token', d['token']);
        widget.onDone();
      } else {
        setState(() => err = d['error'] ?? 'Something went wrong');
      }
    } catch (_) {
      setState(() => err = 'Cannot reach the server at ${serverShown()}. Check RUN-MEDISYNC.bat is running, then tap Server below to fix the address.');
    }
    if (mounted) setState(() => busy = false);
  }

  void submit() {
    final e = email.text.trim().toLowerCase(), p = pass.text.trim();
    if (!signup) {
      send('login', {'email': e, 'password': p});
      return;
    }
    final body = <String, dynamic>{'name': name.text.trim(), 'email': e, 'password': p};
    if (doctor) {
      body['specialty'] = specialty.text.trim();
      body['fee'] = fee.text.trim();
      body['experience'] = exp.text.trim();
    }
    send(doctor ? 'register-doctor' : 'register', body);
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 72, 24, 36),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF0B6E5C), Color(0xFF3CCFB0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.add, size: 40, color: Color(0xFF0B6E5C)),
              ),
              const SizedBox(height: 16),
              const Text('MediSync', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Healthcare that feels effortless.', style: TextStyle(color: Colors.white70, fontSize: 16)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Patient'), icon: Icon(Icons.person)),
                  ButtonSegment(value: true, label: Text('Doctor'), icon: Icon(Icons.medical_services)),
                ],
                selected: {doctor},
                onSelectionChanged: (s) => setState(() => doctor = s.first),
              ),
              const SizedBox(height: 18),
              Text(signup ? 'Create your account' : 'Welcome back', style: Theme.of(c).textTheme.headlineSmall),
              const SizedBox(height: 12),
              if (signup) ...[
                TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.badge_outlined))),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pass,
                obscureText: hide,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                      icon: Icon(hide ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => hide = !hide)),
                ),
              ),
              if (signup && doctor) ...[
                const SizedBox(height: 10),
                TextField(
                    controller: specialty,
                    decoration: const InputDecoration(
                        labelText: 'Specialty (for example Cardiologist)', prefixIcon: Icon(Icons.local_hospital_outlined))),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: fee,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Fee in rupees'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: exp,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Years of experience'))),
                ]),
              ],
              if (err.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 10), child: Text(err, style: const TextStyle(color: Colors.red))),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : submit,
                style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                child: Text(busy ? 'Please wait...' : (signup ? 'Create account' : 'Log in')),
              ),
              TextButton(
                onPressed: () => setState(() {
                  signup = !signup;
                  err = '';
                }),
                child: Text(signup ? 'Have an account? Log in' : 'New here? Create an account'),
              ),
              TextButton.icon(
                onPressed: busy ? null : () async {
                  await serverDialog(c);
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.wifi_tethering, size: 18),
                label: Text('Server: ${serverShown()}'),
              ),
              if (!signup) ...[
                const Divider(height: 28),
                const Text('Quick demo login', textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: busy ? null : () => send('login', {'email': 'patient@medisync.com', 'password': 'Patient@123'}),
                          child: const Text('Patient'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: OutlinedButton(
                          onPressed: busy ? null : () => send('login', {'email': 'ananya@medisync.com', 'password': 'Doctor@123'}),
                          child: const Text('Doctor'))),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List docs = [];
  String q = '', spec = 'All';
  bool loading = true, onlyFav = false;
  Set<String> favs = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await http.get(Uri.parse('$base/doctors'));
      if (r.statusCode == 200) docs = jsonDecode(r.body);
    } catch (_) {}
    try {
      final f = await apiGet('/plus/favorites');
      final fj = jsonOf(f);
      if (ok(f) && fj is List) favs = {for (final x in fj) '$x'};
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> toggleFav(Map d) async {
    final id = '${d['_id']}';
    final r = await apiSend('POST', '/plus/favorites/$id');
    if (!mounted) return;
    if (!ok(r)) return snack(errOf(r));
    final j = jsonOf(r);
    setState(() {
      if (j is Map && j['favorite'] == true) {
        favs.add(id);
      } else {
        favs.remove(id);
      }
    });
  }

  void snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  String sub(Map d) {
    final q = '${d['qualification'] ?? ''}';
    return '${d['specialty']} · ${d['experience'] ?? 0} yrs · ₹${d['fee']}${q.isEmpty ? '' : '\n$q'}';
  }

  String initial(String n) {
    final s = n.replaceFirst('Dr. ', '').trim();
    return s.isEmpty ? '?' : s[0].toUpperCase();
  }

  Future<void> book(Map d) async {
    String forName = '';
    final fr = await apiGet('/extras/family');
    final fj = jsonOf(fr);
    if (!mounted) return;
    if (ok(fr) && fj is List && fj.isNotEmpty) {
      final pick = await showDialog<String>(
        context: context,
        builder: (_) => SimpleDialog(title: const Text('Booking for'), children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(context, ''), child: const Text('Myself')),
          for (final m in fj)
            SimpleDialogOption(onPressed: () => Navigator.pop(context, '${m['name']}'), child: Text('${m['name']} (${m['relation'] ?? ''})')),
        ]),
      );
      if (pick == null || !mounted) return;
      forName = pick;
    }
    final day = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 60)));
    if (day == null || !mounted) return;
    final date = day.toIso8601String().substring(0, 10);
    final sr = await http.get(Uri.parse('$base/doctors/${d['_id']}/slots?date=$date'));
    if (!mounted) return;
    final List slots = sr.statusCode == 200 ? jsonDecode(sr.body) : [];
    if (slots.isEmpty) {
      snack('No free times on $date. Try another day.');
      return;
    }
    final time = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => ListView(children: [for (final s in slots) ListTile(title: Text('$s'), onTap: () => Navigator.pop(context, '$s'))]),
    );
    if (time == null || !mounted) return;
    final r = await http.post(Uri.parse('$base/appointments'),
        headers: await headers(), body: jsonEncode({'doctor': d['_id'], 'date': date, 'time': time, 'forName': forName}));
    if (!mounted) return;
    snack(r.statusCode == 201 ? 'Appointment booked' : jsonDecode(r.body)['error']);
  }

  @override
  Widget build(BuildContext c) {
    final specs = ['All', ...{for (final d in docs) if (d['specialty'] != null) '${d['specialty']}'}];
    final shown = docs
        .where((d) =>
            (!onlyFav || favs.contains('${d['_id']}')) &&
            (spec == 'All' || d['specialty'] == spec) &&
            ('${d['name']} ${d['specialty']}').toLowerCase().contains(q.toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Find a doctor')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search), hintText: 'Search doctor or specialty', border: OutlineInputBorder()),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
            Padding(
              padding: const EdgeInsets.all(6),
              child: FilterChip(label: const Text('Favorites'), avatar: const Icon(Icons.star, size: 18), selected: onlyFav, onSelected: (v) => setState(() => onlyFav = v)),
            ),
            for (final s in specs)
              Padding(
                padding: const EdgeInsets.all(6),
                child: ChoiceChip(label: Text(s), selected: spec == s, onSelected: (_) => setState(() => spec = s)),
              ),
          ]),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : shown.isEmpty
                  ? Center(child: Text(onlyFav ? 'No favorite doctors yet. Tap the star on a doctor.' : 'No doctors found'))
                  : ListView(children: [
                      for (final d in shown)
                        Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            leading: face(d['avatar'], '${d['name']}'),
                            title: Text('${d['name']}'),
                            subtitle: Text(sub(d)),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                tooltip: favs.contains('${d['_id']}') ? 'Remove from favorites' : 'Save as favorite',
                                icon: Icon(favs.contains('${d['_id']}') ? Icons.star : Icons.star_border, color: Colors.amber.shade700),
                                onPressed: () => toggleFav(d),
                              ),
                              FilledButton(onPressed: () => book(d), child: const Text('Book')),
                            ]),
                          ),
                        ),
                    ]),
        ),
      ]),
    );
  }
}
