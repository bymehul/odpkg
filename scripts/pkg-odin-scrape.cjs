const fs = require("fs");
const path = require("path");
const cheerio = require("cheerio");
const fetch = (...args) => import("node-fetch").then(({ default: fetch }) => fetch(...args));

const BASE_URL = "https://pkg-odin.org";
const HOME_URL = `${BASE_URL}/`;
const USER_AGENT = "odpkg-scrape/0.1 (dev tool)";

function absoluteUrl(href) {
  if (!href) return "";
  if (href.startsWith("http")) return href;
  return `${BASE_URL}${href}`;
}

function uniqueBy(items, keyFn) {
  const seen = new Set();
  const out = [];
  for (const item of items) {
    const key = keyFn(item);
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(item);
  }
  return out;
}

async function fetchText(url) {
  const res = await fetch(url, {
    headers: {
      "user-agent": USER_AGENT,
      "accept": "text/html",
    }
  });
  if (!res.ok) {
    throw new Error(`HTTP ${res.status} ${res.statusText} for ${url}`);
  }
  return res.text();
}

function extractPackageLinks($) {
  const items = [];
  $("a").each((_, el) => {
    const href = $(el).attr("href") || "";
    const text = $(el).text().trim();
    if (!text) return;
    if (href.startsWith("/packages/") || href.includes("pkg-odin.org/packages")) {
      items.push({ title: text, url: absoluteUrl(href) });
    }
  });
  return uniqueBy(items, (it) => it.url);
}

function listPackageLinks(items) {
  console.log(`Found ${items.length} candidate package links`);
  for (const it of items) {
    console.log(`- ${it.title} :: ${it.url}`);
  }
}

function collectScriptSrcs($) {
  const srcs = [];
  $("script[src]").each((_, el) => {
    const src = $(el).attr("src");
    if (src) srcs.push(src);
  });
  return srcs;
}

async function scanBundlesForEndpoints(srcs) {
  const endpoints = new Set();
  if (!srcs.length) return endpoints;
  console.log(`\nFound ${srcs.length} script bundle(s). Scanning for endpoints...`);
  for (const src of srcs) {
    const jsUrl = absoluteUrl(src);
    const jsRes = await fetch(jsUrl, { headers: { "user-agent": USER_AGENT } });
    if (!jsRes.ok) continue;
    const js = await jsRes.text();
    const urlMatches = js.match(/https?:\/\/[^\s"'<>]+/g) || [];
    const apiMatches = js.match(/\/api\/[a-zA-Z0-9_\-\/]+/g) || [];
    for (const u of urlMatches) endpoints.add(u);
    for (const u of apiMatches) endpoints.add(`${BASE_URL}${u}`);
  }
  return endpoints;
}

function printEndpoints(endpoints, hadBundles) {
  if (endpoints.size) {
    console.log("Possible endpoints found:");
    for (const u of endpoints) console.log(`- ${u}`);
    return;
  }
  if (hadBundles) {
    console.log("No obvious endpoints found in JS bundles.");
  }
}

async function probeRegistry(endpoints) {
  if (!endpoints.has("https://api.pkg-odin.org")) return;
  console.log("\nProbing https://api.pkg-odin.org/packages ...");
  const apiRes = await fetch("https://api.pkg-odin.org/packages", {
    headers: { "user-agent": USER_AGENT }
  });
  if (!apiRes.ok) {
    console.log(`API returned ${apiRes.status}`);
    return;
  }
  const data = await apiRes.json();
  console.log(`API packages: ${data.length}`);
  for (const pkg of data.slice(0, 10)) {
    console.log(`- ${pkg.slug} :: ${pkg.repository_url}`);
  }
}

async function main() {
  const html = await fetchText(HOME_URL);
  const $ = cheerio.load(html);

  const packages = extractPackageLinks($);
  listPackageLinks(packages);

  const scriptSrcs = collectScriptSrcs($);
  const endpoints = await scanBundlesForEndpoints(scriptSrcs);
  printEndpoints(endpoints, scriptSrcs.length > 0);
  await probeRegistry(endpoints);

  // Save raw HTML for offline inspection
  fs.writeFileSync(path.join(__dirname, "pkg-odin.html"), html, "utf8");
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
