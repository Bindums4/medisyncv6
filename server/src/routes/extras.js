const r = require("express").Router();
const { Family, Announcement, User, Doctor, Appointment } = require("../models"), { protect } = require("../auth"), { notify } = require("../lib/notify");

// ---- clinic announcements (admin writes, every patient is notified, everyone can read) ----
r.get("/announcements", protect(), async (_q, res) => res.json(await Announcement.find().sort("-createdAt").limit(5)));
r.post("/announcements", protect("admin"), async (req, res) => {
  const title = String(req.body.title || "").trim(), body = String(req.body.body || "").trim();
  if (!title || title.length > 100 || body.length > 500) return res.status(400).json({ error: "Enter a title (up to 100 characters) and a message (up to 500)" });
  const a = await Announcement.create({ title, body });
  const people = await User.find({ role: "patient", active: { $ne: false } }).select("_id").limit(500);
  people.forEach((u) => notify(u._id, title, body, "info"));
  res.status(201).json(a);
});
r.delete("/announcements/:id", protect("admin"), async (req, res) => { await Announcement.findByIdAndDelete(req.params.id); res.json({ ok: true }); });

// ---- family members a patient can book visits for ----
r.get("/family", protect("patient"), async (req, res) => res.json(await Family.find({ owner: req.user.id }).sort("createdAt")));
r.post("/family", protect("patient"), async (req, res) => {
  const name = String(req.body.name || "").trim(), relation = String(req.body.relation || "").trim().slice(0, 30);
  const age = req.body.age === "" || req.body.age == null ? undefined : Number(req.body.age);
  if (name.length < 2 || name.length > 80) return res.status(400).json({ error: "Enter the family member's name" });
  if (age !== undefined && !(age >= 0 && age <= 120)) return res.status(400).json({ error: "Enter a valid age" });
  if ((await Family.countDocuments({ owner: req.user.id })) >= 10) return res.status(400).json({ error: "You can add up to 10 family members" });
  res.status(201).json(await Family.create({ owner: req.user.id, name, relation, age }));
});
r.delete("/family/:id", protect("patient"), async (req, res) => { await Family.deleteOne({ _id: req.params.id, owner: req.user.id }); res.json({ ok: true }); });

// ---- doctor schedule and earnings ----
r.get("/doctor-stats", protect("doctor"), async (req, res) => {
  const d = await Doctor.findOne({ user: req.user.id });
  if (!d) return res.json({ fee: 0, today: 0, upcoming: 0, done: 0, paidCount: 0, earnings: 0, week: [], ahead: [] });
  const tz = process.env.CLINIC_TZ || "Asia/Kolkata", day = (ms) => new Date(ms).toLocaleDateString("en-CA", { timeZone: tz });
  const all = await Appointment.find({ doctor: d._id, status: { $ne: "cancelled" } }).select("date status paid");
  const todayStr = day(Date.now()), week = [], ahead = [];
  for (let i = 6; i >= 0; i--) { const ds = day(Date.now() - i * 864e5); week.push({ date: ds, count: all.filter((a) => a.date === ds).length }); }
  for (let i = 0; i < 7; i++) { const ds = day(Date.now() + i * 864e5); ahead.push({ date: ds, count: all.filter((a) => a.date === ds && a.status === "booked").length }); }
  const paidCount = all.filter((a) => a.paid).length;
  res.json({
    fee: d.fee, today: all.filter((a) => a.date === todayStr).length, upcoming: all.filter((a) => a.status === "booked").length,
    done: all.filter((a) => a.status === "done").length, paidCount, earnings: paidCount * d.fee, week, ahead,
  });
});

module.exports = r;
