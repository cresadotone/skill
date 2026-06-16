// Cresa OS · app generator
// Usage: node scripts/generate.mjs            (build all configs)
//        node scripts/generate.mjs 21         (build one)
import { readFileSync, writeFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __dir = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dir, "..");
const tpl = readFileSync(join(ROOT, "templates/template.html"), "utf8");
const runtime = readFileSync(join(ROOT, "templates/runtime.js"), "utf8");

const accentInk = { cyan:"#001318", amber:"#1A1200", magenta:"#1A0420", mint:"#00190F",
  coral:"#1A0309", violet:"#0E0420", emerald:"#001A10", orange:"#1A0B00", lime:"#0A1A00",
  red:"#1A0306", blue:"#001020" };
const accentHex = { cyan:"#22D3EE", amber:"#FBBF24", magenta:"#E879F9", mint:"#34D399",
  coral:"#FB7185", violet:"#A78BFA", emerald:"#34D399", orange:"#FB923C", lime:"#A3E635",
  red:"#FB7185", blue:"#22D3EE" };
const accentLight = { cyan:"#0E8FB0", amber:"#B26A00", magenta:"#A22FC0", mint:"#0E8C5E",
  coral:"#C2344D", violet:"#6D45D8", emerald:"#0E8C5E", orange:"#C25A00", lime:"#4F8C00",
  red:"#C2344D", blue:"#0E6FB0" };

// slug -> permanent live URL (set after first deploy)
const LIVE = {
  lease_option_valuation_black_scholes:"https://lease-option-valuation.cresa.one",
  maq_chemical_occupancy_auditor:"https://maq-occupancy-auditor.cresa.one",
  slab_vibration_vc_matcher:"https://slab-vibration-vc-matcher.cresa.one",
  hvac_emission_dispersion_modeler:"https://emission-dispersion-modeler.cresa.one",
  landlord_debt_yield_pressure_monitor:"https://debt-yield-pressure-monitor.cresa.one",
  cleanroom_turbulence_recovery_optimizer:"https://cleanroom-recovery-optimizer.cresa.one",
  portfolio_lease_underwriting_matrix:"https://portfolio-underwriting-matrix.cresa.one",
  lab_equipment_amortization_arbiter:"https://equipment-amortization-arbiter.cresa.one",
  scope3_lease_emission_estimator:"https://scope3-lease-emissions.cresa.one",
  snda_foreclosure_protection_evaluator:"https://snda-protection-evaluator.cresa.one"
};

function build(cfgPath){
  const src = readFileSync(cfgPath, "utf8");
  const meta = JSON.parse(src.match(/\/\*META([\s\S]*?)META\*\//)[1]);
  const accent = meta.accent;
  const ogUrl = LIVE[meta.slug] || "";
  const html = tpl
    .replaceAll("__TITLE__", meta.title)
    .replaceAll("__SUBTITLE__", meta.subtitle)
    .replaceAll("__DESC__", (meta.desc||meta.heroCap).replace(/"/g,"&quot;"))
    .replaceAll("__KEYWORDS__", (meta.tags||[]).join(", "))
    .replaceAll("__OGURL__", ogUrl)
    .replaceAll("__INPUTHEAD__", meta.inputHead)
    .replaceAll("__HEROCAP__", meta.heroCap)
    .replaceAll("__DELTALABEL__", meta.deltaLabel || "")
    .replaceAll("__CHARTTITLE__", meta.chartTitle)
    .replaceAll("__TABLEHEAD__", meta.tableHead)
    .replaceAll("__COL0__", meta.col0)
    .replaceAll("__NOTE__", meta.note)
    .replaceAll("__ACCENT__", accentHex[accent])
    .replaceAll("__ACCENT_ENC__", encodeURIComponent(accentHex[accent]))
    .replaceAll("__ACCENTINK__", accentInk[accent])
    .replaceAll("__ACCENTLIGHT__", accentLight[accent]);

  const out = html +
    `\n<script>\n${src.replace(/\/\*META[\s\S]*?META\*\//,"").trim()}\n</script>\n` +
    `<script>\n${runtime}\n</script>\n</body>\n</html>\n`;

  const outPath = join(ROOT, "apps", meta.slug + ".html");
  writeFileSync(outPath, out);
  return { slug: meta.slug, bytes: out.length };
}

const arg = process.argv[2];
const allCfgs = readdirSync(join(ROOT,"config")).filter(f=>f.endsWith(".js"));
const cfgs = allCfgs.filter(f=>{
  if(!arg) return true;
  if(f.includes(arg)) return true;
  const src = readFileSync(join(ROOT,"config",f),"utf8");
  const m = src.match(/\/\*META([\s\S]*?)META\*\//);
  try{ const meta=JSON.parse(m[1]); return meta.subtitle.includes("#"+arg)||meta.slug.includes(arg); }catch{ return false; }
});
if(cfgs.length===0){ console.error("no config matched:", arg); process.exit(1); }
for (const c of cfgs){
  const r = build(join(ROOT,"config",c));
  console.log(`built ${r.slug}  (${(r.bytes/1024).toFixed(0)} KB)`);
}
