import { useEffect, useState } from "react";
import { api } from "./api";
import { Avatar } from "./Features";

const TIPS = [
  "Drink a glass of water first thing in the morning.",
  "A 20 minute walk a day keeps your heart happier.",
  "Sleep 7 to 8 hours. Your body repairs itself at night.",
  "Wash hands for 20 seconds before meals.",
  "Add one extra fruit or vegetable to every meal.",
  "Take short breaks from screens. Look far away for 20 seconds.",
  "Stretch for 5 minutes after sitting for a long time.",
  "Take your medicines at the same time every day.",
  "Breathe in for 4 seconds, hold 4, breathe out 6. Repeat 5 times.",
  "Limit sugary drinks. Water is the best choice.",
];
const today = () => new Date().toLocaleDateString("en-CA");

function Water() {
  const key = "water-" + today();
  const [n, setN] = useState(() => { try { return Number(localStorage.getItem(key)) || 0; } catch { return 0; } });
  const set = (v) => { const x = Math.max(0, Math.min(20, v)); setN(x); try { localStorage.setItem(key, String(x)); } catch { /* ignore */ } };
  return (
    <div className="card">
      <div className="row"><b>Water today</b><small>Goal: 8 glasses</small></div>
      <div className="glasses">{Array.from({ length: 8 }).map((_, i) => <span key={i} className={"glass " + (i < n ? "full" : "")} />)}</div>
      <div className="acts"><button className="ghost" onClick={() => set(n - 1)} aria-label="Remove a glass">-</button>
        <b>{n} / 8</b><button onClick={() => set(n + 1)} aria-label="Add a glass">+ Add glass</button></div>
    </div>
  );
}

export function Home({ go }) {
  const [mine, setMine] = useState(null), [news, setNews] = useState([]), [me, setMe] = useState(null);
  useEffect(() => { api("/appointments/mine").then(setMine).catch(() => setMine([])); api("/extras/announcements").then(setNews).catch(() => {}); api("/auth/me").then(setMe).catch(() => {}); }, []);
  const name = (localStorage.name || "").split(" ")[0];
  const h = new Date().getHours(), hello = h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening";
  const upcoming = (mine || []).filter((a) => a.status === "booked").sort((a, b) => (a.date + a.time).localeCompare(b.date + b.time));
  const next = upcoming[0], done = (mine || []).filter((a) => a.status === "done").length;
  const tip = TIPS[new Date().getDate() % TIPS.length];
  const ACTIONS = [["Book a doctor", 1], ["Health readings", 2], ["Medicine reminders", 3], ["My records", 4], ["Check symptoms", 5], ["Emergency SOS", 7], ["Health card", 9], ["Nearby help", 10], ["Family", 11], ["Medicine info", 12], ["Health timeline", 13], ["Vaccinations", 14]];
  return (
    <>
      <div className="welcome avrow">
        <Avatar src={me?.avatar} name={me?.name || name} size={60} />
        <div><h2>{hello}, {name || "there"}</h2><p>Your health, all in one place.</p></div>
      </div>
      {news[0] && <div className="card news"><small>Clinic announcement</small><p><b>{news[0].title}</b><br />{news[0].body}</p></div>}
      <div className="grid stats">
        <div className="card stat"><b>{upcoming.length}</b><small>Upcoming visits</small></div>
        <div className="card stat"><b>{done}</b><small>Completed visits</small></div>
        <div className="card stat"><b>{mine ? mine.length : "-"}</b><small>Total bookings</small></div>
      </div>
      <div className="card next">
        <small>Next appointment</small>
        {mine === null ? <p>Loading...</p> : next
          ? <p><b>{next.doctor?.name}</b><br />{next.date} at {next.time}</p>
          : <p>No upcoming visit. <button onClick={() => go(1)}>Book now</button></p>}
      </div>
      <h3>Quick actions</h3>
      <div className="grid quick">{ACTIONS.map(([label, i]) => <button key={label} className="card doc" onClick={() => go(i)}>{label}</button>)}</div>
      <Water />
      <div className="card tip"><small>Health tip of the day</small><p>{tip}</p></div>
    </>
  );
}
