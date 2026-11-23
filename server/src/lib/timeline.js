// Turns a patient's visits, prescriptions, readings and records into one list, newest first.
const NAMES = { bp: "Blood pressure", sugar: "Blood sugar", weight: "Weight", heart: "Heart rate", temp: "Temperature", spo2: "Oxygen (SpO2)" };
const UNITS = { bp: "mmHg", sugar: "mg/dL", weight: "kg", heart: "bpm", temp: "°C", spo2: "%" };

const when = (date, time, fallback) => {
  const hm = /^\d{1,2}:\d{2}$/.test(time || "") ? String(time).padStart(5, "0") : "00:00";
  const t = new Date(`${date}T${hm}:00`);
  return isNaN(t) ? new Date(fallback) : t;
};

function buildTimeline({ apts = [], rx = [], vit = [], recs = [] } = {}, limit = 50) {
  const out = [];
  for (const a of apts) out.push({
    kind: "visit", id: String(a._id), at: when(a.date, a.time, a.createdAt),
    title: "Visit with " + (a.doctor?.name || "doctor"),
    detail: [a.status, a.forName && "for " + a.forName, a.paid && "paid"].filter(Boolean).join(" · "),
  });
  for (const x of rx) out.push({
    kind: "prescription", id: String(x._id), at: new Date(x.createdAt),
    title: "Prescription from " + (x.doctor?.name || "doctor"),
    detail: x.diagnosis || (x.medicines || []).map((m) => m.name).filter(Boolean).join(", "),
  });
  for (const v of vit) out.push({
    kind: "reading", id: String(v._id), at: new Date(v.at || v.createdAt),
    title: NAMES[v.type] || "Reading",
    detail: (v.type === "bp" && v.value2 != null ? v.value + "/" + v.value2 : String(v.value)) + " " + (UNITS[v.type] || ""),
  });
  for (const r of recs) out.push({
    kind: "record", id: String(r._id), at: new Date(r.createdAt),
    title: r.title || "Health record", detail: r.type || "",
  });
  return out.filter((x) => !isNaN(x.at)).sort((a, b) => b.at - a.at).slice(0, limit)
    .map((x) => ({ ...x, at: x.at.toISOString(), detail: x.detail.trim() }));
}
module.exports = { buildTimeline };
