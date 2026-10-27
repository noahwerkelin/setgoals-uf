export const normalizeUsername = (value: string) => value.trim().toLowerCase();
export const validUsername = (value: string) => /^[a-z0-9_]{3,20}$/.test(normalizeUsername(value));