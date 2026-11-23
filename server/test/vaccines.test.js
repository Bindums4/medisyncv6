const test = require("node:test"), assert = require("node:assert");
const { validDate, dueStatus, sortVaccines } = require("../src/lib/vaccines");
const { availability, freeSlots } = require("../src/lib/slots");

test("validDate accepts real dates only", () => {
  assert.equal(validDate("2026-11-23"), true);
  assert.equal(validDate("2026-02-30"), false);
  assert.equal(validDate("23-11-2026"), false);
  assert.equal(validDate(""), false);
});
test("dueStatus bands", () => {
  assert.equal(dueStatus("", "2026-11-23"), "none");
  assert.equal(dueStatus("2026-11-22", "2026-11-23"), "overdue");
  assert.equal(dueStatus("2026-11-23", "2026-11-23"), "soon");
  assert.equal(dueStatus("2026-12-23", "2026-11-23"), "soon");
  assert.equal(dueStatus("2026-12-24", "2026-11-23"), "ok");
});
test("sortVaccines puts overdue first, then soonest", () => {
  const out = sortVaccines([
    { name: "A", date: "2025-01-01", nextDue: "" },
    { name: "B", date: "2025-01-01", nextDue: "2027-06-01" },
    { name: "C", date: "2025-01-01", nextDue: "2026-12-01" },
    { name: "D", date: "2025-01-01", nextDue: "2026-10-01" },
  ], "2026-11-23");
  assert.deepEqual(out.map((v) => v.name), ["D", "C", "B", "A"]);
});
test("a doctor day off has no free slots", () => {
  const av = availability({ workDays: [1, 2, 3, 4, 5, 6], startTime: "09:00", endTime: "10:00", slotMinutes: 30, daysOff: ["2026-11-24"] });
  assert.deepEqual(freeSlots(av, "2026-11-24", []), []);
  assert.deepEqual(freeSlots(av, "2026-11-25", []), ["09:00", "09:30"]);
});
