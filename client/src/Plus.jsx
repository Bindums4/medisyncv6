import { useEffect, useState } from "react";
import { api } from "./api";

const KIND = { visit: "Visit", prescription: "Prescription", reading: "Reading", record: "Record" };
const stamp = (iso) => { const d = new Date(iso); return isNaN(d) ? "" : d.toLocaleDateString(undefined, { day: "numeric", month: "short", year: "numeric" }); };

/* ---------- Patient: health timeline ---------- */
export function Timeline() {
  const [items, setItems] = useState(null), [err, setErr] = useState("");
  useEffect(() => { api("/plus/timeline").then(setItems).catch((e) => { setErr(e.message); setItems([]); }); }, []);
  return (
    <>
      <h2>Health timeline</h2>
      <p><small>Your visits, prescriptions, readings and records in one place, newest first.</small></p>
      {err && <p className="err">{err}</p>}
      {items === null && <p>Loading...</p>}
      {items && items.length === 0 && !err && <p>Nothing here yet. Book a visit or add a reading to start your timeline.</p>}
      <div className="tl">
        {(items || []).map((x) => (
          <div className={"tl-item " + x.kind} key={x.kind + x.id}>
            <small>{stamp(x.at)} · {KIND[x.kind] || x.kind}</small>
            <div><b>{x.title}</b></div>
            {x.detail ? <small>{x.detail}</small> : null}
          </div>))}
      </div>
    </>
  );
}

/* ---------- Doctor: private notes about one patient ---------- */
export function Notes({ patientId }) {
  const [list, setList] = useState([]), [text, setText] = useState(""), [msg, setMsg] = useState("");
  const load = () => api("/plus/notes/" + patientId).then(setList).catch((e) => setMsg(e.message));
  useEffect(() => { setList([]); setMsg(""); load(); }, [patientId]);
  const add = async () => {
    try { await api("/plus/notes/" + patientId, "POST", { text }); setText(""); setMsg(""); load(); } catch (e) { setMsg(e.message); }
  };
  const del = (id) => api("/plus/notes/" + id, "DELETE").then(load).catch((e) => setMsg(e.message));
  return (
    <div>
      <b>Private notes</b> <small>(only you can see these)</small>
      {list.length === 0 && <p><small>No notes yet.</small></p>}
      {list.map((n) => (
        <div className="row" key={n._id}><span>{n.text}<br /><small>{stamp(n.createdAt)}</small></span>
          <button className="ghost" onClick={() => del(n._id)}>Delete</button></div>))}
      <textarea aria-label="New private note" maxLength={500} rows={2} placeholder="Write a note about this patient" value={text} onChange={(e) => setText(e.target.value)} />
      <button disabled={!text.trim()} onClick={add}>Save note</button>
      {msg && <p className="err" role="alert">{msg}</p>}
    </div>
  );
}

/* ---------- Emergency phone numbers (India) ---------- */
const NUMBERS = [["National emergency", "112"], ["Ambulance", "108"], ["Police", "100"], ["Fire", "101"], ["Ambulance (maternal and child)", "102"], ["Women helpline", "1091"], ["Childline", "1098"]];
export function EmergencyNumbers() {
  return (
    <div className="card">
      <b>Emergency numbers</b>
      {NUMBERS.map(([n, num]) => <div className="row" key={num}><span>{n}</span><a href={"tel:" + num}><b>{num}</b></a></div>)}
    </div>
  );
}

/* ---------- Patient: move a booked visit to another time ---------- */
const todayStr = () => new Date().toLocaleDateString("en-CA");
export function Reschedule({ a, onDone }) {
  const [open, setOpen] = useState(false), [date, setDate] = useState(""), [slots, setSlots] = useState(null), [msg, setMsg] = useState("");
  useEffect(() => {
    setSlots(null);
    if (!open || !date || !a.doctor?._id) return;
    api(`/doctors/${a.doctor._id}/slots?date=${date}`).then(setSlots).catch((e) => { setSlots([]); setMsg(e.message); });
  }, [open, date]);
  const move = async (time) => {
    try { await api(`/appointments/${a._id}/reschedule`, "PATCH", { date, time }); setOpen(false); setDate(""); setMsg(""); onDone(); }
    catch (e) { setMsg(e.message); }
  };
  if (!open) return <button className="ghost" onClick={() => setOpen(true)}>Reschedule</button>;
  return (
    <div className="modal" role="dialog" aria-label="Reschedule visit">
      <div className="card">
        <b>Move your visit with {a.doctor?.name}</b><br /><small>Now: {a.date} at {a.time}</small>
        <label>New date <input type="date" min={todayStr()} value={date} onChange={(e) => { setDate(e.target.value); setMsg(""); }} /></label>
        {date && slots && slots.length === 0 && <p>No free times on this day. Try another date.</p>}
        <div className="slots">{(slots || []).map((s) => <button key={s} onClick={() => move(s)}>{s}</button>)}</div>
        {msg && <p className="err" role="alert">{msg}</p>}
        <button className="ghost" onClick={() => { setOpen(false); setMsg(""); }}>Close</button>
      </div>
    </div>
  );
}

/* ---------- Patient: vaccination record ---------- */
const VSTATUS = { overdue: ["Overdue", "var(--bad)"], soon: ["Due soon", "#b9770e"], ok: ["Next dose planned", "var(--mint)"], none: ["", ""] };
export function Vaccines() {
  const blank = { name: "", date: "", nextDue: "", notes: "" };
  const [list, setList] = useState(null), [f, setF] = useState(blank), [msg, setMsg] = useState("");
  const load = () => api("/plus/vaccines").then(setList).catch((e) => { setMsg(e.message); setList([]); });
  useEffect(() => { load(); }, []);
  const set = (k) => (e) => setF((p) => ({ ...p, [k]: e.target.value }));
  const add = async () => { try { await api("/plus/vaccines", "POST", f); setF(blank); setMsg(""); load(); } catch (e) { setMsg(e.message); } };
  const del = (id) => api("/plus/vaccines/" + id, "DELETE").then(load).catch((e) => setMsg(e.message));
  return (
    <>
      <h2>Vaccinations</h2>
      <p><small>Keep a record of the vaccines you have taken and when the next dose is due.</small></p>
      <div className="card">
        <label>Vaccine name <input maxLength={80} placeholder="For example: Hepatitis B, Tetanus, COVID-19" value={f.name} onChange={set("name")} /></label>
        <label>Date taken <input type="date" max={todayStr()} value={f.date} onChange={set("date")} /></label>
        <label>Next dose due (optional) <input type="date" min={f.date || undefined} value={f.nextDue} onChange={set("nextDue")} /></label>
        <label>Notes (optional) <input maxLength={200} value={f.notes} onChange={set("notes")} /></label>
        <button disabled={!f.name.trim() || !f.date} onClick={add}>Save vaccine</button>
        {msg && <p className="err" role="alert">{msg}</p>}
      </div>
      {list === null && <p>Loading...</p>}
      {list && list.length === 0 && <p>No vaccines saved yet.</p>}
      {(list || []).map((v) => (
        <div className="card row" key={v._id}>
          <span><b>{v.name}</b><br /><small>Taken {stamp(v.date + "T00:00:00")}{v.notes ? " · " + v.notes : ""}</small>
            {v.nextDue ? <><br /><small style={{ color: VSTATUS[v.status]?.[1] }}><b>{VSTATUS[v.status]?.[0]}</b> · {stamp(v.nextDue + "T00:00:00")}</small></> : null}</span>
          <button className="ghost" onClick={() => del(v._id)}>Delete</button>
        </div>))}
    </>
  );
}

/* ---------- Doctor: days away ---------- */
export function DaysOff() {
  const [list, setList] = useState(null), [date, setDate] = useState(""), [msg, setMsg] = useState(""), [bad, setBad] = useState(false);
  useEffect(() => { api("/doctors/me/daysoff").then(setList).catch((e) => { setBad(true); setMsg(e.message); setList([]); }); }, []);
  const add = async () => {
    try {
      const r = await api("/doctors/me/daysoff", "POST", { date });
      setList(r.daysOff); setDate(""); setBad(false);
      setMsg(r.affected ? `Saved. ${r.affected} patient${r.affected > 1 ? "s were" : " was"} asked to reschedule.` : "Day off saved.");
    } catch (e) { setBad(true); setMsg(e.message); }
  };
  const del = (d) => api("/doctors/me/daysoff/" + d, "DELETE").then((x) => { setList(x); setMsg(""); }).catch((e) => { setBad(true); setMsg(e.message); });
  return (
    <>
      <h2>Days off</h2>
      <p><small>Patients cannot book the dates you add here. Patients who already booked that day get a message to reschedule.</small></p>
      <div className="card">
        <label>Date <input type="date" min={todayStr()} value={date} onChange={(e) => setDate(e.target.value)} /></label>
        <button disabled={!date} onClick={add}>Add day off</button>
        {msg && <p className={bad ? "err" : ""} role="status">{msg}</p>}
      </div>
      {list === null && <p>Loading...</p>}
      {list && list.length === 0 && <p>No days off added.</p>}
      {(list || []).map((d) => <div className="card row" key={d}><span>{stamp(d + "T00:00:00")}</span><button className="ghost" onClick={() => del(d)}>Remove</button></div>)}
    </>
  );
}
