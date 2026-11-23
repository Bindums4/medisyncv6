// Vaccine helpers. Dates are "YYYY-MM-DD" strings, today comes from the clinic clock.
const DATE = /^\d{4}-\d{2}-\d{2}$/;
const validDate = (s) => DATE.test(s || "") && !isNaN(new Date(s + "T00:00:00Z")) && new Date(s + "T00:00:00Z").toISOString().slice(0, 10) === s;
const daysBetween = (from, to) => Math.round((new Date(to + "T00:00:00Z") - new Date(from + "T00:00:00Z")) / 86400000);

// "none" = no next dose planned, "overdue" = date has passed, "soon" = within 30 days, "ok" = later.
function dueStatus(nextDue, today) {
  if (!validDate(nextDue) || !validDate(today)) return "none";
  const d = daysBetween(today, nextDue);
  return d < 0 ? "overdue" : d <= 30 ? "soon" : "ok";
}

// Overdue and upcoming doses first (soonest first), then everything else newest first.
function sortVaccines(list, today) {
  const rank = { overdue: 0, soon: 1, ok: 2, none: 3 };
  return list.map((v) => ({ ...v, status: dueStatus(v.nextDue, today) }))
    .sort((a, b) => rank[a.status] - rank[b.status] || (a.status === "none" ? String(b.date).localeCompare(String(a.date)) : String(a.nextDue).localeCompare(String(b.nextDue))));
}
module.exports = { validDate, daysBetween, dueStatus, sortVaccines };
