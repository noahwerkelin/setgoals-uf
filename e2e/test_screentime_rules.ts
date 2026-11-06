import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
  effectiveCapHours,
  effectiveStepsPer30,
  earnedMinForDay,
  computeRolloverMin,
  DEFAULT_PRO_ST,
  type ProST,
} from "../src/lib/screentime";

// 2026-11-06 is a Friday, 2026-11-07 a Saturday (local dates, noon to avoid TZ edges).
const friday = new Date(2026, 10, 6, 12);
const saturday = new Date(2026, 10, 7, 12);

const proOn: ProST = { ...DEFAULT_PRO_ST, weekend2x: true, splitCaps: true, weekdayCap: 3, weekendCap: 6 };

describe("split weekday/weekend caps", () => {
  it("override the standard daily cap when enabled for PRO", () => {
    assert.equal(effectiveCapHours(5, proOn, true, friday), 3);
    assert.equal(effectiveCapHours(5, proOn, true, saturday), 6);
  });
  it("fall back to the standard cap when disabled or not PRO", () => {
    assert.equal(effectiveCapHours(5, { ...proOn, splitCaps: false }, true, friday), 5);
    assert.equal(effectiveCapHours(5, proOn, false, friday), 5);
  });
});

describe("weekend 2x multiplier", () => {
  it("halves the steps needed per 30 min on weekends for PRO", () => {
    assert.equal(effectiveStepsPer30(1000, proOn, true, saturday), 500);
    assert.equal(effectiveStepsPer30(1000, proOn, true, friday), 1000);
    assert.equal(effectiveStepsPer30(1000, proOn, false, saturday), 1000);
  });
  it("doubles earned minutes on weekends, still capped", () => {
    // 6000 steps: weekday at 1000/30min = 180 min; weekend 2x = 360 min, capped by 6h.
    assert.equal(earnedMinForDay(6000, 1000, 5, proOn, true, friday), 180);
    assert.equal(earnedMinForDay(6000, 1000, 5, proOn, true, saturday), 360);
    // 20000 steps on a weekend would earn 600 min but the 6h weekend cap holds.
    assert.equal(earnedMinForDay(20000, 1000, 5, proOn, true, saturday), 360);
  });
});

describe("rollover", () => {
  it("is zero without PRO or with rollover disabled", () => {
    assert.equal(computeRolloverMin(10000, 1000, 5, proOn, false), 0);
    assert.equal(computeRolloverMin(10000, 1000, 5, { ...proOn, rollover: false }, true), 0);
  });
  it("carries yesterday's earned minutes, capped by today's cap", () => {
    const withRollover = { ...proOn, rollover: true };
    const rolled = computeRolloverMin(4000, 1000, 5, withRollover, true);
    assert.ok(rolled > 0 && rolled <= effectiveCapHours(5, withRollover, true) * 60);
  });
});
