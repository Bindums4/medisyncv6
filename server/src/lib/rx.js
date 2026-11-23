// Cleans what a doctor types into a prescription. Pure functions, so they are easy to test.
const { validDate } = require("./vaccines");

function cleanMedicines(list) {
  return (Array.isArray(list) ? list : [])
    .filter((m) => m && String(m.name || "").trim()).slice(0, 10)
    .map((m) => ({ name: String(m.name).trim().slice(0, 100), dose: String(m.dose || "").trim().slice(0, 100), days: Math.min(365, Math.max(1, Number(m.days) || 1)) }));
}

// Returns { error } or { value }. today is "YYYY-MM-DD" on the clinic clock.
function cleanRx(body, today) {
  const medicines = cleanMedicines(body.medicines);
  if (!medicines.length) return { error: "Add at least one medicine" };
  const followUp = String(body.followUp || "").trim();
  if (followUp && (!validDate(followUp) || followUp < today)) return { error: "Follow-up date must be today or a later date" };
  return { value: {
    diagnosis: String(body.diagnosis || "").trim().slice(0, 300), medicines,
    tests: String(body.tests || "").trim().slice(0, 300), notes: String(body.notes || "").trim().slice(0, 500), followUp,
  } };
}
module.exports = { cleanMedicines, cleanRx };
