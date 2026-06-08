// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See the repository LICENSE.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

/* QSeq web generator — ports the core QSeq encoders + sizing to the browser.
   © 2026 Meerv Inc. Rendering via bwip-js. */
'use strict';

const APP_VERSION='1.0.0';

// ---- encoders --------------------------------------------------------------
function gtinCheck(data){let s=0,n=data.length;for(let i=0;i<n;i++){const d=+data[i];s+=d*(((n-1-i)%2===0)?3:1);}return (10-(s%10))%10;}
function gtinValid(g){return /^\d+$/.test(g)&&g.length>=8&&gtinCheck(g.slice(0,-1))===+g.slice(-1);}
function gtin14(g){g=g.trim();if(!/^\d+$/.test(g))throw 'GTIN must be numeric';
  if(![8,12,13,14].includes(g.length))throw 'GTIN must be 8, 12, 13 or 14 digits';
  if(!gtinValid(g))throw 'GTIN check digit is invalid';return g.padStart(14,'0');}
function sgtinElement(g,sn){return `(01)${gtin14(g)}(21)${sn}`;}
function sgtinLink(g,sn,dom){return `${dom.replace(/\/$/,'')}/01/${gtin14(g)}/21/${encodeURIComponent(sn)}`;}
function sgtinEpc(g,sn,cpl){const x=gtin14(g);if(cpl<6||cpl>12)throw 'Company prefix length must be 6–12';
  return `urn:epc:id:sgtin:${x.slice(1,1+cpl)}.${x[0]}${x.slice(1+cpl,13)}.${sn}`;}
function nsnDigits(s){const x=s.replace(/[\s-]/g,'');if(!/^\d{13}$/.test(x))throw 'NSN must be exactly 13 digits';return x;}
function nsnFormat(x){return `${x.slice(0,4)}-${x.slice(4,6)}-${x.slice(6,9)}-${x.slice(9,13)}`;}

// ---- capacity tables -------------------------------------------------------
const QR=[[17,14,11,7],[32,26,20,14],[53,42,32,24],[78,62,46,34],[106,84,60,44],[134,106,74,58],[154,122,86,64],[192,152,108,84],[230,180,130,98],[271,213,151,119],[321,251,177,137],[367,287,203,155],[425,331,241,177],[458,362,258,194],[520,412,292,220],[586,450,322,250],[644,504,364,280],[718,560,394,310],[792,624,442,338],[858,666,482,382],[929,711,509,403],[1003,779,565,439],[1091,857,611,461],[1171,911,661,511],[1273,997,715,535],[1367,1059,751,593],[1465,1125,805,625],[1528,1190,868,658],[1628,1264,908,698],[1732,1370,982,742],[1840,1452,1030,790],[1952,1538,1112,842],[2068,1628,1168,898],[2188,1722,1228,958],[2303,1809,1283,983],[2431,1911,1351,1051],[2563,1989,1423,1093],[2699,2099,1499,1139],[2809,2213,1579,1219],[2953,2331,1663,1273]];
const EC_COL={L:0,M:1,Q:2,H:3};
const EC_FRAC={L:0.07,M:0.15,Q:0.25,H:0.30};
function qrModules(v){return 17+4*v;}
function qrMinVersion(bytes,ec){const c=EC_COL[ec];for(let v=1;v<=40;v++)if(QR[v-1][c]>=bytes)return v;return null;}
// Data Matrix square ECC 200: [modules, dataCW, ecCW]
const DM=[[10,3,5],[12,5,7],[14,8,10],[16,12,12],[18,18,14],[20,22,18],[22,30,20],[24,36,24],[26,44,28],[32,62,36],[36,86,42],[40,114,48],[44,144,56],[48,174,68],[52,204,84],[64,280,112],[72,368,144],[80,456,192],[88,576,224],[96,696,272],[104,816,336],[120,1050,408],[132,1304,496],[144,1558,620]];
function dmMinSize(bytes){for(const d of DM){if(Math.max(1,d[1]-2)>=bytes)return d;}return null;}

// ---- sizing ----------------------------------------------------------------
const utf8len=s=>new TextEncoder().encode(s).length;
const moduleDots=(xmm,dpi)=>Math.max(1,Math.round(xmm/25.4*dpi));
const mm=px_dpi=>px_dpi*25.4;

// ---- DOM helpers -----------------------------------------------------------
const $=id=>document.getElementById(id);
const val=id=>$(id)?.value ?? '';
const num=id=>parseFloat(val(id));
function show(sel,on){document.querySelectorAll(`[data-when~="${sel}"]`).forEach(e=>e.hidden=!on);}

const state=()=>({
  mode:val('mode'),kind:val('kind'),gtin:val('gtin'),serial:val('serial'),
  sgtinFormat:val('sgtinFormat'),cpl:num('cpl'),domain:val('domain'),
  nsn:val('nsn'),text:val('text'),twoD:val('twoD'),ec:val('ec'),oneD:val('oneD'),
  dpi:num('dpi'),xdim:num('xdim'),logo:num('logo'),ecbudget:num('ecbudget'),barh:num('barh'),
  sprefix:val('sprefix'),sstart:parseInt(val('sstart'))||0,scount:parseInt(val('scount'))||1,spad:parseInt(val('spad'))||0,
});

const is1D=s=>s.mode.startsWith('1d');
const isSerial=s=>s.mode.endsWith('Serial');
const bcid=s=>is1D(s)?s.oneD:s.twoD;

// Build the encoded payload for a given serial (or the static serial).
function encode(s,serialOverride){
  const sn=serialOverride!=null?serialOverride:s.serial;
  if(s.kind==='nsn')return serialOverride!=null?serialOverride:nsnDigits(s.nsn);
  if(s.kind==='text')return serialOverride!=null?(s.text+serialOverride):s.text;
  // sgtin
  if(s.sgtinFormat==='element')return sgtinElement(s.gtin,sn);
  if(s.sgtinFormat==='epc')return sgtinEpc(s.gtin,sn,s.cpl);
  return sgtinLink(s.gtin,sn,s.domain);
}

function captionParts(s){
  if(s.kind==='nsn')return['',nsnFormat(nsnDigits(s.nsn))];
  if(s.kind==='text')return['',''];
  return['',s.serial];
}

// ---- rendering -------------------------------------------------------------
const ppmm=dpi=>dpi/25.4; // pixels per millimetre at a DPI

// Render one barcode to a NEW canvas (with centre logo knockout for 2D).
function makeCanvas(s,text){
  const opts={bcid:bcid(s),text:text,scale:Math.max(2,moduleDots(s.xdim,s.dpi)),
    paddingwidth:0,paddingheight:0};
  if(!is1D(s)&&s.twoD==='qrcode')opts.eclevel=s.ec;
  if(is1D(s)){opts.height=Math.max(6,s.barh);opts.includetext=true;}
  const cv=document.createElement('canvas');
  window.bwipjs.toCanvas(cv,opts);
  if(!is1D(s)&&s.logo>0){
    const ctx=cv.getContext('2d');
    const side=Math.min(cv.width,cv.height)*logoFrac(s);
    ctx.fillStyle='#fff';
    ctx.fillRect((cv.width-side)/2,(cv.height-side)/2,side,side);
  }
  return cv;
}

// Draw a caption (prefix normal + bold counter) onto a 2D canvas context.
function drawCanvasCaption(ctx,prefix,bold,cx,y,fs){
  ctx.textAlign='left';ctx.textBaseline='middle';ctx.fillStyle='#000';
  ctx.font=`${fs}px monospace`;const pw=ctx.measureText(prefix).width;
  ctx.font=`bold ${fs}px monospace`;const bw=ctx.measureText(bold).width;
  let tx=cx-(pw+bw)/2;if(tx<0)tx=0;
  ctx.font=`${fs}px monospace`;if(prefix)ctx.fillText(prefix,tx,y);
  ctx.font=`bold ${fs}px monospace`;if(bold)ctx.fillText(bold,tx+pw,y);
}

// A single code with its caption underneath, on one canvas.
function composeSingle(s){
  const cv=makeCanvas(s,encode(s,null));
  const cap=captionParts(s);
  if(!(cap[0]||cap[1]))return cv;
  const capH=Math.round(ppmm(s.dpi)*4.5);
  const out=document.createElement('canvas');out.width=cv.width;out.height=cv.height+capH;
  const ctx=out.getContext('2d');ctx.fillStyle='#fff';ctx.fillRect(0,0,out.width,out.height);
  ctx.drawImage(cv,0,0);
  drawCanvasCaption(ctx,cap[0],cap[1],out.width/2,cv.height+capH*0.55,capH*0.46);
  return out;
}

// The serialized sheet (a grid of captioned cells) on one canvas.
function composeSheet(s){
  const n=Math.min(s.scount,120);
  const cells=[];
  for(let i=0;i<n;i++){
    const counter=String(s.sstart+i).padStart(s.spad,'0');
    cells.push({cv:makeCanvas(s,encode(s,s.sprefix+counter)),prefix:s.sprefix,counter});
  }
  const capH=Math.round(ppmm(s.dpi)*4.2);
  const cw=Math.max(...cells.map(c=>c.cv.width));
  const ch=Math.max(...cells.map(c=>c.cv.height))+capH;
  const gap=Math.round(ppmm(s.dpi)*3);
  const cols=Math.max(1,Math.floor(Math.sqrt(n*1.5)));
  const rows=Math.ceil(n/cols);
  const out=document.createElement('canvas');
  out.width=cols*cw+(cols+1)*gap;out.height=rows*ch+(rows+1)*gap;
  const ctx=out.getContext('2d');ctx.fillStyle='#fff';ctx.fillRect(0,0,out.width,out.height);
  cells.forEach((c,i)=>{
    const cx=gap+(i%cols)*(cw+gap),cy=gap+Math.floor(i/cols)*(ch+gap);
    ctx.drawImage(c.cv,cx+(cw-c.cv.width)/2,cy);
    drawCanvasCaption(ctx,c.prefix,c.counter,cx+cw/2,cy+c.cv.height+capH*0.55,capH*0.46);
  });
  return out;
}

// Scale the preview card down (CSS zoom) so it never overflows the stage
// horizontally — keeps the sheet readable and the log fully visible.
function fitCardToStage(card,stage){
  requestAnimationFrame(()=>{
    const avail=stage.clientWidth-40;
    const w=card.scrollWidth;
    card.style.zoom=(w>avail&&avail>0)?(avail/w).toFixed(3):'1';
  });
}

// Wrap a canvas with an on-screen mm/inch ruler (x + y) and a vernier corner.
function wrapWithRulers(canvas,dpi){
  const band=44;
  const grid=document.createElement('div');
  grid.style.display='grid';
  grid.style.gridTemplateColumns=`${canvas.width}px ${band}px`;
  grid.style.gridTemplateRows=`${canvas.height}px ${band}px`;
  grid.style.background='#fff';grid.style.padding='8px';grid.style.borderRadius='8px';
  const c1=document.createElement('div');c1.appendChild(canvas);
  grid.appendChild(c1);
  grid.appendChild(rulerSVG(canvas.height,dpi,'v',band));
  grid.appendChild(rulerSVG(canvas.width,dpi,'h',band));
  grid.appendChild(vernierSVG(dpi,band));
  return grid;
}

function rulerSVG(lenPx,dpi,orient,band){
  const ns='http://www.w3.org/2000/svg',ppm=ppmm(dpi);
  const W=orient==='h'?lenPx:band,H=orient==='h'?band:lenPx;
  const svg=document.createElementNS(ns,'svg');
  svg.setAttribute('width',W);svg.setAttribute('height',H);
  const ln=(x1,y1,x2,y2,w)=>{const l=document.createElementNS(ns,'line');
    l.setAttribute('x1',x1);l.setAttribute('y1',y1);l.setAttribute('x2',x2);l.setAttribute('y2',y2);
    l.setAttribute('stroke','#111');l.setAttribute('stroke-width',w);svg.appendChild(l);};
  const tx=(x,y,s)=>{const t=document.createElementNS(ns,'text');t.setAttribute('x',x);t.setAttribute('y',y);
    t.setAttribute('font-size','9');t.setAttribute('font-family','monospace');t.setAttribute('fill','#111');t.textContent=s;svg.appendChild(t);};
  const mmN=Math.floor(lenPx/ppm);
  for(let i=0;i<=mmN;i++){const p=i*ppm,maj=i%10===0,med=i%5===0,L=maj?13:(med?8:4);
    if(orient==='h'){ln(p,0,p,L,maj?1.1:0.6);if(maj&&i)tx(p+1.5,22,String(i));}
    else{ln(0,p,L,p,maj?1.1:0.6);if(maj&&i)tx(1.5,p+10,String(i));}}
  tx(1.5,orient==='h'?11:9,'mm');
  const sN=Math.floor(lenPx/(dpi/16));
  for(let j=0;j<=sN;j++){const p=j*dpi/16,maj=j%16===0,half=j%8===0,q=j%4===0,L=maj?13:(half?9:(q?6:3));
    if(orient==='h'){ln(p,H-L,p,H,maj?1.1:0.6);if(maj&&j)tx(p+1.5,H-15,(j/16)+'"');}
    else{ln(W-L,p,W,p,maj?1.1:0.6);if(maj&&j)tx(W-20,p+10,(j/16)+'"');}}
  return svg;
}

// Vernier corner block: 10 divisions over 9 mm → 0.1 mm reading.
function vernierSVG(dpi,band){
  const ns='http://www.w3.org/2000/svg',ppm=ppmm(dpi);
  const svg=document.createElementNS(ns,'svg');
  svg.setAttribute('width',band);svg.setAttribute('height',band);
  const ln=(x1,y1,x2,y2,w)=>{const l=document.createElementNS(ns,'line');
    l.setAttribute('x1',x1);l.setAttribute('y1',y1);l.setAttribute('x2',x2);l.setAttribute('y2',y2);
    l.setAttribute('stroke','#111');l.setAttribute('stroke-width',w);svg.appendChild(l);};
  const scale=Math.min(1,(band-6)/(9*ppm));const x0=2,y0=8,u=0.9*ppm*scale;
  ln(x0,y0,x0+9*ppm*scale,y0,1.1);
  for(let k=0;k<=10;k++){ln(x0+k*u,y0,x0+k*u,y0+6,k%5===0?1.1:0.5);}
  const t=document.createElementNS(ns,'text');t.setAttribute('x',2);t.setAttribute('y',band-4);
  t.setAttribute('font-size','7');t.setAttribute('font-family','monospace');t.setAttribute('fill','#111');
  t.textContent='vern 0.1mm';svg.appendChild(t);
  return svg;
}

function logoFrac(s){ // logo side / symbol side, from the computed outer size
  const info=size(s);
  if(!info||s.logo<=0)return 0;
  return Math.min(0.5,s.logo/info.outerWmm);
}

function size(s){
  try{
    const bytes=utf8len(encode(s,isSerial(s)?(s.sprefix+String(s.sstart).padStart(s.spad,'0')):null));
    const dots=moduleDots(s.xdim,s.dpi);
    if(is1D(s)){
      // approximate width via a probe render is overkill; report module + DPI only
      return {label:`${bcid(s).toUpperCase()}`,outerWmm:0,outerHmm:s.barh,dots,bytes,cap:null,fits:true,budget:null};
    }
    if(s.twoD==='qrcode'){
      const v=qrMinVersion(bytes,s.ec);if(!v)return {fits:false,msg:`Data exceeds QR capacity at EC ${s.ec}`};
      const m=qrModules(v),side=m+8,wmm=mm(side*dots/s.dpi),symMm=mm(m*dots/s.dpi);
      return {label:`Version ${v} · ${m}×${m}`,outerWmm:wmm,outerHmm:wmm,dots,bytes,cap:QR[v-1][EC_COL[s.ec]],fits:true,
        budget:budget(s,symMm,EC_FRAC[s.ec])};
    }else{
      const d=dmMinSize(bytes);if(!d)return {fits:false,msg:'Data exceeds largest Data Matrix'};
      const m=d[0],side=m+2,wmm=mm(side*dots/s.dpi),symMm=mm(m*dots/s.dpi),frac=d[2]/(d[1]+d[2]);
      return {label:`Size ${m}×${m}`,outerWmm:wmm,outerHmm:wmm,dots,bytes,cap:Math.max(1,d[1]-2),fits:true,
        budget:budget(s,symMm,frac),note:`ECC 200 fixed ${Math.round(frac*100)}%`};
    }
  }catch(e){return {fits:false,msg:String(e)};}
}

function budget(s,symMm,frac){
  if(s.logo<=0)return null;
  const area=Math.pow(s.logo/symMm,2),b=frac*(s.ecbudget/100);
  return {area,b,fits:area<=b,max:symMm*Math.sqrt(b)};
}

// ---- main render -----------------------------------------------------------
function render(){
  const s=state();
  // toggle field visibility
  show('sgtin',s.kind==='sgtin');show('nsn',s.kind==='nsn');show('text',s.kind==='text');
  show('static',!isSerial(s));show('serial',isSerial(s));
  show('2d',!is1D(s));show('1d',is1D(s));show('qr',!is1D(s)&&s.twoD==='qrcode');
  show('epc',s.kind==='sgtin'&&s.sgtinFormat==='epc');
  show('dl',s.kind==='sgtin'&&s.sgtinFormat==='dl');
  // reflect the current resolver in the preset selector
  const rsel=$('resolver');
  if(rsel){const known=['https://id.gs1.org','https://tapdpp.qdat.io'];
    rsel.value=known.includes(s.domain)?s.domain:'custom';}

  const stage=$('stage');stage.innerHTML='';$('err').textContent='';
  try{
    const canvas=isSerial(s)?composeSheet(s):composeSingle(s);
    const card=document.createElement('div');card.className='card';
    card.appendChild(wrapWithRulers(canvas,s.dpi));
    stage.appendChild(card);
    fitCardToStage(card,stage); // shrink the sheet to fit — no horizontal scroll
    if(isSerial(s)&&s.scount>120){const note=document.createElement('div');note.className='cap';
      note.style.color='#888';note.style.marginTop='8px';
      note.textContent=`Showing first 120 of ${s.scount}`;stage.appendChild(note);}
  }catch(e){$('err').textContent=String(e);}
  renderReadout(s);
  renderLog(s);
}

// Right-hand Serialization Log: the full encoded payload (GS1 Digital Link) for
// every code, mirroring the desktop app.
function renderLog(s){
  const log=$('log'),cnt=$('logCount');
  if(!log)return;
  let entries=[];
  try{
    if(isSerial(s)){
      const n=Math.min(s.scount,2000);
      for(let i=0;i<n;i++){
        const counter=String(s.sstart+i).padStart(s.spad,'0');
        entries.push(encode(s,s.sprefix+counter));
      }
    }else{
      entries=[encode(s,null)];
    }
  }catch(e){entries=[];}
  if(!entries.length){cnt.textContent='';log.innerHTML='<div class="empty">No codes.</div>';return;}
  cnt.textContent=`${entries.length} code${entries.length>1?'s':''} · full encoded link`;
  const isLink=v=>/^https?:\/\//.test(v);
  const w=String(entries.length).length;
  log.innerHTML=entries.map((v,i)=>{
    const num=String(i+1).padStart(w,' ');
    const cell=isLink(v)
      ? `<a href="${escapeHtml(v)}" target="_blank" rel="noopener">${escapeHtml(v)}</a>`
      : escapeHtml(v);
    return `<div class="row"><span class="n">${num}</span><span>${cell}</span></div>`;
  }).join('');
}

function renderReadout(s){
  const r=$('readout');const info=size(s);
  if(!info||!info.fits){r.innerHTML=`<div class="full bad">${escapeHtml(info?.msg||'—')}</div>`;return;}
  const cells=[];
  if(!is1D(s)){
    cells.push(kv('Outer size',`${info.outerWmm.toFixed(1)} × ${info.outerHmm.toFixed(1)} mm`));
    cells.push(kv('',`${(info.outerWmm/25.4).toFixed(2)} × ${(info.outerHmm/25.4).toFixed(2)} in`));
  }else{
    cells.push(kv('Symbology',info.label));
    cells.push(kv('Bar height',`${s.barh} mm`));
  }
  cells.push(kv('Geometry',info.label));
  cells.push(kv('Bytes',info.cap!=null?`${info.bytes} / ${info.cap}`:`${info.bytes}`));
  if(info.note)cells.push(`<div class="full warn">${escapeHtml(info.note)} — not adjustable.</div>`);
  if(info.budget){const bd=info.budget;
    cells.push(`<div class="full ${bd.fits?'ok':'bad'}">Logo ${(bd.area*100).toFixed(1)}% of ${(bd.b*100).toFixed(1)}% budget`+
      ` · max safe ≈ ${bd.max.toFixed(1)} mm ${bd.fits?'✓':'✗'}</div>`);}
  cells.push(`<div class="full">Module ${info.dots} dots @ ${s.dpi} DPI · print at ${s.dpi} DPI for exact size</div>`);
  r.innerHTML=cells.join('');
}
const kv=(k,v)=>`<div><div class="k">${escapeHtml(k)}</div><div class="v">${escapeHtml(v)}</div></div>`;
const escapeHtml=s=>String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));

// ---- downloads -------------------------------------------------------------
function downloadPng(){
  const s=state();
  try{
    const cv=isSerial(s)?composeSheet(s):composeSingle(s);
    saveCanvas(cv,isSerial(s)?'qseq-sheet.png':'qseq-code.png');
  }catch(e){$('err').textContent=String(e);}
}
function saveCanvas(cv,name){const a=document.createElement('a');a.download=name;a.href=cv.toDataURL('image/png');a.click();}

// Print-true PDF at the chosen DPI (1 px = 25.4/dpi mm). The bold counter is
// rendered bold, matching the desktop app.
function pdfCaption(doc,prefix,bold,cx,y,fs){
  doc.setFontSize(fs);
  doc.setFont('courier','normal');const pw=doc.getTextWidth(prefix);
  doc.setFont('courier','bold');const bw=doc.getTextWidth(bold);
  let tx=cx-(pw+bw)/2;if(tx<0.5)tx=0.5;
  doc.setFont('courier','normal');if(prefix)doc.text(prefix,tx,y);
  doc.setFont('courier','bold');if(bold)doc.text(bold,tx+pw,y);
}
// Vector mm/inch + vernier rulers for the PDF, drawn in a reserved gutter so
// they never overlay the codes. Band 13 mm, with a 3 mm gap to content.
const RBAND=13, RGAP=3;
function pdfHRuler(doc,x0,yTop,lenMm){
  doc.setDrawColor(17);doc.setTextColor(17);
  for(let i=0,n=Math.floor(lenMm);i<=n;i++){const x=x0+i,maj=i%10===0,med=i%5===0,L=maj?3.4:(med?2.1:1.2);
    doc.setLineWidth(maj?0.25:0.1);doc.line(x,yTop,x,yTop+L);
    if(maj&&i){doc.setFontSize(5);doc.text(String(i),x+0.4,yTop+4.4);}}
  doc.setFontSize(5);doc.text('mm',x0+0.3,yTop+3.2);
  const sN=Math.floor(lenMm/25.4*16);
  for(let j=0;j<=sN;j++){const x=x0+(j/16)*25.4,maj=j%16===0,half=j%8===0,q=j%4===0,L=maj?3.4:(half?2.4:(q?1.7:1));
    doc.setLineWidth(maj?0.25:0.1);doc.line(x,yTop+RBAND-L,x,yTop+RBAND);
    if(maj&&j){doc.setFontSize(5);doc.text((j/16)+'"',x+0.4,yTop+RBAND-1.4);}}
}
function pdfVRuler(doc,xLeft,y0,lenMm){
  doc.setDrawColor(17);doc.setTextColor(17);
  for(let i=0,n=Math.floor(lenMm);i<=n;i++){const y=y0+i,maj=i%10===0,med=i%5===0,L=maj?3.4:(med?2.1:1.2);
    doc.setLineWidth(maj?0.25:0.1);doc.line(xLeft,y,xLeft+L,y);
    if(maj&&i){doc.setFontSize(5);doc.text(String(i),xLeft+0.4,y+1.7);}}
  const sN=Math.floor(lenMm/25.4*16);
  for(let j=0;j<=sN;j++){const y=y0+(j/16)*25.4,maj=j%16===0,half=j%8===0,q=j%4===0,L=maj?3.4:(half?2.4:(q?1.7:1));
    doc.setLineWidth(maj?0.25:0.1);doc.line(xLeft+RBAND-L,y,xLeft+RBAND,y);
    if(maj&&j){doc.setFontSize(5);doc.text((j/16)+'"',xLeft+RBAND-3.6,y+1.7);}}
}
function pdfVernier(doc,x0,y0){
  doc.setDrawColor(17);doc.setTextColor(17);doc.setLineWidth(0.22);doc.line(x0,y0,x0+9,y0);
  for(let k=0;k<=10;k++){doc.setLineWidth(k%5===0?0.25:0.1);doc.line(x0+k*0.9,y0,x0+k*0.9,y0+2.2);}
  doc.setFontSize(4.4);doc.text('vernier 0.1mm',x0,y0+4.4);
}

function downloadPdf(){
  const s=state();
  const J=window.jspdf&&window.jspdf.jsPDF;
  if(!J){$('err').textContent='PDF library still loading — try again.';return;}
  const mmpx=25.4/s.dpi,gutter=RBAND+RGAP;
  try{
    if(isSerial(s)){
      const n=Math.min(s.scount,2000);
      const doc=new J({unit:'mm',format:'a4'});
      const pageW=210,pageH=297,m=8,gap=3;
      const contentW=pageW-m-(m+gutter),contentH=pageH-m-(m+gutter);
      const probe=makeCanvas(s,encode(s,s.sprefix+String(s.sstart).padStart(s.spad,'0')));
      const cellW=probe.width*mmpx;
      const cols=Math.max(1,Math.floor((contentW+gap)/(cellW+gap)));
      let col=0,x=m,y=m,rowH=0;
      for(let i=0;i<n;i++){
        const counter=String(s.sstart+i).padStart(s.spad,'0');
        const cv=makeCanvas(s,encode(s,s.sprefix+counter));
        const wmm=cv.width*mmpx,hmm=cv.height*mmpx;
        if(y+hmm+5>m+contentH){doc.addPage();x=m;y=m;col=0;rowH=0;}
        doc.addImage(cv.toDataURL('image/png'),'PNG',x,y,wmm,hmm);
        pdfCaption(doc,s.sprefix,counter,x+wmm/2,y+hmm+3.5,7);
        rowH=Math.max(rowH,hmm+5);
        col++;if(col>=cols){col=0;x=m;y+=rowH+gap;rowH=0;}else{x+=cellW+gap;}
      }
      // rulers in the reserved bottom + right gutters of every page
      const pages=doc.getNumberOfPages();
      for(let p=1;p<=pages;p++){doc.setPage(p);
        pdfHRuler(doc,m,m+contentH+RGAP,contentW);
        pdfVRuler(doc,m+contentW+RGAP,m,contentH);
        pdfVernier(doc,m+contentW+RGAP,m+contentH+RGAP);
      }
      doc.save('qseq-sheet.pdf');
    }else{
      const cv=makeCanvas(s,encode(s,null));
      const wmm=cv.width*mmpx,hmm=cv.height*mmpx;
      const cap=captionParts(s);const capH=(cap[0]||cap[1])?5:0;
      const cH=hmm+capH;
      const doc=new J({unit:'mm',format:[Math.max(wmm,10)+RGAP+RBAND,cH+RGAP+RBAND]});
      doc.addImage(cv.toDataURL('image/png'),'PNG',0,0,wmm,hmm);
      if(capH)pdfCaption(doc,cap[0],cap[1],wmm/2,hmm+3.5,8);
      pdfHRuler(doc,0,cH+RGAP,wmm);
      pdfVRuler(doc,wmm+RGAP,0,cH);
      pdfVernier(doc,wmm+RGAP,cH+RGAP);
      doc.save('qseq-code.pdf');
    }
  }catch(e){$('err').textContent=String(e);}
}

function downloadSvg(){
  const s=state();
  try{
    const opts={bcid:bcid(s),text:encode(s,isSerial(s)?(s.sprefix+String(s.sstart).padStart(s.spad,'0')):null)};
    if(!is1D(s)&&s.twoD==='qrcode')opts.eclevel=s.ec;
    if(is1D(s)){opts.height=Math.max(6,s.barh);opts.includetext=true;}
    const svg=window.bwipjs.toSVG(opts);
    const blob=new Blob([svg],{type:'image/svg+xml'});const a=document.createElement('a');
    a.download='qseq-code.svg';a.href=URL.createObjectURL(blob);a.click();
  }catch(e){$('err').textContent=String(e);}
}

// Canonical (desktop QSeq) <-> web form value maps, so .qseq files interchange.
const MODE_TO={'2d':'twoD','2dSerial':'twoDSerial','1d':'oneD','1dSerial':'oneDSerial'};
const MODE_FROM={twoD:'2d',twoDSerial:'2dSerial',oneD:'1d',oneDSerial:'1dSerial',combo:'2d',comboSerial:'2dSerial'};
const ONED_TO={'gs1-128':'gs1_128',code128:'code128',code39:'code39',ean13:'ean13',upca:'upcA'};
const ONED_FROM={gs1_128:'gs1-128',code128:'code128',code39:'code39',ean13:'ean13',upcA:'upca'};
const TWOD_TO={qrcode:'qrCode',datamatrix:'dataMatrix'};
const TWOD_FROM={qrCode:'qrcode',dataMatrix:'datamatrix'};
const EC_TO={L:'low',M:'medium',Q:'quartile',H:'high'};
const EC_FROM={low:'L',medium:'M',quartile:'Q',high:'H'};
const KIND_TO={sgtin:'sgtin',nsn:'nsn',text:'rawText'};
const KIND_FROM={sgtin:'sgtin',nsn:'nsn',rawText:'text'};
const FMT_TO={element:'elementString',dl:'digitalLink',epc:'epcTagUri'};
const FMT_FROM={elementString:'element',digitalLink:'dl',epcTagUri:'epc'};
const pick=(m,v,fb)=>(v!=null&&m[v]!=null)?m[v]:fb;

function downloadProject(){
  const s=state();
  const proj={format:'QSeq Project',version:1,
    workspace:{mode:pick(MODE_TO,s.mode,'twoD'),oneDSymbology:pick(ONED_TO,s.oneD,'gs1_128'),twoDSymbology:pick(TWOD_TO,s.twoD,'qrCode'),errorCorrection:pick(EC_TO,s.ec,'medium')},
    data:{kind:pick(KIND_TO,s.kind,'sgtin'),gtin:s.gtin,serial:s.serial,sgtinFormat:pick(FMT_TO,s.sgtinFormat,'digitalLink'),companyPrefixLength:s.cpl,digitalLinkDomain:s.domain,nsn:s.nsn,rawText:s.text},
    print:{dpi:s.dpi,xDimensionMm:s.xdim,barHeightMm:s.barh},
    logo:{sideMm:s.logo,ecBudget:s.ecbudget/100},
    serialization:{prefix:s.sprefix,start:s.sstart,count:s.scount,padDigits:s.spad}};
  const blob=new Blob([JSON.stringify(proj,null,2)],{type:'application/json'});
  const a=document.createElement('a');a.download='design.qseq';a.href=URL.createObjectURL(blob);a.click();
}

function openProject(){
  const inp=document.createElement('input');
  inp.type='file';inp.accept='.qseq,.json,application/json';
  inp.onchange=()=>{const f=inp.files&&inp.files[0];if(!f)return;
    const r=new FileReader();
    r.onload=()=>{try{applyProject(JSON.parse(r.result));$('err').textContent='';}
      catch(e){$('err').textContent='Could not read project file: '+e;}};
    r.readAsText(f);};
  inp.click();
}

const setv=(id,v)=>{const el=$(id);if(el&&v!=null&&v!=='')el.value=v;};
function applyProject(p){
  const w=p.workspace||{},d=p.data||{},pr=p.print||{},lg=p.logo||{},sr=p.serialization||{};
  setv('mode',pick(MODE_FROM,w.mode,'2d'));
  setv('oneD',pick(ONED_FROM,w.oneDSymbology,'gs1-128'));
  setv('twoD',pick(TWOD_FROM,w.twoDSymbology,'qrcode'));
  setv('ec',pick(EC_FROM,w.errorCorrection,'M'));
  setv('kind',pick(KIND_FROM,d.kind,'sgtin'));
  setv('gtin',d.gtin);setv('serial',d.serial);
  setv('sgtinFormat',pick(FMT_FROM,d.sgtinFormat,'dl'));
  setv('cpl',d.companyPrefixLength);setv('domain',d.digitalLinkDomain);
  setv('nsn',d.nsn);setv('text',d.rawText);
  setv('dpi',pr.dpi);setv('xdim',pr.xDimensionMm);setv('barh',pr.barHeightMm);
  setv('logo',lg.sideMm);
  setv('ecbudget',lg.ecBudget!=null?Math.round(lg.ecBudget*100):(lg.ecBudgetPct!=null?lg.ecBudgetPct:50));
  setv('sprefix',sr.prefix);setv('sstart',sr.start);setv('scount',sr.count);setv('spad',sr.padDigits);
  render();
}

// ---- wire ------------------------------------------------------------------
function init(){
  document.querySelectorAll('input,select').forEach(el=>el.addEventListener('input',render));
  $('dlPng').addEventListener('click',downloadPng);
  $('dlPdf').addEventListener('click',downloadPdf);
  $('dlSvg').addEventListener('click',downloadSvg);
  $('dlProj').addEventListener('click',downloadProject);
  $('openProj').addEventListener('click',openProject);
  $('resolver').addEventListener('change',()=>{const v=$('resolver').value;
    if(v!=='custom')$('domain').value=v;render();});
  const ver=$('ver');if(ver)ver.textContent='v'+APP_VERSION;
  if(window.bwipjs)render();
  else{let t=setInterval(()=>{if(window.bwipjs){clearInterval(t);render();}},120);}
}
document.addEventListener('DOMContentLoaded',init);
