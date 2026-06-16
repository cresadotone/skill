/*META
{
  "slug": "example_occupancy_cost_probe",
  "title": "Occupancy Cost Probe",
  "subtitle": "#00 · Example",
  "accent": "cyan",
  "desc": "A minimal terminal-instrument example for cresa.one.",
  "inputHead": "Scenario inputs",
  "heroCap": "Annual occupancy cost",
  "deltaLabel": "Monthly",
  "chartTitle": "Cost ramp",
  "tableHead": "Cost mix",
  "col0": "Line item",
  "note": "<b>Example only.</b> Replace assumptions and formulas with sourced domain logic.",
  "tags": ["example", "calculator", "cre"]
}
META*/
const APP = {
  slug: "example_occupancy_cost_probe",
  heroFmt: "money",
  deltaFmt: "money",
  fields: {
    rsf: { label: "Rentable SF", min: 1000, max: 250000, step: 1000, def: 25000, fmt: "int" },
    rent: { label: "Rent / SF", min: 5, max: 150, step: 1, def: 42, fmt: "money2", pre: "$" },
    opex: { label: "OpEx / SF", min: 0, max: 60, step: 1, def: 14, fmt: "money2", pre: "$" },
    growth: { label: "Annual growth", min: 0, max: 10, step: 0.25, def: 3, fmt: "pct1", suf: "%" }
  },
  tiles: [
    { id: "base", k: "Base rent", x: "year 1", fmt: "money", color: "cyan" },
    { id: "opex", k: "OpEx", x: "year 1", fmt: "money", color: "amber" },
    { id: "monthly", k: "Monthly", x: "year 1", fmt: "money", color: "mint" },
    { id: "fiveYear", k: "5-year total", x: "with growth", fmt: "money", color: "magenta" }
  ],
  series: [
    { label: "Annual cost", color: "cyan", fill: true },
    { label: "Base rent", color: "amber" }
  ],
  chart: { yfmt: "moneyK", xsuf: "y" },
  compute(s) {
    const base = s.rsf * s.rent;
    const opex = s.rsf * s.opex;
    const total = base + opex;
    const g = s.growth / 100;
    const fiveYear = Array.from({ length: 5 }, (_, i) => total * Math.pow(1 + g, i)).reduce((a, b) => a + b, 0);
    return { hero: total, heroDelta: total / 12, base, opex, monthly: total / 12, fiveYear };
  },
  verdict(r) {
    if (r.monthly < 100000) return { kind: "good", text: "Manageable" };
    if (r.monthly < 250000) return { kind: "warn", text: "Watch budget" };
    return { kind: "bad", text: "High exposure" };
  },
  chartData(s, compute) {
    const labels = [1, 2, 3, 4, 5];
    const g = s.growth / 100;
    const rent = s.rsf * s.rent;
    const total = compute(s).hero;
    return {
      labels,
      series: [
        labels.map((_, i) => total * Math.pow(1 + g, i)),
        labels.map((_, i) => rent * Math.pow(1 + g, i))
      ]
    };
  },
  table(r) {
    return [
      { k: "Base rent", value: r.base, share: true },
      { k: "OpEx", value: r.opex, share: true },
      { k: "Total", value: r.hero, total: true }
    ];
  },
  csv(r) {
    return [["annual_cost", Math.round(r.hero)], ["monthly_cost", Math.round(r.monthly)]];
  },
  summary(s, r) {
    return `Annual occupancy cost: ${FMT.money(r.hero)} (${FMT.money(r.monthly)}/mo) for ${FMT.int(s.rsf)} RSF.`;
  }
};
