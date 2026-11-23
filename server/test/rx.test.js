const test = require("node:test"), assert = require("node:assert");
const { cleanRx } = require("../src/lib/rx");

test("needs at least one medicine", () => {
  assert.match(cleanRx({ medicines: [{ name: "  " }] }, "2026-11-23").error, /at least one medicine/);
  assert.match(cleanRx({}, "2026-11-23").error, /at least one medicine/);
});
test("cleans and limits the medicines", () => {
  const r = cleanRx({ medicines: [{ name: " Paracetamol ", dose: "1 tablet twice a day", days: "0" }, { name: "Cetirizine", days: 999 }] }, "2026-11-23");
  assert.deepEqual(r.value.medicines, [{ name: "Paracetamol", dose: "1 tablet twice a day", days: 1 }, { name: "Cetirizine", dose: "", days: 365 }]);
});
test("follow-up date must be real and not in the past", () => {
  const m = [{ name: "A", days: 3 }];
  assert.ok(cleanRx({ medicines: m, followUp: "2026-11-22" }, "2026-11-23").error);
  assert.ok(cleanRx({ medicines: m, followUp: "2026-02-30" }, "2026-11-23").error);
  assert.equal(cleanRx({ medicines: m, followUp: "2026-11-23" }, "2026-11-23").value.followUp, "2026-11-23");
  assert.equal(cleanRx({ medicines: m }, "2026-11-23").value.followUp, "");
});
test("trims text and keeps tests", () => {
  const r = cleanRx({ medicines: [{ name: "A" }], diagnosis: "  Viral fever ", tests: " CBC, Dengue NS1 ", notes: " Rest " }, "2026-11-23");
  assert.equal(r.value.diagnosis, "Viral fever"); assert.equal(r.value.tests, "CBC, Dengue NS1"); assert.equal(r.value.notes, "Rest");
});
