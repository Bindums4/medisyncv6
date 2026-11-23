import { useEffect, useState } from "react";
import QRCode from "qrcode";
import { api } from "./api";

/* ---------- Add a visit to the phone or laptop calendar (.ics file) ---------- */
export function addToCalendar(a) {
  const [y, m, d] = a.date.split("-"), [hh, mm] = a.time.split(":");
  const pad = (n) => String(n).padStart(2, "0");
  const end = new Date(Number(y), Number(m) - 1, Number(d), Number(hh), Number(mm) + 30);
  const stamp = new Date().toISOString().replace(/[-:]/g, "").slice(0, 15) + "Z";
  const ics = [
    "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//MediSync//EN", "BEGIN:VEVENT",
    "UID:" + a._id + "@medisync", "DTSTAMP:" + stamp,
    "DTSTART:" + y + m + d + "T" + hh + mm + "00",
    "DTEND:" + end.getFullYear() + pad(end.getMonth() + 1) + pad(end.getDate()) + "T" + pad(end.getHours()) + pad(end.getMinutes()) + "00",
    "SUMMARY:Doctor visit - " + (a.doctor?.name || "MediSync"), "DESCRIPTION:Booked on MediSync",
    "BEGIN:VALARM", "TRIGGER:-PT60M", "ACTION:DISPLAY", "DESCRIPTION:Doctor visit in 1 hour", "END:VALARM",
    "END:VEVENT", "END:VCALENDAR",
  ].join("\r\n");
  const url = URL.createObjectURL(new Blob([ics], { type: "text/calendar" }));
  const el = document.createElement("a");
  el.href = url; el.download = "medisync-visit.ics"; document.body.appendChild(el); el.click(); el.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

/* ---------- Digital health card with QR code ---------- */
export function HealthCard() {
  const [u, setU] = useState(null), [qr, setQr] = useState("");
  useEffect(() => { api("/auth/me").then(setU).catch(() => setU({})); }, []);
  const v = (x, d) => (x ? x : d);
  const text = u ? [
    "MEDISYNC HEALTH CARD", "Name: " + v(u.name, "-"), "Blood group: " + v(u.bloodGroup, "not set"),
    "Allergies: " + v(u.allergies, "none noted"), "Conditions: " + v(u.conditions, "none noted"), "DOB: " + v(u.dob, "-"),
    "Emergency contact: " + v(u.emergencyContact?.name, "-") + " " + v(u.emergencyContact?.phone, ""),
  ].join("\n") : "";
  useEffect(() => { if (text) QRCode.toDataURL(text, { width: 240, margin: 1 }).then(setQr).catch(() => setQr("")); }, [text]);
  if (!u) return <p>Loading...</p>;
  return (
    <>
      <h2>Health card</h2>
      <div className="hcard">
        <div className="hc-main">
          <small>MEDISYNC HEALTH CARD</small>
          <h3>{v(u.name, "-")}</h3>
          <p><b>Blood group:</b> {v(u.bloodGroup, "not set")}</p>
          <p><b>Allergies:</b> {v(u.allergies, "none noted")}</p>
          <p><b>Conditions:</b> {v(u.conditions, "none noted")}</p>
          <p><b>Emergency contact:</b> {v(u.emergencyContact?.name, "-")} {v(u.emergencyContact?.phone, "")}</p>
        </div>
        {qr && <img className="qr" src={qr} alt="QR code with your health card details" />}
      </div>
      <p><small>A doctor can scan this code in an emergency. Fill in your blood group, allergies and emergency contact in Profile and Emergency to complete the card.</small></p>
      {qr && <a href={qr} download="medisync-health-card.png"><button>Download QR image</button></a>}
    </>
  );
}

/* ---------- Nearby hospitals and pharmacies (opens Google Maps) ---------- */
const PLACES = [["Hospitals", "hospitals"], ["Pharmacies", "pharmacies"], ["Clinics", "clinics"], ["Blood banks", "blood bank"], ["Diagnostic labs", "diagnostic lab"], ["Ambulance services", "ambulance service"]];
export function Nearby() {
  return (
    <>
      <h2>Nearby help</h2>
      <p>Tap a button to open Google Maps with the closest places to you.</p>
      <div className="grid">{PLACES.map(([label, q]) => (
        <a key={label} className="card doc" target="_blank" rel="noopener noreferrer" href={"https://www.google.com/maps/search/" + encodeURIComponent(q + " near me")}>
          <b>{label}</b><small>Open in Maps</small>
        </a>))}</div>
      <p><small>In an emergency call 112.</small></p>
    </>
  );
}

/* ---------- Family members ---------- */
export function Family() {
  const [list, setList] = useState([]), [f, setF] = useState({ name: "", relation: "", age: "" }), [msg, setMsg] = useState("");
  const load = () => api("/extras/family").then(setList).catch(() => setList([]));
  useEffect(() => { load(); }, []);
  const add = async () => {
    setMsg("");
    try { await api("/extras/family", "POST", f); setF({ name: "", relation: "", age: "" }); load(); } catch (e) { setMsg(e.message); }
  };
  return (
    <>
      <h2>Family</h2>
      <p>Add family members, then choose them when you book a visit.</p>
      <div className="card">
        <input aria-label="Name" placeholder="Name" value={f.name} onChange={(e) => setF({ ...f, name: e.target.value })} />
        <select aria-label="Relation" value={f.relation} onChange={(e) => setF({ ...f, relation: e.target.value })}>
          <option value="">Relation</option>{["Mother", "Father", "Spouse", "Son", "Daughter", "Brother", "Sister", "Grandparent", "Other"].map((x) => <option key={x}>{x}</option>)}
        </select>
        <input aria-label="Age" placeholder="Age" inputMode="numeric" value={f.age} onChange={(e) => setF({ ...f, age: e.target.value })} />
        {msg && <p className="err" role="alert">{msg}</p>}
        <button onClick={add}>Add family member</button>
      </div>
      {list.length === 0 && <p>No family members yet.</p>}
      {list.map((m) => (
        <div className="card row" key={m._id}>
          <span><b>{m.name}</b><br /><small>{m.relation || "Family"}{m.age !== undefined && m.age !== null ? " · " + m.age + " years" : ""}</small></span>
          <button className="ghost" onClick={() => api("/extras/family/" + m._id, "DELETE").then(load)}>Remove</button>
        </div>))}
    </>
  );
}

/* ---------- Medicine information (general guidance only) ---------- */
const MEDS = [
  ["Paracetamol", "Fever and mild pain", "Do not exceed the dose on the label. Be careful with liver problems and alcohol."],
  ["Ibuprofen", "Pain, inflammation and fever", "Take after food. Avoid with stomach ulcers, kidney problems or in late pregnancy."],
  ["Aspirin", "Pain, fever and blood thinning", "Can irritate the stomach. Not for children with fever. Tell your doctor if you bleed easily."],
  ["Amoxicillin", "Bacterial infections", "Finish the full course. Tell your doctor about penicillin allergy."],
  ["Azithromycin", "Bacterial infections", "Usually taken for a few days. Report rashes or severe diarrhoea."],
  ["Cetirizine", "Allergies, sneezing, itching", "May cause sleepiness. Be careful when driving."],
  ["Loratadine", "Allergies", "Usually causes less sleepiness. Check the dose for children."],
  ["Omeprazole", "Acidity and stomach ulcers", "Best taken before breakfast. Long use needs a doctor's advice."],
  ["Pantoprazole", "Acidity and reflux", "Take before food. Do not use for long without advice."],
  ["Metformin", "Type 2 diabetes", "Take with food. Report severe stomach upset. Kidney checks are needed."],
  ["Amlodipine", "High blood pressure", "May cause ankle swelling. Do not stop suddenly."],
  ["Atorvastatin", "High cholesterol", "Report unexplained muscle pain. Avoid large amounts of grapefruit."],
  ["Salbutamol", "Asthma relief inhaler", "Use for quick relief. If you need it often, see your doctor."],
  ["ORS", "Dehydration from diarrhoea or vomiting", "Mix with clean water exactly as the pack says. Seek help if it does not improve."],
  ["Vitamin D3", "Bone health and vitamin D deficiency", "Take as advised. Too much can raise calcium."],
  ["Iron tablets", "Low iron or anaemia", "May darken stools. Take with water or vitamin C, away from tea and milk."],
  ["Domperidone", "Nausea and vomiting", "Short courses only. Check with your doctor if you have heart problems."],
  ["Montelukast", "Asthma and allergic rhinitis", "Report mood or sleep changes, especially in children."],
  ["Diclofenac", "Pain and inflammation", "Take after food. Avoid with stomach ulcers, heart or kidney disease unless advised."],
  ["Levothyroxine", "Underactive thyroid", "Take on an empty stomach, same time daily. Do not stop without advice."],
];
export function MedInfo() {
  const [q, setQ] = useState("");
  const shown = MEDS.filter(([n, u]) => (n + " " + u).toLowerCase().includes(q.toLowerCase()));
  return (
    <>
      <h2>Medicine info</h2>
      <input className="search" aria-label="Search medicines" placeholder="Search a medicine or a use" value={q} onChange={(e) => setQ(e.target.value)} />
      {shown.length === 0 && <p>No match. Ask your doctor or pharmacist.</p>}
      {shown.map(([n, u, c]) => (
        <div className="card" key={n}><b>{n}</b><br /><small>Used for: {u}</small><p>{c}</p></div>))}
      <p><small>General information only, not medical advice. Always follow your doctor's prescription.</small></p>
    </>
  );
}

/* ---------- Doctor: schedule and earnings ---------- */
export function DoctorEarnings() {
  const [s, setS] = useState(null);
  useEffect(() => { api("/extras/doctor-stats").then(setS).catch(() => setS({ week: [], ahead: [], fee: 0, today: 0, upcoming: 0, done: 0, earnings: 0, paidCount: 0 })); }, []);
  if (!s) return <p>Loading...</p>;
  const mx = Math.max(1, ...(s.week || []).map((x) => x.count));
  const day = (d) => new Date(d + "T00:00:00").toLocaleDateString([], { weekday: "short", day: "numeric", month: "short" });
  return (
    <>
      <h2>Earnings and schedule</h2>
      <div className="grid">
        {[["Today", s.today], ["Upcoming", s.upcoming], ["Completed", s.done], ["Estimated earnings", "\u20B9" + s.earnings]].map(([k, v]) => (
          <div className="card" key={k}><b style={{ fontSize: 28 }}>{v}</b><br /><small>{k}</small></div>))}
      </div>
      <div className="card"><b>Visits in the last 7 days</b>
        <div className="bars">{(s.week || []).map((x) => (
          <div key={x.date} className="barcol"><small>{x.count}</small><div className="vbar" style={{ height: 8 + (x.count / mx) * 90 }} /><small>{day(x.date).split(" ")[0]}</small></div>))}</div>
      </div>
      <div className="card"><b>Next 7 days</b>
        {(s.ahead || []).map((x) => <div className="row" key={x.date}><span>{day(x.date)}</span><span className={"pill " + (x.count ? "ok" : "")}>{x.count} booked</span></div>)}
      </div>
      <p><small>Earnings are estimated as paid visits times your current fee ({"\u20B9"}{s.fee}). Set your working days and hours on the Appointments page.</small></p>
    </>
  );
}

/* ---------- Admin: announcements ---------- */
export function AdminAnnounce() {
  const [list, setList] = useState([]), [f, setF] = useState({ title: "", body: "" }), [msg, setMsg] = useState("");
  const load = () => api("/extras/announcements").then(setList).catch(() => setList([]));
  useEffect(() => { load(); }, []);
  const send = async () => {
    setMsg("");
    try { await api("/extras/announcements", "POST", f); setF({ title: "", body: "" }); setMsg("Sent to all patients"); load(); } catch (e) { setMsg(e.message); }
  };
  return (
    <>
      <h2>Announcements</h2>
      <div className="card">
        <input aria-label="Title" placeholder="Title (for example Clinic closed on Sunday)" value={f.title} onChange={(e) => setF({ ...f, title: e.target.value })} />
        <textarea aria-label="Message" placeholder="Message" rows={3} value={f.body} onChange={(e) => setF({ ...f, body: e.target.value })} />
        {msg && <p role="status">{msg}</p>}
        <button onClick={send}>Send to all patients</button>
      </div>
      {list.map((a) => (
        <div className="card row" key={a._id}>
          <span><b>{a.title}</b><br /><small>{a.body}</small></span>
          <button className="ghost" onClick={() => api("/extras/announcements/" + a._id, "DELETE").then(load)}>Delete</button>
        </div>))}
    </>
  );
}

/* ---------- Profile photos ---------- */
export function Avatar({ src, name, size = 48 }) {
  const init = ((name || "?").replace(/^Dr\.?\s+/i, "").trim()[0] || "?").toUpperCase();
  const st = { width: size, height: size, borderRadius: "50%", flex: "none" };
  return src
    ? <img src={src} alt={name ? "Photo of " + name : "Profile photo"} style={{ ...st, objectFit: "cover" }} />
    : <span aria-hidden="true" style={{ ...st, display: "inline-grid", placeItems: "center", background: "var(--soft)", color: "var(--mint)", fontWeight: 700, fontSize: size * 0.42 }}>{init}</span>;
}

function shrink(file, max = 256) {
  return new Promise((resolve, reject) => {
    const img = new Image(), url = URL.createObjectURL(file);
    img.onload = () => {
      const s = Math.min(1, max / Math.max(img.width, img.height)), c = document.createElement("canvas");
      c.width = Math.max(1, Math.round(img.width * s)); c.height = Math.max(1, Math.round(img.height * s));
      c.getContext("2d").drawImage(img, 0, 0, c.width, c.height);
      URL.revokeObjectURL(url);
      let q = 0.85, out = c.toDataURL("image/jpeg", q);
      while (out.length > 60000 && q > 0.3) { q -= 0.1; out = c.toDataURL("image/jpeg", q); }
      if (out.length > 85000) reject(new Error("That photo is too large. Try another one."));
      else resolve(out);
    };
    img.onerror = () => { URL.revokeObjectURL(url); reject(new Error("Could not read that image.")); };
    img.src = url;
  });
}

export function AvatarPicker({ src, name, onChange }) {
  const [msg, setMsg] = useState(""), [busy, setBusy] = useState(false);
  const pick = async (e) => {
    const file = e.target.files && e.target.files[0];
    e.target.value = "";
    if (!file) return;
    setMsg(""); setBusy(true);
    try { const data = await shrink(file); const u = await api("/auth/me", "PATCH", { avatar: data }); onChange(u.avatar || data); }
    catch (er) { setMsg(er.message); } finally { setBusy(false); }
  };
  const remove = async () => {
    setMsg(""); setBusy(true);
    try { await api("/auth/me", "PATCH", { avatar: "" }); onChange(""); } catch (er) { setMsg(er.message); } finally { setBusy(false); }
  };
  return (
    <div className="avrow">
      <Avatar src={src} name={name} size={84} />
      <div>
        <label className="filebtn">{busy ? "Saving..." : src ? "Change photo" : "Add photo"}
          <input type="file" accept="image/*" onChange={pick} disabled={busy} style={{ display: "none" }} /></label>
        {src && <button className="ghost" onClick={remove} disabled={busy}>Remove</button>}
        {msg && <p className="err" role="alert">{msg}</p>}
      </div>
    </div>
  );
}
