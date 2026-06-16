/* ===== Cresa OS · shared instrument runtime ===== */
"use strict";
const RM = matchMedia("(prefers-reduced-motion:reduce)").matches;
const $ = s => document.querySelector(s);
const $$ = s => [...document.querySelectorAll(s)];

// APP is injected above this script by the generator.
const F = APP.fields;
const ORDER = Object.keys(F);
const state = {};
let mode = APP.modes ? APP.modes.options[0].id : null;

/* ── number formatters available to config ── */
const FMT = {
  money: v => "$" + Math.round(v).toLocaleString(),
  money2: v => "$" + v.toFixed(2),
  moneyK: v => "$" + (Math.abs(v) >= 1000 ? (v/1000).toFixed(0) + "k" : Math.round(v)),
  int: v => Math.round(v).toLocaleString(),
  int1: v => v.toLocaleString(undefined,{maximumFractionDigits:1}),
  pct: v => v.toFixed(0) + "%",
  pct1: v => v.toFixed(1) + "%",
  num2: v => v.toFixed(2),
  num1: v => v.toFixed(1),
  x: v => v.toFixed(2) + "×",
  yr: v => v.toFixed(v % 1 ? 1 : 0) + " yr"
};
function fmt(spec, v){ return typeof spec === "function" ? spec(v) : FMT[spec](v); }

/* ── build inputs from config ── */
function buildInputs(){
  const host = $("#inputs");
  let html = "";
  if (APP.modes){
    html += `<div class="field"><div class="fhead"><label>${APP.modes.label}</label></div>
      <div class="seg" role="group" aria-label="${APP.modes.label}">` +
      APP.modes.options.map((o,i)=>`<button data-mode="${o.id}" aria-pressed="${i===0}">${o.label}</button>`).join("") +
      `</div></div>`;
  }
  for (const k of ORDER){
    const f = F[k];
    const pre = f.pre ? `<span class="pre">${f.pre}</span>` : "";
    const suf = f.suf ? `<span class="suf">${f.suf}</span>` : "";
    const inputmode = f.dp ? "decimal" : "numeric";
    if (f.sliderOnly){
      html += `<div class="field" data-key="${k}">
        <div class="fhead"><label for="${k}_s">${f.label}</label><span class="rv mono" id="${k}_rv"></span></div>
        <div class="slider"><input id="${k}_s" type="range" min="${f.min}" max="${f.max}" step="${f.step}" aria-label="${f.label}"></div>
      </div>`;
    } else {
      html += `<div class="field" data-key="${k}">
        <div class="fhead"><label for="${k}_n">${f.label}</label><span class="rv mono" id="${k}_rv"></span></div>
        <div class="inrow">
          <button class="step" data-step="-1" aria-label="decrease ${f.label}">−</button>
          <div class="box">${pre}<input id="${k}_n" type="number" inputmode="${inputmode}" step="${f.step}" aria-label="${f.label}">${suf}</div>
          <button class="step" data-step="1" aria-label="increase ${f.label}">+</button>
        </div>
        <div class="slider"><input id="${k}_s" type="range" min="${f.min}" max="${f.max}" step="${f.step}" aria-label="${f.label} slider"></div>
      </div>`;
    }
  }
  host.innerHTML = html;
}

/* ── build tiles, series toggles, shortcut list ── */
function buildTiles(){
  $("#tiles").innerHTML = APP.tiles.map(t =>
    `<div class="tile"><div class="k"><i style="background:var(--${t.color})"></i>${t.k}</div>
     <div class="v mono" id="tile_${t.id}">—</div><div class="x">${t.x}</div></div>`).join("");
}
function buildSeries(){
  $("#series").innerHTML = APP.series.map((s,i)=>
    `<button data-s="${i}" aria-pressed="${s.on!==false}"><span class="sw" style="background:var(--${s.color})"></span>${s.label}</button>`).join("");
}
function buildShortcuts(){
  const rows = [];
  ORDER.slice(0,9).forEach((k,i)=>rows.push([`Jump to ${F[k].label}`, String(i+1)]));
  if (APP.modes) rows.push([`Toggle ${APP.modes.label}`,"M"]);
  rows.push(["Toggle light/dark","T"],["Reset to defaults","R"],["Clear all","0"],
    ["Copy summary","C"],["Export CSV","E"],["Share link","L"],["Open this dialog","?"],["Close dialog","Esc"]);
  $("#kbList").innerHTML = rows.map(([s,k])=>`<div class="kb"><span>${s}</span><kbd>${k}</kbd></div>`).join("");
}

/* ── count-up animation ── */
const animers = new Map();
function setNum(el,to,spec){
  if(!el) return;
  const from = animers.get(el)?.cur ?? to;
  if(RM || !isFinite(to)){ el.textContent = fmt(spec, isFinite(to)?to:0); animers.set(el,{cur:to}); return; }
  if(animers.get(el)?.raf) cancelAnimationFrame(animers.get(el).raf);
  const t0=performance.now(), dur=420;
  const tick=now=>{
    const p=Math.min((now-t0)/dur,1), e=1-Math.pow(1-p,3), cur=from+(to-from)*e;
    el.textContent=fmt(spec,cur); animers.set(el,{cur, raf:p<1?requestAnimationFrame(tick):0});
  };
  animers.set(el,{cur:from, raf:requestAnimationFrame(tick)});
}

/* ── chart ── */
let chart; const seriesOn = [];
function hexToRgba(hex,a){
  hex=hex.trim();
  if(hex.startsWith("#")){
    const n=hex.length===4?hex.slice(1).split("").map(c=>c+c).join(""):hex.slice(1);
    const r=parseInt(n.slice(0,2),16),g=parseInt(n.slice(2,4),16),b=parseInt(n.slice(4,6),16);
    return `rgba(${r},${g},${b},${a})`;
  }
  return hex; // already rgb/rgba/named
}
function buildChart(){
  APP.series.forEach((s,i)=>seriesOn[i]=s.on!==false);
  const css = getComputedStyle(document.documentElement);
  Chart.defaults.color = css.getPropertyValue("--tx3").trim();
  Chart.defaults.font.family = "ui-monospace,monospace";
  chart = new Chart($("#chart"), {
    type:"line",
    data:{labels:[],datasets:APP.series.map(s=>{
      const col=css.getPropertyValue("--"+s.color).trim();
      return { label:s.label, data:[], borderColor:col,
        backgroundColor:s.fill?hexToRgba(col,0.10):"transparent",
        fill:!!s.fill, borderDash:s.dash?[5,4]:[], tension:.35, borderWidth:s.fill?2.5:2, pointRadius:0 };
    })},
    options:{responsive:true,maintainAspectRatio:false,
      animation:RM?false:{duration:420,easing:"easeOutCubic"},
      interaction:{intersect:false,mode:"index"},
      plugins:{legend:{display:false},tooltip:{
        backgroundColor:css.getPropertyValue("--s3").trim(),borderColor:css.getPropertyValue("--line2").trim(),
        borderWidth:1,padding:10,callbacks:{label:c=>" "+c.dataset.label+": "+fmt(APP.chart.yfmt||"int",c.parsed.y)}}},
      scales:{
        x:{grid:{color:css.getPropertyValue("--grid").trim()},
           ticks:{maxRotation:0,autoSkip:true,maxTicksLimit:6,
             callback:function(v){return (APP.chart.xsuf?this.getLabelForValue(v)+APP.chart.xsuf:this.getLabelForValue(v))}}},
        y:{grid:{color:css.getPropertyValue("--grid").trim()},
           ticks:{callback:v=>fmt(APP.chart.yfmt||"int",v)}}}}
  });
}
function refreshChart(){
  const {labels,series} = APP.chartData(state,compute);
  chart.data.labels = labels;
  series.forEach((d,i)=>{ chart.data.datasets[i].data=d; chart.data.datasets[i].hidden=!seriesOn[i]; });
  // recolor for theme switches
  const css=getComputedStyle(document.documentElement);
  chart.data.datasets.forEach((ds,i)=>{
    const col=css.getPropertyValue("--"+APP.series[i].color).trim();
    ds.borderColor=col;
    if(APP.series[i].fill) ds.backgroundColor=hexToRgba(col,0.10);
  });
  chart.options.scales.x.grid.color=chart.options.scales.y.grid.color=css.getPropertyValue("--grid").trim();
  Chart.defaults.color=css.getPropertyValue("--tx3").trim();
  chart.update();
}

const compute = (s)=>APP.compute(s, mode);

/* ── render ── */
function render(){
  const r = compute(state);
  setNum($("#hero"), r.hero, APP.heroFmt);
  if (r.heroDelta!==undefined) $("#heroDelta").textContent = (r.heroDelta>=0?"+":"")+fmt(APP.deltaFmt||APP.heroFmt, r.heroDelta);
  APP.tiles.forEach(t=>{
    const el=$("#tile_"+t.id); if(!el) return;
    setNum(el, r[t.id], t.fmt);
    const cls = t.state ? t.state(r) : "";
    el.className = "v mono " + cls;
  });
  const vd = APP.verdict(r);
  const v=$("#verdict"); v.className="verdict "+vd.kind; $("#verdictTx").textContent=vd.text;
  // table
  const rows = APP.table(r, state);
  const tot = rows.reduce((a,b)=>a+(b.share?b.value:0),0) || 1;
  $("#tbody").innerHTML = rows.map(row=>{
    if (row.total) return `<tr><td class="lbl" style="color:var(--tx)"><b>${row.k}</b></td>
       <td class="r" style="color:var(--accent)">${fmt(row.fmt||APP.heroFmt,row.value)}</td><td class="r">100%</td></tr>`;
    const pct = row.share ? Math.max(0,Math.min(100,row.value/tot*100)) : null;
    return `<tr><td class="lbl">${row.k}</td><td class="r">${fmt(row.fmt||APP.heroFmt,row.value)}</td>
      <td class="r">${pct===null?"—":pct.toFixed(0)+"%"+`<div class="bar" style="width:${pct}%"></div>`}</td></tr>`;
  }).join("");
  refreshChart();
}

/* ── field sync ── */
function setField(k,val,silent){
  const f=F[k]; if(isNaN(val)) return;
  val=Math.max(f.min,Math.min(f.max,val));
  val=Math.round(val/f.step)*f.step;
  val=parseFloat(val.toFixed(6));
  state[k]=val;
  const rv=$("#"+k+"_rv"); if(rv) rv.textContent=fmt(f.fmt,val);
  const n=$("#"+k+"_n"); if(n && document.activeElement!==n) n.value=val;
  const s=$("#"+k+"_s"); if(s) s.value=val;
  if(!silent) render();
}
function bind(k){
  const f=F[k], n=$("#"+k+"_n"), s=$("#"+k+"_s");
  if(s) s.addEventListener("input",()=>setField(k,parseFloat(s.value)));
  if(n) n.addEventListener("input",()=>{const v=parseFloat(n.value); if(!isNaN(v)) setField(k,v);});
  $$(`[data-key="${k}"] .step`).forEach(b=>b.addEventListener("click",()=>{
    haptic(); setField(k, state[k]+f.step*parseInt(b.dataset.step));
  }));
}
function haptic(){ if(!RM && navigator.vibrate) navigator.vibrate(8); }

/* ── modes ── */
function setMode(m){
  if(!APP.modes) return;
  mode=m;
  $$(".seg [data-mode]").forEach(b=>b.setAttribute("aria-pressed", b.dataset.mode===m));
  render();
}

/* ── theme ── */
function applyTheme(t){
  document.documentElement.setAttribute("data-theme", t);
  $("#metaTheme").content = t==="light" ? "#F4F6FA" : "#000000";
  try{ localStorage.setItem("cresaos-theme", t); }catch{}
  if(chart) refreshChart();
}
function toggleTheme(){
  const cur = document.documentElement.getAttribute("data-theme")==="light"?"dark":"light";
  applyTheme(cur); toast(cur==="light"?"Light mode":"Dark mode");
}

/* ── toast ── */
function toast(m){const t=$("#toast");t.textContent=m;t.classList.add("on");
  clearTimeout(t._t);t._t=setTimeout(()=>t.classList.remove("on"),1700);}

/* ── quick actions ── */
function defaults(){ ORDER.forEach(k=>setField(k,F[k].def,true)); if(APP.modes) setMode(APP.modes.options[0].id); else render(); }
function clearAll(){ ORDER.forEach(k=>setField(k,F[k].min,true)); render(); toast("Cleared"); }
function summary(){ return APP.summary(state, compute(state), mode); }

$("#qaTheme").onclick=toggleTheme;
$("#qaReset").onclick=()=>{defaults();toast("Reset to defaults");};
$("#qaCopy").onclick=async()=>{try{await navigator.clipboard.writeText(summary());toast("Summary copied");}catch{toast("Copy blocked")}};
$("#qaCsv").onclick=()=>{
  const r=compute(state);
  const rows=[["field","value"]];
  ORDER.forEach(k=>rows.push([k,state[k]]));
  if(APP.modes) rows.push(["mode",mode]);
  APP.csv(r).forEach(([k,v])=>rows.push([k,v]));
  const blob=new Blob([rows.map(r=>r.join(",")).join("\n")],{type:"text/csv"});
  const a=document.createElement("a");a.href=URL.createObjectURL(blob);
  a.download=APP.slug+".csv";a.click();toast("CSV exported");
};
$("#qaLink").onclick=async()=>{
  const p=new URLSearchParams(); ORDER.forEach(k=>p.set(k,state[k])); if(APP.modes)p.set("m",mode);
  const url=location.origin+location.pathname+"#"+p.toString();
  try{await navigator.clipboard.writeText(url);toast("Share link copied");}catch{toast("Link in URL")}
  location.hash=p.toString();
};

/* ── series toggles (delegated, since built dynamically) ── */
$("#series").addEventListener("click",e=>{
  const b=e.target.closest("button"); if(!b)return;
  const i=+b.dataset.s; seriesOn[i]=!seriesOn[i]; b.setAttribute("aria-pressed",seriesOn[i]); refreshChart();
});
/* ── mode toggles (delegated) ── */
document.addEventListener("click",e=>{
  const b=e.target.closest(".seg [data-mode]"); if(!b)return; haptic(); setMode(b.dataset.mode);
});

/* ── dialog + keyboard ── */
const scrim=$("#scrim"),dlg=$("#dlg");
const openDlg=()=>{scrim.classList.add("on");dlg.focus();};
const closeDlg=()=>scrim.classList.remove("on");
$("#qaHelp").onclick=openDlg;
scrim.onclick=e=>{if(e.target===scrim)closeDlg();};
addEventListener("keydown",e=>{
  if(scrim.classList.contains("on")){
    if(e.key==="Escape")closeDlg();
    if(e.key==="Tab"){e.preventDefault();dlg.focus();}
    return;
  }
  if(document.activeElement.tagName==="INPUT" && e.key!=="Escape") return;
  if(e.key==="?"||(e.shiftKey&&e.key==="/")){e.preventDefault();openDlg();return;}
  if(e.key>="1"&&e.key<="9"){const k=ORDER[+e.key-1];if(k){const el=$("#"+k+"_n")||$("#"+k+"_s");if(el){el.focus();e.preventDefault();}}return;}
  const K=e.key.toLowerCase();
  if(K==="m"&&APP.modes){const ids=APP.modes.options.map(o=>o.id);setMode(ids[(ids.indexOf(mode)+1)%ids.length]);}
  else if(K==="t"){toggleTheme();}
  else if(K==="r"){defaults();toast("Reset");}
  else if(e.key==="0"){clearAll();}
  else if(K==="c"){$("#qaCopy").click();}
  else if(K==="e"){$("#qaCsv").click();}
  else if(K==="l"){$("#qaLink").click();}
  else if(e.key==="Escape"){closeDlg();}
});

/* ── hash restore ── */
function fromHash(){
  if(!location.hash) return false;
  const p=new URLSearchParams(location.hash.slice(1)); let any=false;
  ORDER.forEach(k=>{if(p.has(k)){state[k]=parseFloat(p.get(k));any=true;}});
  if(p.has("m"))mode=p.get("m");
  return any;
}

/* ── init ── */
(function init(){
  let t="dark"; try{t=localStorage.getItem("cresaos-theme")||"dark";}catch{}
  document.documentElement.setAttribute("data-theme",t);
  $("#metaTheme").content = t==="light"?"#F4F6FA":"#000000";
  ORDER.forEach(k=>state[k]=F[k].def);
  buildInputs(); buildTiles(); buildSeries(); buildShortcuts();
  ORDER.forEach(bind);
  buildChart();
  const restored=fromHash();
  ORDER.forEach(k=>setField(k,state[k],true));
  if(APP.modes) setMode(mode||APP.modes.options[0].id); else render();
  render();
})();
