require("dotenv").config();
const mongoose = require("mongoose"), bcrypt = require("bcryptjs");
const { User, Doctor, Appointment } = require("./models");
const DOCS = [
  { name: "Dr. Ananya Rao", specialty: "Cardiologist", fee: 800, experience: 12, email: "ananya@medisync.com" },
  { name: "Dr. Kiran Shetty", specialty: "General physician", fee: 500, experience: 8, email: "kiran@medisync.com" },
  { name: "Dr. Meera Nair", specialty: "Dermatologist", fee: 600, experience: 10, email: "meera@medisync.com" },
  { name: "Dr. Ravi Kumar", specialty: "Orthopedic", fee: 700, experience: 15, email: "ravi@medisync.com" },
  { name: "Dr. Sneha Iyer", specialty: "Pediatrician", fee: 600, experience: 9, email: "sneha@medisync.com" },
  { name: "Dr. Farhan Ali", specialty: "Neurologist", fee: 900, experience: 14, email: "farhan@medisync.com" },
  { name: "Dr. Lakshmi Prasad", specialty: "Gynecologist", fee: 700, experience: 11, email: "lakshmi@medisync.com" },
  { name: "Dr. Arjun Mehta", specialty: "ENT specialist", fee: 550, experience: 7, email: "arjun@medisync.com" },
];
(async () => {
  await mongoose.connect(process.env.MONGO_URI);
  // Only the demo accounts are rebuilt. Doctors who signed up themselves are kept.
  const old = await User.find({ email: { $in: [...DOCS.map((d) => d.email), "admin@medisync.com"] } }).select("_id");
  const ids = old.map((u) => u._id);
  // Doctors left over from an older version have no login account, so nobody can sign in as them. Remove them (and their visits).
  const orphans = await Doctor.find({ $or: [{ user: { $exists: false } }, { user: null }] }).select("_id");
  if (orphans.length) { const oid = orphans.map((d) => d._id); await Appointment.deleteMany({ doctor: { $in: oid } }); await Doctor.deleteMany({ _id: { $in: oid } }); }
  await Doctor.deleteMany({ user: { $in: ids } }); await User.deleteMany({ _id: { $in: ids } });
  await User.create({ name: "Admin", email: "admin@medisync.com", password: await bcrypt.hash("Admin@123", 10), role: "admin" });
  for (const d of DOCS) {
    const u = await User.create({ name: d.name, email: d.email, password: await bcrypt.hash("Doctor@123", 10), role: "doctor" });
    await Doctor.create({ name: d.name, specialty: d.specialty, fee: d.fee, experience: d.experience, user: u._id });
  }
  if (!(await User.findOne({ email: "patient@medisync.com" })))
    await User.create({ name: "Demo Patient", email: "patient@medisync.com", password: await bcrypt.hash("Patient@123", 10), role: "patient" });
  console.log("Seeded. Admin: admin@medisync.com / Admin@123. Patient: patient@medisync.com / Patient@123. 8 doctors (ananya, kiran, meera, ravi, sneha, farhan, lakshmi, arjun @medisync.com) / Doctor@123");
  process.exit(0);
})();
