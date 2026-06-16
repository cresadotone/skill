import json, re, os, math, glob, asyncio
from playwright.async_api import async_playwright

ACC={"cyan":"#22D3EE","amber":"#FBBF24","magenta":"#E879F9","mint":"#34D399",
"coral":"#FB7185","violet":"#A78BFA","emerald":"#34D399","orange":"#FB923C","lime":"#A3E635",
"red":"#FB7185","blue":"#22D3EE"}

def card(meta):
    a=ACC[meta["accent"]]
    num=(re.search(r"#(\d+)",meta["subtitle"]) or [None,"--"])[1]
    n=int(num) if num.isdigit() else 0
    pts=[]
    for i in range(13):
        x=60+i*(1080/12)
        y=470-(math.sin(i*0.7+n*0.4)*0.5+0.5)*180-(i*6)
        pts.append(f"{x:.0f},{max(150,y):.0f}")
    pts=" ".join(pts)
    sub=re.sub(r"^#\d+ · ","",meta["subtitle"])
    return f"""<!DOCTYPE html><html><head><meta charset="utf8">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&family=JetBrains+Mono:wght@600;700&display=swap" rel="stylesheet"><style>
*{{margin:0;box-sizing:border-box}}
body{{width:1200px;height:630px;background:#000;overflow:hidden;position:relative;font-family:Inter,system-ui,sans-serif;color:#F2F4F8}}
.glow{{position:absolute;top:-260px;left:50%;transform:translateX(-50%);width:900px;height:620px;border-radius:50%;background:radial-gradient(closest-side,{a}38,transparent 70%);filter:blur(8px)}}
.frame{{position:absolute;inset:28px;border:1px solid #1c2230;border-radius:28px}}
.pad{{position:absolute;inset:64px;display:flex;flex-direction:column}}
.top{{display:flex;align-items:center;gap:14px}}
.dot{{width:14px;height:14px;border-radius:50%;background:{a};box-shadow:0 0 22px {a}}}
.brand{{font-size:20px;font-weight:700;letter-spacing:.12em;text-transform:uppercase;color:#8b94a4}}
.num{{margin-left:auto;font-family:'JetBrains Mono',monospace;font-weight:700;font-size:22px;color:{a};border:1.5px solid {a}66;border-radius:12px;padding:8px 16px;background:{a}14}}
.title{{margin-top:auto;font-size:84px;line-height:1.02;font-weight:800;letter-spacing:-.035em;max-width:1000px}}
.cap{{margin-top:22px;font-size:30px;font-weight:600;color:#aab3c2;letter-spacing:-.01em;max-width:980px}}
.sub{{margin-top:14px;font-family:'JetBrains Mono',monospace;font-size:19px;color:#5c6472;letter-spacing:.02em}}
svg{{position:absolute;left:0;bottom:0;width:1200px;height:520px;opacity:.5}}
.accentbar{{position:absolute;left:64px;bottom:56px;width:88px;height:6px;border-radius:4px;background:{a}}}
</style></head><body>
<div class="glow"></div>
<svg viewBox="0 0 1200 520" preserveAspectRatio="none">
<polyline points="{pts}" fill="none" stroke="{a}" stroke-width="3" stroke-opacity="0.55" stroke-linecap="round" stroke-linejoin="round"/>
<polyline points="{pts} 1140,520 60,520" fill="{a}" fill-opacity="0.07" stroke="none"/>
</svg>
<div class="frame"></div>
<div class="pad">
<div class="top"><span class="dot"></span><span class="brand">Cresa OS</span><span class="num">#{num}</span></div>
<div class="title">{meta['title']}</div>
<div class="cap">{meta['heroCap']}</div>
<div class="sub">{sub}</div>
</div>
<div class="accentbar"></div>
</body></html>"""

async def main():
    async with async_playwright() as p:
        b=await p.chromium.launch()
        for f in sorted(glob.glob("config/*.js")):
            src=open(f).read()
            meta=json.loads(re.search(r"/\*META([\s\S]*?)META\*/",src).group(1))
            os.makedirs("deploy/"+meta["slug"],exist_ok=True)
            pg=await b.new_page(viewport={"width":1200,"height":630},device_scale_factor=2)
            await pg.set_content(card(meta),wait_until="networkidle")
            await pg.wait_for_timeout(700)
            await pg.screenshot(path="deploy/"+meta["slug"]+"/og@2x.png")
            await pg.close()
            print("og:",meta["slug"])
        await b.close()
asyncio.run(main())
