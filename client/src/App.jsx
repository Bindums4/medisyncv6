import { useEffect, useState } from "react";
import { api } from "./api";
import { notify } from "./alerts";
import { LANGS, LangCtx, useT } from "./i18n";
import { Book, Chat, Emergency, Records, ReminderWatcher, Reminders, Symptoms } from "./Patient";
import { Admin, DoctorDash } from "./Staff";
import { Home } from "./Home";
import { DaysOff, Timeline, Vaccines } from "./Plus";
import { AdminAnnounce, DoctorEarnings, Family, HealthCard, MedInfo, Nearby } from "./Features";
import { AdminUsers, AdminVisits, Bell, DoctorProfile, Patients, Profile, Vitals } from "./Extra";

function Prefs({ lang, setLang, theme, setTheme, big, setBig }) {
  return (
    <div className="prefs">
      <select aria-label="Language" value={lang} onChange={(e) => setLang(e.target.value)}>{LANGS.map(([k, n]) => <option key={k} value={k}>{n}</option>)}</select>
      <button className="ghost" aria-label="Switch light or dark theme" onClick={() => setTheme(theme === "dark" ? "light" : "dark")}>{theme === "dark" ? "Light" : "Dark"}</button>
      <button className="ghost" aria-label="Larger text" aria-pressed={big} onClick={() => setBig(!big)}>A+</button>
    </div>
  );
}

const DEMO = [["Patient", "patient@medisync.com", "Patient@123"], ["Doctor", "ananya@medisync.com", "Doctor@123"], ["Admin", "admin@medisync.com", "Admin@123"]];
const FEATURES = ["Book doctors in seconds", "Chat and video consultations", "Digital prescriptions", "Medicine reminders", "Emergency SOS", "English, Kannada and Hindi"];

function Auth({ onDone, prefs }) {
  const t = useT();
  const resetToken = new URLSearchParams(window.location.search).get("reset");
  const [mode, setMode] = useState(resetToken ? "reset" : "login"), [who, setWho] = useState("patient");
  const [f, setF] = useState({}), [err, setErr] = useState(""), [info, setInfo] = useState(""), [busy, setBusy] = useState(false), [show, setShow] = useState(false);
  const set = (k) => (e) => setF({ ...f, [k]: e.target.value });
  const finish = (d) => { localStorage.token = d.token; localStorage.name = d.user.name; localStorage.role = d.user.role; onDone(); };
  const run = async (fn) => { setErr(""); setInfo(""); setBusy(true); try { await fn(); } catch (e) { setErr(e.message); } finally { setBusy(false); } };
  const go = () => run(async () => {
    if (mode === "forgot") { setInfo((await api("/auth/forgot", "POST", { email: f.email })).message); return; }
    if (mode === "reset") {
      await api("/auth/reset", "POST", { token: resetToken, password: f.password });
      window.history.replaceState(null, "", "/"); setMode("login"); setInfo("Password changed. Log in with your new password."); return;
    }
    const path = mode === "register" && who === "doctor" ? "register-doctor" : mode;
    finish(await api("/auth/" + path, "POST", { ...f, email: (f.email || "").trim().toLowerCase() }));
  });
  const demo = (email, password) => run(async () => finish(await api("/auth/login", "POST", { email, password })));
  const label = { login: t("login"), register: t("register"), forgot: t("sendLink"), reset: t("setPass") }[mode];
  const showTabs = mode === "login" || mode === "register";
  return (
    <div className="ap">
      <section className="ap-hero" aria-hidden="false">
        <div className="blob b1" /><div className="blob b2" />
        <div className="ap-brand"><span className="logo">+</span> Medi<span>Sync</span></div>
        <h2>Healthcare that feels effortless.</h2>
        <p>Find the right doctor, book a visit and stay on top of your health from one app.</p>
        <ul>{FEATURES.map((x) => <li key={x}>{x}</li>)}</ul>
      </section>
      <section className="ap-form" onKeyDown={(e) => e.key === "Enter" && go()}>
        <div className="row"><h1 className="ap-small">Medi<span>Sync</span></h1>{prefs}</div>
        <h2>{mode === "login" ? "Welcome back" : mode === "register" ? "Create your account" : mode === "forgot" ? "Forgot password" : "New password"}</h2>
        {showTabs && <div className="seg" role="tablist">
          <button role="tab" aria-selected={who === "patient"} className={who === "patient" ? "sel" : ""} onClick={() => setWho("patient")}>I am a patient</button>
          <button role="tab" aria-selected={who === "doctor"} className={who === "doctor" ? "sel" : ""} onClick={() => setWho("doctor")}>I am a doctor</button>
        </div>}
        {mode === "register" && <input aria-label={t("name")} placeholder={who === "doctor" ? "Full name (for example Asha Menon)" : t("name")} value={f.name || ""} onChange={set("name")} />}
        {mode !== "reset" && <input aria-label={t("email")} placeholder={t("email")} type="email" autoCapitalize="none" autoCorrect="off" value={f.email || ""} onChange={set("email")} />}
        {mode !== "forgot" && <div className="pw"><input aria-label={t("password")} placeholder={mode === "reset" ? t("newPass") : t("password")} type={show ? "text" : "password"} value={f.password || ""} onChange={set("password")} />
          <button type="button" className="ghost eye" onClick={() => setShow(!show)} aria-label="Show or hide password">{show ? "Hide" : "Show"}</button></div>}
        {mode === "register" && who === "doctor" && <>
          <input aria-label="Specialty" placeholder="Specialty (for example Cardiologist)" value={f.specialty || ""} onChange={set("specialty")} />
          <div className="two"><input aria-label="Consultation fee" placeholder="Fee in rupees" inputMode="numeric" value={f.fee || ""} onChange={set("fee")} />
            <input aria-label="Years of experience" placeholder="Years of experience" inputMode="numeric" value={f.experience || ""} onChange={set("experience")} /></div>
          <input aria-label="Clinic code" placeholder="Clinic code (only if your clinic gave you one)" value={f.code || ""} onChange={set("code")} />
        </>}
        {err && <p className="err" role="alert">{err}</p>}
        {info && <p role="status">{info}</p>}
        <button className="cta" disabled={busy} onClick={go}>{busy ? "Please wait..." : label}</button>
        {showTabs && <>
          <a href="#" onClick={(e) => { e.preventDefault(); setMode(mode === "login" ? "register" : "login"); setErr(""); }}>{mode === "login" ? t("newHere") : t("haveAcc")}</a>
          <a href="#" onClick={(e) => { e.preventDefault(); setMode("forgot"); setErr(""); }}>{t("forgot")}</a></>}
        {(mode === "forgot" || mode === "reset") && <a href="#" onClick={(e) => { e.preventDefault(); setMode("login"); setErr(""); }}>{t("login")}</a>}
        {mode === "login" && import.meta.env.VITE_DEMO !== "0" && <div className="demo">
          <small>Quick demo login</small>
          <div className="acts">{DEMO.map(([n, em, pw]) => <button key={n} className="ghost" disabled={busy} onClick={() => demo(em, pw)}>{n}</button>)}</div>
        </div>}
      </section>
    </div>
  );
}

const TABS = {
  patient: [["home", Home], ["book", Book], ["vitals", Vitals], ["reminders", Reminders], ["records", Records], ["symptoms", Symptoms], ["chat", Chat], ["emergency", Emergency], ["profile", Profile], ["card", HealthCard], ["nearby", Nearby], ["family", Family], ["medicines", MedInfo], ["timeline", Timeline], ["vaccines", Vaccines]],
  doctor: [["appointments", DoctorDash], ["earnings", DoctorEarnings], ["patients", Patients], ["chat", Chat], ["profile", DoctorProfile], ["daysoff", DaysOff]],
  admin: [["insights", Admin], ["visits", AdminVisits], ["users", AdminUsers], ["announce", AdminAnnounce]],
};

function Shell({ onLogout, prefs }) {
  const t = useT(), [tab, setTab] = useState(0), [alerts, setAlerts] = useState([]);
  const fire = (text) => { notify(text); setAlerts((a) => [...a, { id: Date.now() + Math.random(), text }]); };
  const tabs = TABS[localStorage.role] || TABS.patient, View = tabs[Math.min(tab, tabs.length - 1)][1];
  return (
    <div className="wrap">
      {localStorage.role === "patient" && <ReminderWatcher onFire={fire} />}
      {alerts.length > 0 && (
        <div className="alerts" role="alert">
          {alerts.map((a) => (
            <div key={a.id} className="alert"><span>Time to take {a.text}</span>
              <button onClick={() => setAlerts((x) => x.filter((y) => y.id !== a.id))}>Taken</button></div>))}
        </div>)}
      <header><h1>Medi<span>Sync</span></h1>
        <div className="prefs">{prefs}<Bell /><button className="ghost" onClick={onLogout}>{t("logout")} ({localStorage.name})</button></div></header>
      <nav aria-label="Main">{tabs.map(([k], i) => <button key={k} className={i === tab ? "on" : "ghost"} aria-current={i === tab} onClick={() => setTab(i)}>{t(k)}</button>)}</nav>
      <main><View go={setTab} /></main>
    </div>
  );
}

export default function App() {
  const [ok, setOk] = useState(!!localStorage.token);
  const [lang, setLang] = useState(localStorage.lang || "en");
  const [theme, setTheme] = useState(localStorage.theme || (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"));
  const [big, setBig] = useState(localStorage.big === "1");
  useEffect(() => { localStorage.lang = lang; document.documentElement.lang = lang; }, [lang]);
  useEffect(() => { localStorage.theme = theme; document.documentElement.dataset.theme = theme; }, [theme]);
  useEffect(() => { localStorage.big = big ? "1" : "0"; document.documentElement.style.fontSize = big ? "20px" : ""; }, [big]);
  const prefs = <Prefs {...{ lang, setLang, theme, setTheme, big, setBig }} />;
  const logout = () => { ["token", "name", "role"].forEach((k) => localStorage.removeItem(k)); setOk(false); };
  return (
    <LangCtx.Provider value={{ lang }}>
      {ok ? <Shell onLogout={logout} prefs={prefs} /> : <Auth onDone={() => setOk(true)} prefs={prefs} />}
    </LangCtx.Provider>
  );
}
