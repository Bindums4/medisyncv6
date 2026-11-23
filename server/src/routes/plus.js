// Favorite doctors, the patient health timeline, and private doctor notes.
const r = require("express").Router(), mongoose = require("mongoose");
const { Vaccine, Favorite, DoctorNote, Doctor, Appointment, Prescription, Vital, Record } = require("../models"), { protect } = require("../auth");
const { buildTimeline } = require("../lib/timeline"), { validDate, sortVaccines } = require("../lib/vaccines"), { nowIn } = require("../lib/clock");
const validId = (x) => mongoose.isValidObjectId(x);

// ---- favorite doctors (patient) ----
r.get("/favorites", protect("patient"), async (q, s) => {
  const f = await Favorite.find({ patient: q.user.id }).select("doctor").lean();
  s.json(f.map((x) => String(x.doctor)));
});
r.post("/favorites/:doctorId", protect("patient"), async (q, s) => {
  const id = q.params.doctorId;
  if (!validId(id) || !(await Doctor.exists({ _id: id }))) return s.status(404).json({ error: "Doctor not found" });
  const had = await Favorite.findOneAndDelete({ patient: q.user.id, doctor: id });
  if (!had) {
    if ((await Favorite.countDocuments({ patient: q.user.id })) >= 50) return s.status(400).json({ error: "You can save up to 50 favorite doctors" });
    await Favorite.create({ patient: q.user.id, doctor: id }).catch(() => null);
  }
  s.json({ favorite: !had });
});

// ---- health timeline (patient): visits, prescriptions, readings and records in one list ----
r.get("/timeline", protect("patient"), async (q, s) => {
  const id = q.user.id;
  const [apts, rx, vit, recs] = await Promise.all([
    Appointment.find({ patient: id }).populate("doctor", "name").sort("-date -time").limit(30).lean(),
    Prescription.find({ patient: id }).populate("doctor", "name").sort("-createdAt").limit(20).lean(),
    Vital.find({ patient: id }).sort("-at").limit(20).lean(),
    Record.find({ patient: id }).sort("-createdAt").limit(20).lean(),
  ]);
  s.json(buildTimeline({ apts, rx, vit, recs }));
});

// ---- vaccination record (patient) ----
r.get("/vaccines", protect("patient"), async (q, s) => {
  s.json(sortVaccines(await Vaccine.find({ patient: q.user.id }).limit(100).lean(), nowIn().date));
});
r.post("/vaccines", protect("patient"), async (q, s) => {
  const name = String(q.body.name || "").trim().slice(0, 80), date = String(q.body.date || ""), nextDue = String(q.body.nextDue || ""), notes = String(q.body.notes || "").trim().slice(0, 200);
  if (!name) return s.status(400).json({ error: "Enter the vaccine name" });
  if (!validDate(date)) return s.status(400).json({ error: "Enter the date you took it" });
  if (date > nowIn().date) return s.status(400).json({ error: "The date taken cannot be in the future" });
  if (nextDue && (!validDate(nextDue) || nextDue < date)) return s.status(400).json({ error: "Next dose date must be on or after the date taken" });
  if ((await Vaccine.countDocuments({ patient: q.user.id })) >= 100) return s.status(400).json({ error: "You can save up to 100 vaccines" });
  s.status(201).json(await Vaccine.create({ patient: q.user.id, name, date, nextDue, notes }));
});
r.delete("/vaccines/:id", protect("patient"), async (q, s) => {
  if (validId(q.params.id)) await Vaccine.deleteOne({ _id: q.params.id, patient: q.user.id });
  s.json({ ok: true });
});

// ---- private notes (doctor), only for patients the doctor has a visit with ----
async function myDoctorFor(userId, patientId) {
  if (!validId(patientId)) return null;
  const d = await Doctor.findOne({ user: userId });
  if (!d) return null;
  return (await Appointment.exists({ doctor: d._id, patient: patientId, status: { $ne: "cancelled" } })) ? d : null;
}
r.get("/notes/:patientId", protect("doctor"), async (q, s) => {
  const d = await myDoctorFor(q.user.id, q.params.patientId);
  if (!d) return s.status(404).json({ error: "Patient not found" });
  s.json(await DoctorNote.find({ doctor: d._id, patient: q.params.patientId }).sort("-createdAt").limit(50).lean());
});
r.post("/notes/:patientId", protect("doctor"), async (q, s) => {
  const d = await myDoctorFor(q.user.id, q.params.patientId);
  if (!d) return s.status(404).json({ error: "Patient not found" });
  const text = String(q.body.text || "").trim();
  if (!text || text.length > 500) return s.status(400).json({ error: "Write a note of up to 500 characters" });
  if ((await DoctorNote.countDocuments({ doctor: d._id, patient: q.params.patientId })) >= 100) return s.status(400).json({ error: "Note limit reached for this patient" });
  s.status(201).json(await DoctorNote.create({ doctor: d._id, patient: q.params.patientId, text }));
});
r.delete("/notes/:id", protect("doctor"), async (q, s) => {
  const d = await Doctor.findOne({ user: q.user.id });
  if (d && validId(q.params.id)) await DoctorNote.deleteOne({ _id: q.params.id, doctor: d._id });
  s.json({ ok: true });
});
module.exports = r;
