const r = require("express").Router(), crypto = require("crypto");
const { Appointment, Doctor } = require("../models"), { notify } = require("../lib/notify"), { protect } = require("../auth"), canChat = require("../chatAccess");
const { availability, freeSlots } = require("../lib/slots"), { nowIn } = require("../lib/clock");

r.post("/", protect("patient"), async (req, res) => {
  const { doctor, date, time, forName } = req.body;
  if (!doctor || !date || !time) return res.status(400).json({ error: "Doctor, date and time are required" });
  const d = await Doctor.findById(doctor).catch(() => null);
  if (!d) return res.status(404).json({ error: "Doctor not found" });
  const taken = (await Appointment.find({ doctor: d._id, date, status: "booked" }).select("time")).map((x) => x.time);
  if (!freeSlots(availability(d), String(date), taken, nowIn()).includes(time) && !taken.includes(time))
    return res.status(400).json({ error: "The doctor is not available at that time" });
  try {
    const a = await Appointment.create({ patient: req.user.id, doctor: d._id, date, time, forName: forName ? String(forName).trim().slice(0, 80) : undefined });
    notify(req.user.id, "Visit booked", `Your visit with ${d.name} is on ${date} at ${time}.`, "booking");
    notify(d.user, "New booking", `A patient booked ${date} at ${time}.`, "booking");
    res.status(201).json(a);
  } catch (e) {
    if (e.code === 11000) return res.status(409).json({ error: "That slot is already booked" });
    throw e;
  }
});
r.get("/mine", protect("patient"), async (req, res) => {
  const list = await Appointment.find({ patient: req.user.id }).populate("doctor").sort("-createdAt").lean();
  // Queue token: your place among that doctor's booked visits on the same day, by time.
  for (const a of list) {
    if (a.status === "booked" && a.doctor) a.queue = await Appointment.countDocuments({ doctor: a.doctor._id, date: a.date, status: "booked", time: { $lte: a.time } });
  }
  res.json(list);
});
r.get("/doctor", protect("doctor"), async (req, res) => {
  const d = await Doctor.findOne({ user: req.user.id });
  res.json(d ? await Appointment.find({ doctor: d._id }).populate("patient", "name email avatar").sort("date time") : []);
});
r.patch("/:id/done", protect("doctor"), async (req, res) => {
  const d = await Doctor.findOne({ user: req.user.id });
  const a = d && await Appointment.findOneAndUpdate({ _id: req.params.id, doctor: d._id, status: "booked" }, { status: "done" }, { new: true });
  if (!a) return res.status(404).json({ error: "Not found" });
  notify(a.patient, "Visit completed", "Your visit is marked done. Check for a prescription and leave a review.", "visit");
  const days = Number(req.body && req.body.followUpDays);
  if (days >= 1 && days <= 90) {
    const when = new Date(Date.now() + days * 864e5).toLocaleDateString("en-CA", { timeZone: process.env.CLINIC_TZ || "Asia/Kolkata" });
    notify(a.patient, "Follow-up suggested", `Your doctor suggests a follow-up visit around ${when}. Open Book visit to pick a time.`, "visit");
  }
  res.json(a);
});
r.patch("/:id/cancel", protect("patient"), async (req, res) => {
  const a = await Appointment.findOneAndUpdate({ _id: req.params.id, patient: req.user.id, status: "booked" }, { status: "cancelled" }, { new: true });
  if (!a) return res.status(404).json({ error: "Not found" });
  const d = await Doctor.findById(a.doctor).select("user");
  notify(d?.user, "Visit cancelled", `The patient cancelled the visit on ${a.date} at ${a.time}.`, "booking");
  res.json(a);
});

// Move a booked visit to another free time with the same doctor. The unique index stops double booking.
r.patch("/:id/reschedule", protect("patient"), async (req, res) => {
  const { date, time } = req.body;
  const a = await Appointment.findOne({ _id: req.params.id, patient: req.user.id, status: "booked" });
  if (!a) return res.status(404).json({ error: "Not found" });
  const d = await Doctor.findById(a.doctor);
  const taken = (await Appointment.find({ doctor: d._id, date, status: "booked" }).select("time")).map((x) => x.time);
  if (!freeSlots(availability(d), String(date), taken, nowIn()).includes(time)) return res.status(400).json({ error: "The doctor is not available at that time" });
  const old = `${a.date} at ${a.time}`;
  try { a.date = date; a.time = time; a.reminded24 = false; a.reminded1 = false; await a.save(); }
  catch (e) { if (e.code === 11000) return res.status(409).json({ error: "That slot is already booked" }); throw e; }
  notify(a.patient, "Visit moved", `Your visit moved from ${old} to ${date} at ${time}.`, "booking");
  notify(d.user, "Visit moved", `A patient moved their visit from ${old} to ${date} at ${time}.`, "booking");
  res.json(a);
});
// Video room: the name is derived from a secret, so only people who get it from this route can guess it.
r.get("/:id/video", protect(), async (req, res) => {
  if (!(await canChat(req.user.id, req.params.id))) return res.status(403).json({ error: "Not allowed" });
  const a = await Appointment.findById(req.params.id);
  if (a.status === "cancelled") return res.status(400).json({ error: "This visit was cancelled" });
  const room = "medisync-" + crypto.createHmac("sha256", process.env.JWT_SECRET).update(String(a._id)).digest("hex").slice(0, 20);
  res.json({ url: `${process.env.JITSI_URL || "https://meet.jit.si"}/${room}` });
});
module.exports = r;
