import test from "node:test";
import assert from "node:assert/strict";
import {
  readFileSync,
  existsSync,
  mkdtempSync,
  mkdirSync,
  writeFileSync,
  rmSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const root = new URL("../../", import.meta.url);
const landingFile = new URL("web/landing.html", root);
const vercelConfigFile = new URL("vercel.json", root);

test("LND-01 landing.html exists in web/", () => {
  assert.ok(existsSync(landingFile), "web/landing.html must exist");
});

test("LND-02 landing.html includes brand identity, Poppins, colors, and responsive viewport", () => {
  assert.ok(existsSync(landingFile), "web/landing.html must exist");
  const html = readFileSync(landingFile, "utf8");

  // Meta & responsive
  assert.match(
    html,
    /<meta\s+name=["']viewport["']/i,
    "Viewport meta tag required",
  );
  assert.match(html, /Statoo/i, "Brand title required");

  // Punchline and Logo
  assert.match(
    html,
    /logo-transparent\.png/,
    "Transparent logo must be referenced",
  );
  assert.match(
    html,
    /Le foot entre amis,\s*les comptes au clair/i,
    "Punchline required",
  );

  // Design system: Poppins and theme colors
  assert.match(html, /Poppins/i, "Poppins font required");
  assert.match(html, /#0b0f14|#15803d|#22c55e/i, "Brand colors required");
});

test("LND-03 landing.html contains CTA 'Commencer' pointing to web onboarding /app", () => {
  assert.ok(existsSync(landingFile), "web/landing.html must exist");
  const html = readFileSync(landingFile, "utf8");

  // Button or link "Commencer" pointing to /app
  assert.match(
    html,
    /href=["']\/?app["']/i,
    "CTA 'Commencer' must point to /app",
  );
  assert.match(html, /Commencer/i, "Button text 'Commencer' required");
});

test("LND-04 landing.html contains Android APK download with GitHub Release link, QR code, and guide", () => {
  assert.ok(existsSync(landingFile), "web/landing.html must exist");
  const html = readFileSync(landingFile, "utf8");

  // Link to GitHub release statoo.apk
  assert.match(
    html,
    /https:\/\/github\.com\/NorrisAkg\/statoo-5v5\/releases\/latest\/download\/statoo\.apk|\/download/i,
    "Download link to statoo.apk required",
  );

  // QR Code
  assert.match(html, /<svg|<img[^>]*qr/i, "QR code for mobile scan required");

  // 3-step installation guide
  assert.match(html, /Télécharger/i, "Step 1: Download required");
  assert.match(
    html,
    /inconnues|sources|danger|paramètres/i,
    "Step 2: Unknown sources / warning advice required",
  );
  assert.match(html, /Installer/i, "Step 3: Install required");
});

test("LND-05 vercel.json routes root to landing.html and /app to Flutter web", () => {
  assert.ok(existsSync(vercelConfigFile), "vercel.json must exist");
  const vercel = JSON.parse(readFileSync(vercelConfigFile, "utf8"));

  assert.ok(Array.isArray(vercel.rewrites), "vercel.json must define rewrites");

  const rootRewrite = vercel.rewrites.find((r) => r.source === "/");
  assert.ok(rootRewrite, "Rewrite for / must exist");
  assert.equal(rootRewrite.destination, "/landing.html");

  const appRewrite = vercel.rewrites.find(
    (r) => r.source === "/app" || r.source === "/app/:path*",
  );
  assert.ok(appRewrite, "Rewrite for /app must exist");
  assert.equal(appRewrite.destination, "/index.html");

  const downloadRewrite = vercel.rewrites.find((r) => r.source === "/download");
  assert.ok(downloadRewrite, "Rewrite for /download must exist");
  assert.match(downloadRewrite.destination, /statoo\.apk/);
});

test("LND-06 package-universal packages landing.html into universal-dist", async () => {
  const moduleUrl = new URL(
    "../../scripts/package-universal-web.mjs",
    import.meta.url,
  );
  const { packageUniversal } = await import(moduleUrl);
  const rootDir = mkdtempSync(join(tmpdir(), "statoo-landing-test-"));

  try {
    const build = join(rootDir, "build");
    const legacy = join(rootDir, "legacy");
    const output = join(rootDir, "output");
    mkdirSync(build);
    mkdirSync(legacy);

    for (const file of [
      "index.html",
      "flutter_bootstrap.js",
      "main.dart.js",
      "sqlite3.wasm",
      "sqflite_sw.js",
    ]) {
      writeFileSync(join(build, file), "dummy");
    }
    writeFileSync(join(legacy, "index.html"), "legacy");

    packageUniversal({ build, legacy, output });

    assert.ok(
      existsSync(join(output, "landing.html")),
      "landing.html must be copied to universal-dist",
    );
  } finally {
    rmSync(rootDir, { recursive: true, force: true });
  }
});

test("LND-07 sw.js routes /app navigations to index.html and / to landing.html", async () => {
  const moduleUrl = new URL(
    "../../scripts/package-universal-web.mjs",
    import.meta.url,
  );
  const { packageUniversal } = await import(moduleUrl);
  const rootDir = mkdtempSync(join(tmpdir(), "statoo-sw-test-"));

  try {
    const build = join(rootDir, "build");
    const legacy = join(rootDir, "legacy");
    const output = join(rootDir, "output");
    mkdirSync(build);
    mkdirSync(legacy);

    for (const file of [
      "index.html",
      "flutter_bootstrap.js",
      "main.dart.js",
      "sqlite3.wasm",
      "sqflite_sw.js",
    ]) {
      writeFileSync(join(build, file), "dummy");
    }
    writeFileSync(join(legacy, "index.html"), "legacy");

    packageUniversal({ build, legacy, output });

    const worker = readFileSync(join(output, "sw.js"), "utf8");
    assert.ok(worker.includes("/app"), "sw.js must route /app navigation");
    assert.ok(
      worker.includes("landing.html"),
      "sw.js must route / to landing.html",
    );
  } finally {
    rmSync(rootDir, { recursive: true, force: true });
  }
});
