/**
 * Verification of Apple StoreKit 2 / App Store Server Notification JWS payloads.
 *
 * Apple signs every transaction and notification with a certificate chain that
 * terminates in the Apple Root CA - G3. We verify:
 *   1. the chain root is byte-identical to Apple's published root certificate,
 *   2. each certificate in the chain really signed the next one,
 *   3. the JWS signature validates against the leaf certificate's public key,
 *   4. the payload's bundle id matches ours (when APPLE_BUNDLE_ID is set).
 *
 * Only after all four checks do we treat the payload as trustworthy enough to
 * grant a PRO entitlement.
 */

const APPLE_ROOT_CA_URL = "https://www.apple.com/certificateauthority/AppleRootCA-G3.cer";

let rootCache: { der: Uint8Array; at: number } | null = null;

async function appleRootDer(): Promise<Uint8Array> {
  if (rootCache && Date.now() - rootCache.at < 24 * 3600_000) return rootCache.der;
  const res = await fetch(APPLE_ROOT_CA_URL);
  if (!res.ok) throw new Error("Could not load the Apple root certificate");
  const der = new Uint8Array(await res.arrayBuffer());
  rootCache = { der, at: Date.now() };
  return der;
}

/* ------------------------------- base64 --------------------------------- */

function b64ToBytes(b64: string): Uint8Array {
  const norm = b64.replace(/-/g, "+").replace(/_/g, "/");
  const bin = atob(norm.padEnd(Math.ceil(norm.length / 4) * 4, "="));
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function bytesEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

/* --------------------------------- DER ---------------------------------- */

type TLV = { tag: number; headerStart: number; contentStart: number; length: number; end: number };

function readTLV(buf: Uint8Array, offset: number): TLV {
  const tag = buf[offset];
  let i = offset + 1;
  let length = buf[i++];
  if (length & 0x80) {
    const n = length & 0x7f;
    length = 0;
    for (let k = 0; k < n; k++) length = length * 256 + buf[i++];
  }
  return { tag, headerStart: offset, contentStart: i, length, end: i + length };
}

function children(buf: Uint8Array, node: TLV): TLV[] {
  const out: TLV[] = [];
  let off = node.contentStart;
  while (off < node.end) {
    const tlv = readTLV(buf, off);
    out.push(tlv);
    off = tlv.end;
  }
  return out;
}

const slice = (buf: Uint8Array, t: TLV) => buf.slice(t.headerStart, t.end);

type ParsedCert = {
  tbs: Uint8Array;
  spki: Uint8Array;
  signature: Uint8Array;
  issuer: Uint8Array;
  subject: Uint8Array;
};

/** Minimal X.509 parse: enough to walk the chain and read the public key. */
function parseCertificate(der: Uint8Array): ParsedCert {
  const cert = readTLV(der, 0);
  const [tbsNode, , sigNode] = children(der, cert);
  const tbsKids = children(der, tbsNode);
  // Skip the optional [0] EXPLICIT version tag.
  const fields = tbsKids[0].tag === 0xa0 ? tbsKids.slice(1) : tbsKids;
  // serial(0) signature(1) issuer(2) validity(3) subject(4) spki(5)
  const bitString = der.slice(sigNode.contentStart + 1, sigNode.end); // drop unused-bits byte
  return {
    tbs: slice(der, tbsNode),
    spki: slice(der, fields[5]),
    signature: bitString,
    issuer: slice(der, fields[2]),
    subject: slice(der, fields[4]),
  };
}

/** DER ECDSA signature (SEQUENCE of two INTEGERs) -> raw r||s for WebCrypto. */
function derSignatureToRaw(der: Uint8Array, size = 32): Uint8Array {
  const seq = readTLV(der, 0);
  const [rNode, sNode] = children(der, seq);
  const out = new Uint8Array(size * 2);
  for (const [idx, node] of [rNode, sNode].entries()) {
    let v = der.slice(node.contentStart, node.end);
    while (v.length > size && v[0] === 0) v = v.slice(1);
    out.set(v, idx * size + (size - v.length));
  }
  return out;
}

async function importP256(spki: Uint8Array): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "spki",
    spki.buffer.slice(spki.byteOffset, spki.byteOffset + spki.byteLength) as ArrayBuffer,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["verify"],
  );
}

async function verifyEs256(spki: Uint8Array, signature: Uint8Array, data: Uint8Array): Promise<boolean> {
  const key = await importP256(spki);
  return crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    signature.buffer.slice(signature.byteOffset, signature.byteOffset + signature.byteLength) as ArrayBuffer,
    data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength) as ArrayBuffer,
  );
}

/* --------------------------------- JWS ---------------------------------- */

export type AppleTransaction = {
  transactionId: string;
  originalTransactionId: string;
  productId: string;
  bundleId?: string;
  purchaseDate?: number;
  originalPurchaseDate?: number;
  expiresDate?: number;
  revocationDate?: number;
  type?: string;
  environment?: string;
  appAccountToken?: string;
  isUpgraded?: boolean;
  [key: string]: unknown;
};

export type AppleRenewalInfo = {
  originalTransactionId: string;
  autoRenewStatus?: number;
  autoRenewProductId?: string;
  productId?: string;
  expirationIntent?: number;
  gracePeriodExpiresDate?: number;
  environment?: string;
  [key: string]: unknown;
};

/**
 * Verify a JWS produced by Apple and return its decoded payload.
 * Throws when anything about the signature or the chain is off.
 */
export async function verifyAppleJws<T = Record<string, unknown>>(jws: string): Promise<T> {
  const parts = jws.split(".");
  if (parts.length !== 3) throw new Error("Malformed Apple token");
  const [headerB64, payloadB64, signatureB64] = parts;

  const header = JSON.parse(new TextDecoder().decode(b64ToBytes(headerB64))) as {
    alg?: string;
    x5c?: string[];
  };
  if (header.alg !== "ES256") throw new Error("Unexpected signing algorithm");
  const chainB64 = header.x5c ?? [];
  if (chainB64.length < 2) throw new Error("Missing Apple certificate chain");

  const chain = chainB64.map(b64ToBytes);

  // 1. The chain must terminate in Apple's published root certificate.
  const root = await appleRootDer();
  if (!bytesEqual(chain[chain.length - 1], root)) {
    throw new Error("Certificate chain is not rooted in the Apple Root CA");
  }

  // 2. Every certificate must have been signed by the next one up.
  const parsed = chain.map(parseCertificate);
  for (let i = 0; i < parsed.length - 1; i++) {
    const child = parsed[i];
    const issuer = parsed[i + 1];
    if (!bytesEqual(child.issuer, issuer.subject)) throw new Error("Broken certificate chain");
    const ok = await verifyEs256(issuer.spki, derSignatureToRaw(child.signature), child.tbs);
    if (!ok) throw new Error("Invalid certificate signature");
  }

  // 3. The JWS itself must be signed by the leaf certificate.
  const signed = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
  const sigOk = await verifyEs256(parsed[0].spki, b64ToBytes(signatureB64), signed);
  if (!sigOk) throw new Error("Invalid Apple signature");

  return JSON.parse(new TextDecoder().decode(b64ToBytes(payloadB64))) as T;
}

/** Verify a transaction and check that it belongs to this app. */
export async function verifyAppleTransaction(jws: string): Promise<AppleTransaction> {
  const payload = await verifyAppleJws<AppleTransaction>(jws);
  const expectedBundle = process.env.APPLE_BUNDLE_ID;
  if (expectedBundle && payload.bundleId && payload.bundleId !== expectedBundle) {
    throw new Error("Transaction belongs to a different app");
  }
  if (!payload.productId || !payload.originalTransactionId) {
    throw new Error("Incomplete Apple transaction");
  }
  return payload;
}

/** Apple reports "Sandbox" / "Production"; the app stores sandbox / live. */
export function appleEnv(environment?: string): "sandbox" | "live" {
  return String(environment ?? "").toLowerCase() === "production" ? "live" : "sandbox";
}
