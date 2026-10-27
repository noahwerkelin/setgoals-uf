import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { normalizeUsername, validUsername } from "../src/lib/username";

describe("existing shared username rules", () => {
  it("requires at least 3 characters", () => { assert.equal(validUsername("ab"), false); assert.equal(validUsername("abc"), true); });
  it("allows no more than 20 characters", () => { assert.equal(validUsername("a".repeat(20)), true); assert.equal(validUsername("a".repeat(21)), false); });
  it("allows only ASCII letters, digits and underscores", () => {
    assert.equal(validUsername("user_123"), true);
    for (const invalid of ["no-name", "a b", "åke", "user١", "<script>"]) assert.equal(validUsername(invalid), false);
  });
  it("compares case insensitively", () => { assert.equal(normalizeUsername("  User_123  "), "user_123"); assert.equal(validUsername("USER_123"), true); });
});