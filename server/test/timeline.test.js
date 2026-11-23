const test = require("node:test"), assert = require("node:assert");
const { buildTimeline } = require("../src/lib/timeline");

test("timeline merges and sorts newest first", () => {
  const out = buildTimeline({
    apts: [{ _id: 1, date: "2026-11-10", time: "10:30", status: "done", doctor: { name: "Dr. A" }, paid: true }],
    rx: [{ _id: 2, createdAt: "2026-11-10T12:00:00Z", doctor: { name: "Dr. A" }, medicines: [{ name: "Paracetamol" }] }],
    vit: [{ _id: 3, type: "bp", value: 120, value2: 80, at: "2026-11-15T08:00:00Z" }],
    recs: [{ _id: 4, createdAt: "2026-11-01T09:00:00Z", title: "Blood test", type: "Report" }],
  });
  assert.deepStrictEqual(out.map((x) => x.kind), ["reading", "prescription", "visit", "record"]);
  assert.strictEqual(out[0].detail, "120/80 mmHg");
  assert.strictEqual(out[2].detail, "done · paid");
  assert.strictEqual(out[1].detail, "Paracetamol");
});

test("timeline survives bad dates and respects the limit", () => {
  const out = buildTimeline({ apts: [{ _id: 1, date: "oops", time: "x", createdAt: "bad" }], recs: [{ _id: 2, createdAt: "2026-01-01T00:00:00Z" }] });
  assert.strictEqual(out.length, 1);
  assert.strictEqual(out[0].title, "Health record");
  assert.strictEqual(buildTimeline({ recs: Array.from({ length: 5 }, (_, i) => ({ _id: i, createdAt: "2026-01-0" + (i + 1) + "T00:00:00Z" })) }, 3).length, 3);
});
