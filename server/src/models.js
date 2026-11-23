const { Schema, model } = require("mongoose");
const ref = (m) => ({ type: Schema.Types.ObjectId, ref: m, required: true });

const User = model("User", new Schema({
  name: { type: String, required: true, trim: true },
  email: { type: String, required: true, unique: true, lowercase: true },
  password: { type: String, required: true },
  role: { type: String, enum: ["patient", "doctor", "admin"], default: "patient" },
  emergencyContact: { name: String, phone: String },
  phone: { type: String, maxlength: 20 }, dob: String, gender: { type: String, enum: ["", "female", "male", "other"], default: "" },
  bloodGroup: { type: String, enum: ["", "A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"], default: "" },
  heightCm: Number, weightKg: Number, city: { type: String, maxlength: 60 }, avatar: { type: String, maxlength: 90000 }, allergies: { type: String, maxlength: 300 }, conditions: { type: String, maxlength: 300 },
  shareWithDoctors: { type: Boolean, default: true }, active: { type: Boolean, default: true },
  resetHash: String, resetExpires: Number,
}, { timestamps: true }));

const Doctor = model("Doctor", new Schema({
  name: String, specialty: String, fee: { type: Number, default: 500 }, experience: Number,
  user: { type: Schema.Types.ObjectId, ref: "User" },
  workDays: { type: [Number], default: [1, 2, 3, 4, 5, 6] },        // 0 = Sunday
  startTime: { type: String, default: "09:00" }, endTime: { type: String, default: "17:00" },
  slotMinutes: { type: Number, default: 30 },
  bio: { type: String, maxlength: 500, default: "" }, languages: { type: [String], default: [] },
  qualification: { type: String, maxlength: 120, default: "" }, clinic: { type: String, maxlength: 120, default: "" },
  daysOff: { type: [String], default: [] },                          // "YYYY-MM-DD" dates the doctor is away
}));

const apt = new Schema({
  patient: ref("User"), doctor: ref("Doctor"),
  date: { type: String, required: true }, time: { type: String, required: true },
  status: { type: String, enum: ["booked", "cancelled", "done"], default: "booked" },
  forName: { type: String, maxlength: 80 },
  paid: { type: Boolean, default: false }, orderId: String, paymentId: String, invoiceNo: String,
  reminded24: { type: Boolean, default: false }, reminded1: { type: Boolean, default: false },
}, { timestamps: true });
apt.index({ doctor: 1, date: 1, time: 1 }, { unique: true, partialFilterExpression: { status: "booked" } });
const Appointment = model("Appointment", apt);

const Record = model("Record", new Schema({
  patient: ref("User"), title: String, type: { type: String, enum: ["Report", "Prescription"] },
  file: String, originalName: String,
}, { timestamps: true }));

const Reminder = model("Reminder", new Schema({
  patient: ref("User"), medicine: String, time: String, active: { type: Boolean, default: true },
  takenDates: { type: [String], default: [] },           // "YYYY-MM-DD" days the patient marked as taken
  prescription: { type: Schema.Types.ObjectId, ref: "Prescription" },
}));

const rev = new Schema({
  appointment: ref("Appointment"), doctor: ref("Doctor"), patient: ref("User"),
  stars: { type: Number, min: 1, max: 5, required: true }, comment: { type: String, maxlength: 300 },
}, { timestamps: true });
rev.index({ appointment: 1 }, { unique: true });
const Review = model("Review", rev);

const Message = model("Message", new Schema({
  room: { type: String, index: true }, sender: String, name: String, text: { type: String, maxlength: 500 },
}, { timestamps: true }));

const SosAlert = model("SosAlert", new Schema({
  patient: ref("User"), lat: Number, lng: Number, contactPhone: String, smsSent: Boolean,
}, { timestamps: true }));

const Prescription = model("Prescription", new Schema({
  appointment: { ...ref("Appointment"), unique: true }, doctor: ref("Doctor"), patient: ref("User"),
  diagnosis: { type: String, maxlength: 300 },
  medicines: [{ name: { type: String, maxlength: 100 }, dose: { type: String, maxlength: 100 }, days: Number }],
  notes: { type: String, maxlength: 500 },
  tests: { type: String, maxlength: 300, default: "" },                 // lab tests advised
  followUp: { type: String, default: "" },                              // "YYYY-MM-DD" next visit
}, { timestamps: true }));

// A saved prescription the doctor can reuse for common problems (for example "Viral fever").
const RxTemplate = model("RxTemplate", new Schema({
  doctor: ref("Doctor"), name: { type: String, required: true, maxlength: 60 }, diagnosis: { type: String, maxlength: 300, default: "" },
  medicines: [{ name: { type: String, maxlength: 100 }, dose: { type: String, maxlength: 100 }, days: Number }],
  tests: { type: String, maxlength: 300, default: "" }, notes: { type: String, maxlength: 500, default: "" },
}, { timestamps: true }));

const Device = model("Device", new Schema({ user: ref("User"), token: { type: String, required: true, unique: true } }));

const Notification = model("Notification", new Schema({
  user: ref("User"), title: String, body: String, kind: { type: String, default: "info" }, read: { type: Boolean, default: false },
}, { timestamps: true }));

const Vital = model("Vital", new Schema({
  patient: ref("User"), type: { type: String, enum: ["bp", "sugar", "weight", "heart", "temp", "spo2"], required: true },
  value: { type: Number, required: true }, value2: Number, context: String, note: { type: String, maxlength: 120 }, at: { type: Date, default: Date.now },
}, { timestamps: true }));
Vital.schema.index({ patient: 1, type: 1, at: -1 });

const Family = model("Family", new Schema({
  owner: ref("User"), name: { type: String, required: true, trim: true, maxlength: 80 },
  relation: { type: String, maxlength: 30, default: "" }, age: Number,
}, { timestamps: true }));

const Announcement = model("Announcement", new Schema({
  title: { type: String, required: true, maxlength: 100 }, body: { type: String, maxlength: 500, default: "" },
}, { timestamps: true }));

const Favorite = model("Favorite", (() => {
  const f = new Schema({ patient: ref("User"), doctor: ref("Doctor") }, { timestamps: true });
  f.index({ patient: 1, doctor: 1 }, { unique: true });
  return f;
})());

// Private notes a doctor keeps about a patient. The patient never sees these.
const DoctorNote = model("DoctorNote", new Schema({
  doctor: ref("Doctor"), patient: ref("User"), text: { type: String, required: true, maxlength: 500 },
}, { timestamps: true }));

// A vaccine the patient has taken, with an optional date for the next dose.
const Vaccine = model("Vaccine", new Schema({
  patient: ref("User"), name: { type: String, required: true, maxlength: 80 },
  date: { type: String, required: true }, nextDue: { type: String, default: "" }, notes: { type: String, maxlength: 200, default: "" },
}, { timestamps: true }));

module.exports = { RxTemplate, Vaccine, Favorite, DoctorNote, Family, Announcement, Notification, Vital, User, Doctor, Appointment, Record, Reminder, Review, Message, SosAlert, Prescription, Device };
