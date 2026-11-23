import { useEffect, useState } from "react";
import { Avatar } from "./Features";
import { api, download, openVideo } from "./api";
import { useT } from "./i18n";

const DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

function Availability() {
  const [av, setAv] = useState(null), [msg, setMsg] = useState("");
  useEffect(() => { api("/doctors/me/availability").then(setAv).catch((e) => setMsg(e.message)); }, []);
  if (!av) return msg ? <p className="err">{msg}</p> : null;
  const toggle = (d) => setAv({ ...av, workDays: av.workDays.includes(d) ? av.workDays.filter((x) => x !== d) : [...av.workDays, d].sort() });
  const save = () => api("/doctors/me/availability", "PUT", av).then(() => setMsg("Availability saved")).catch((e) => setMsg(e.message));
  return (
    <div className="card">
      <b>My working hours</b>
      <div className="slots">{DAYS.map((n, d) => <button key={n} className={av.workDays.includes(d) ? "on" : ""} aria-pressed={av.workDays.includes(d)} onClick={() => toggle(d)}>{n}</button>)}</div>
      <div className="row">
        <label>From <input type="time" value={av.startTime} onChange={(e) => setAv({ ...av, startTime: e.target.value })} /></label>
        <label>To <input type="time" value={av.endTime} onChange={(e) => setAv({ ...av, endTime: e.target.value })} /></label>
        <label>Slot <select value={av.slotMinutes} onChange={(e) => setAv({ ...av, slotMinutes: +e.target.value })}>
          {[15, 20, 30, 45, 60].map((n) => <option key={n} value={n}>{n} min</option>)}</select></label>
      </div>
      <button onClick={save}>Save hours</button>
      {msg && <p role="status">{msg}</p>}
    </div>
  );
}

function Rx({ a, onClose }) {
  const blank = { name: "", dose: "", days: 5 };
  const [dx, setDx] = useState(""), [notes, setNotes] = useState(""), [tests, setTests] = useState(""), [followUp, setFollowUp] = useState("");
  const [meds, setMeds] = useState([blank]), [msg, setMsg] = useState(""), [tpls, setTpls] = useState([]), [tplName, setTplName] = useState("");
  const fill = (p) => { setDx(p.diagnosis || ""); setNotes(p.notes || ""); setTests(p.tests || ""); setMeds(p.medicines && p.medicines.length ? p.medicines.map((m) => ({ name: m.name, dose: m.dose || "", days: m.days })) : [blank]); };
  const loadTpls = () => api("/prescriptions/templates").then(setTpls).catch(() => {});
  useEffect(() => {
    api(`/prescriptions/for/${a._id}`).then((p) => { if (p) { fill(p); setFollowUp(p.followUp || ""); } }).catch(() => {});
    loadTpls();
  }, [a._id]);
  const set = (i, k, v) => setMeds(meds.map((m, j) => j === i ? { ...m, [k]: v } : m));
  const body = { diagnosis: dx, notes, tests, medicines: meds };
  const save = () => api("/prescriptions", "POST", { ...body, appointment: a._id, followUp })
    .then(() => { setMsg("Prescription saved. The patient can download it."); setTimeout(onClose, 1200); }).catch((e) => setMsg(e.message));
  const saveTpl = () => api("/prescriptions/templates", "POST", { ...body, name: tplName })
    .then(() => { setMsg("Template saved."); setTplName(""); loadTpls(); }).catch((e) => setMsg(e.message));
  return (
    <div className="card">
      <b>Prescription for {a.patient?.name}</b>
      {tpls.length > 0 && (
        <select aria-label="Use a template" value="" onChange={(e) => { const t = tpls.find((x) => x._id === e.target.value); if (t) fill(t); }}>
          <option value="">Use a saved template...</option>{tpls.map((t) => <option key={t._id} value={t._id}>{t.name}</option>)}
        </select>)}
      <input aria-label="Diagnosis" placeholder="Diagnosis (optional)" value={dx} onChange={(e) => setDx(e.target.value)} />
      {meds.map((m, i) => (
        <div className="row" key={i}>
          <input aria-label="Medicine" placeholder="Medicine" value={m.name} onChange={(e) => set(i, "name", e.target.value)} />
          <input aria-label="Dose" placeholder="Dose, e.g. 1 tablet twice a day" value={m.dose} onChange={(e) => set(i, "dose", e.target.value)} />
          <input aria-label="Days" type="number" min="1" style={{ maxWidth: 80 }} value={m.days} onChange={(e) => set(i, "days", e.target.value)} />
        </div>))}
      {meds.length < 10 && <button className="ghost" onClick={() => setMeds([...meds, { ...blank }])}>Add medicine</button>}
      <input aria-label="Tests advised" placeholder="Lab tests advised (optional), e.g. CBC, Blood sugar" value={tests} onChange={(e) => setTests(e.target.value)} />
      <label>Follow-up visit (optional) <input type="date" min={new Date().toLocaleDateString("en-CA")} value={followUp} onChange={(e) => setFollowUp(e.target.value)} /></label>
      <textarea aria-label="Notes" rows="2" placeholder="Notes (optional)" value={notes} onChange={(e) => setNotes(e.target.value)} />
      <button onClick={save}>Save prescription</button> <button className="ghost" onClick={() => download(`/prescriptions/${a._id}/pdf`, "prescription.pdf").catch((e) => setMsg(e.message))}>Download PDF</button> <button className="ghost" onClick={onClose}>Close</button>
      <div className="row">
        <input aria-label="Template name" placeholder="Save these medicines as a template, name it..." value={tplName} onChange={(e) => setTplName(e.target.value)} />
        <button className="ghost" disabled={!tplName.trim()} onClick={saveTpl}>Save template</button>
      </div>
      {msg && <p role="status">{msg}</p>}
    </div>
  );
}

export function DoctorDash() {
  const t = useT();
  const [list, setList] = useState([]), [rx, setRx] = useState(null), [msg, setMsg] = useState(""), [fu, setFu] = useState({});
  const load = () => api("/appointments/doctor").then(setList);
  useEffect(() => { load(); }, []);
  return (
    <>
      <h2>{t("appointments")}</h2>
      <Availability />
      {msg && <p className="err">{msg}</p>}
      {list.length === 0 && <p>No appointments yet.</p>}
      {list.map((a) => (
        <div key={a._id}>
          <div className="card row">
            <span className="dcard"><Avatar src={a.patient?.avatar} name={a.patient?.name} size={40} /><span><b>{a.patient?.name}</b><br /><small>{a.date} · {a.time} · {a.status}{a.paid ? " · paid" : ""}</small></span></span>
            <span className="acts">
              {a.status !== "cancelled" && <button className="ghost" onClick={() => openVideo(a._id, setMsg)}>Video call</button>}
              {a.status !== "cancelled" && <button className="ghost" onClick={() => setRx(rx === a._id ? null : a._id)}>Prescription</button>}
              {a.status === "booked" && <>
                <select aria-label="Suggest a follow-up" value={fu[a._id] || ""} onChange={(e) => setFu({ ...fu, [a._id]: e.target.value })}>
                  <option value="">No follow-up</option><option value="7">Follow-up in 7 days</option><option value="14">Follow-up in 14 days</option><option value="30">Follow-up in 30 days</option>
                </select>
                <button onClick={() => api(`/appointments/${a._id}/done`, "PATCH", fu[a._id] ? { followUpDays: Number(fu[a._id]) } : undefined).then(load)}>Mark done</button></>}
            </span>
          </div>
          {rx === a._id && <Rx a={a} onClose={() => setRx(null)} />}
        </div>))}
    </>
  );
}

export function Admin() {
  const t = useT();
  const [s, setS] = useState(null);
  useEffect(() => { api("/admin/stats").then(setS); }, []);
  if (!s) return <p>Loading…</p>;
  const mx = Math.max(1, ...Object.values(s.byDoctor));
  return (
    <>
      <h2>{t("insights")}</h2>
      <div className="grid">
        {[["Patients", s.patients], ["Doctors", s.doctors], ["Appointments", s.appointments], ["Cancelled", s.cancelled], ["Revenue", "₹" + s.revenue]]
          .map(([k, v]) => <div className="card" key={k}><b style={{ fontSize: 28 }}>{v}</b><br /><small>{k}</small></div>)}
      </div>
      <div className="card"><b>Appointments by doctor</b>
        {Object.entries(s.byDoctor).map(([n, v]) => (
          <div key={n} style={{ margin: "8px 0" }}><small>{n} · {v}</small><div className="bar" style={{ width: (v / mx) * 100 + "%" }} /></div>))}
      </div>
    </>
  );
}
