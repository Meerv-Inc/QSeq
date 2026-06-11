// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See the repository LICENSE.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

/* QSeq Label designer — a sized label that combines a 2D code (carrying the GS1
   Digital Link URL) and a 1D barcode (carrying the GS1 element string / NSN),
   a free-text title, one shared human-readable line, an optional imported
   background image, and a dashed cut-frame. Elements are draggable/resizable on
   a print-true canvas. Loaded after app.js; reuses its encoders, makeCanvas,
   sizing helpers (mm/ppmm/moduleDots), page formats and jsPDF helpers. */
'use strict';

window.LabelEditor=(function(){
  // Persistent layout state (positions, background, selection). Settings that map
  // to form controls (label size, title, toggles, frame, snap) are read from the
  // DOM each render; only positions/background/selection live here.
  let L=null;
  function ensure(){if(!L)L={el:{},bgImage:null,bgURL:null,selected:null,sig:null,_cv2:null,_cv1:null,_t:null};return L;}

  const clamp=(v,lo,hi)=>Math.min(hi,Math.max(lo,v));

  // --- settings (read from the label controls) ---
  function settings(){
    return {
      wMm:clampF('lblW',5,2000,90),
      hMm:clampF('lblH',5,2000,50),
      title:val('lblTitle'),
      on:{twoD:checked('lblTwoD'),oneD:checked('lblOneD'),title:checked('lblTitleOn'),hri:checked('lblHriOn')},
      frameShown:checked('lblFrameShow'),
      framePrinted:checked('lblFramePrint'),
      snap:checked('lblSnap'),
    };
  }

  // --- encoding: 2D = Digital Link URL, 1D = element string / NSN, HRI = the URL ---
  function texts(s,serialOverride){
    const sn=serialOverride!=null?serialOverride:s.serial;
    if(s.kind==='nsn'){const x=nsnDigits(s.nsn);return {twoD:x,oneD:x,hri:nsnFormat(x)};}
    if(s.kind==='text'){const t=serialOverride!=null?(s.text+serialOverride):s.text;return {twoD:t,oneD:t,hri:t};}
    const url=sgtinLink(s.gtin,sn,s.domain);
    const elem=sgtinElement(s.gtin,sn);
    return {twoD:url,oneD:elem,hri:url};
  }
  const firstSerial=s=>s.sprefix+String(s.sstart).padStart(s.spad,'0');

  // Render one code to a canvas. The 1D suppresses its own HRI so the label can
  // show a single shared line instead of duplicating the human-readable text.
  function codeCanvas(s,kind,text){
    const child={...s,mode:kind==='2d'?'2d':'1d'};
    return kind==='1d'?makeCanvas(child,text,{includetext:false}):makeCanvas(child,text);
  }
  const natMm=(cv,dpi)=>({wMm:mm(cv.width/dpi),hMm:mm(cv.height/dpi)});

  // --- default arrangement: title top, 2D left | 1D right, shared HRI bottom ---
  function arrange(s,set,nat){
    ensure();L.el={};
    const W=set.wMm,H=set.hMm,p=Math.min(4,Math.max(1.5,W*0.04));
    const titleFont=clamp(H*0.09,2.2,4.2),hriFont=clamp(H*0.07,1.8,3.2);
    const titleH=set.on.title?titleFont*1.3:0,hriH=set.on.hri?hriFont*1.3*2:0;
    let top=p;
    if(set.on.title){L.el.title={xMm:p,yMm:top,wMm:W-2*p,hMm:titleH,fontMm:titleFont};top+=titleH+p*0.4;}
    const bottom=H-p-(hriH?hriH+p*0.4:0);
    let bandH=Math.max(4,bottom-top);
    let two=set.on.twoD&&nat.nat2?{...nat.nat2}:null;
    let one=set.on.oneD&&nat.nat1?{...nat.nat1}:null;
    const gap=p;
    // fit each code to the band height, then scale both to fit the width
    const fitH=(o)=>{const k=bandH/o.hMm;return {wMm:o.wMm*k,hMm:bandH};};
    let b2=two?fitH(two):{wMm:0,hMm:0},b1=one?fitH(one):{wMm:0,hMm:0};
    const availW=W-2*p;
    let totalW=b2.wMm+b1.wMm+((two&&one)?gap:0);
    if(totalW>availW&&totalW>0){const k=availW/totalW;b2.wMm*=k;b2.hMm*=k;b1.wMm*=k;b1.hMm*=k;}
    const rowH=Math.max(b2.hMm,b1.hMm);
    const rowY=top+(bandH-rowH)/2;
    let x=p+(availW-(b2.wMm+b1.wMm+((two&&one)?gap:0)))/2;
    if(two){L.el.twoD={xMm:x,yMm:rowY+(rowH-b2.hMm)/2,wMm:b2.wMm,hMm:b2.hMm,aspect:two.wMm/two.hMm};x+=b2.wMm+gap;}
    if(one){L.el.oneD={xMm:x,yMm:rowY+(rowH-b1.hMm)/2,wMm:b1.wMm,hMm:b1.hMm,aspect:one.wMm/one.hMm};}
    if(set.on.hri){L.el.hri={xMm:p,yMm:H-p-hriH,wMm:W-2*p,hMm:hriH,fontMm:hriFont};}
  }

  // --- drawing ---
  function wrapCtx(ctx,text,maxW){
    const lines=[];let line='';
    for(const ch of String(text)){const t=line+ch;
      if(ctx.measureText(t).width>maxW&&line){lines.push(line);line=ch;}else line=t;}
    if(line)lines.push(line);return lines.length?lines:[''];
  }
  function drawTextEl(ctx,key,text,ppm){
    const el=L.el[key];if(!el)return;
    const fontPx=Math.max(5,(el.fontMm||3)*ppm);
    ctx.fillStyle='#000';ctx.textBaseline='top';ctx.textAlign='center';
    ctx.font=(key==='title'?'600 ':'')+fontPx+'px '+(key==='hri'?'ui-monospace,monospace':'system-ui,-apple-system,sans-serif');
    const maxW=el.wMm*ppm,lineH=fontPx*1.25,cx=(el.xMm+el.wMm/2)*ppm;
    const lines=wrapCtx(ctx,text,maxW);
    let y=el.yMm*ppm;for(const ln of lines){ctx.fillText(ln,cx,y);y+=lineH;}
    el.hMm=Math.max(el.hMm||0,(lines.length*lineH)/ppm); // keep box tall enough for hit-testing
  }
  function drawCodeEl(ctx,key,cv,ppm){
    const el=L.el[key];if(!el||!cv)return;
    ctx.imageSmoothingEnabled=false;
    ctx.drawImage(cv,el.xMm*ppm,el.yMm*ppm,el.wMm*ppm,el.hMm*ppm);
  }
  function drawHandles(ctx,el,ppm){
    const x=el.xMm*ppm,y=el.yMm*ppm,w=el.wMm*ppm,h=el.hMm*ppm,r=Math.max(4,ppm*1.6);
    ctx.save();ctx.strokeStyle='#2aa6ff';ctx.lineWidth=1.5;ctx.setLineDash([4,3]);
    ctx.strokeRect(x,y,w,h);ctx.setLineDash([]);
    ctx.fillStyle='#2aa6ff';ctx.fillRect(x+w-r,y+h-r,r,r); // bottom-right resize handle
    ctx.restore();
  }
  // Draw the whole label onto ctx at ppm pixels/mm. opts:{forExport,cv2,cv1,texts}
  function drawLabel(ctx,s,set,ppm,opts){
    const W=set.wMm*ppm,H=set.hMm*ppm;
    ctx.save();ctx.clearRect(0,0,W,H);
    if(opts.forExport){ctx.fillStyle='#fff';ctx.fillRect(0,0,W,H);} // flat white under content for PNG/PDF
    if(L.bgImage)ctx.drawImage(L.bgImage,0,0,W,H);
    if(set.on.twoD)drawCodeEl(ctx,'twoD',opts.cv2,ppm);
    if(set.on.oneD)drawCodeEl(ctx,'oneD',opts.cv1,ppm);
    if(set.on.title)drawTextEl(ctx,'title',set.title,ppm);
    if(set.on.hri)drawTextEl(ctx,'hri',opts.texts.hri,ppm);
    const showFrame=opts.forExport?set.framePrinted:set.frameShown;
    if(showFrame){
      ctx.strokeStyle=opts.forExport?'#000':'#39c1ff';
      ctx.lineWidth=Math.max(1,ppm*0.18);
      ctx.setLineDash([ppm*1.6,ppm*1.2]);
      const o=ctx.lineWidth/2;ctx.strokeRect(o,o,W-ctx.lineWidth,H-ctx.lineWidth);
      ctx.setLineDash([]);
    }
    if(!opts.forExport&&L.selected&&L.el[L.selected])drawHandles(ctx,L.el[L.selected],ppm);
    ctx.restore();
  }

  // --- hit-testing & interaction ---
  function hitTest(p,set){
    const order=['hri','title','oneD','twoD'];
    for(const k of order){if(!set.on[k])continue;const el=L.el[k];if(!el)continue;
      if(p.x>=el.xMm&&p.x<=el.xMm+el.wMm&&p.y>=el.yMm&&p.y<=el.yMm+el.hMm)return k;}
    return null;
  }
  function inHandle(p,el,scale){const tol=Math.max(2,12/scale);
    return Math.abs(p.x-(el.xMm+el.wMm))<=tol&&Math.abs(p.y-(el.yMm+el.hMm))<=tol;}
  function snapPos(nx,ny,el,set){
    if(set.snap){nx=Math.round(nx);ny=Math.round(ny);}
    const sn=1.6;
    if(Math.abs(nx)<sn)nx=0;
    if(Math.abs(nx+el.wMm-set.wMm)<sn)nx=set.wMm-el.wMm;
    if(Math.abs(nx+el.wMm/2-set.wMm/2)<sn)nx=set.wMm/2-el.wMm/2;
    if(Math.abs(ny)<sn)ny=0;
    if(Math.abs(ny+el.hMm-set.hMm)<sn)ny=set.hMm-el.hMm;
    nx=clamp(nx,0,Math.max(0,set.wMm-el.wMm));
    ny=clamp(ny,0,Math.max(0,set.hMm-el.hMm));
    return [nx,ny];
  }
  function bindPointer(canvas,s,set,scale){
    let mode=null,key=null,grab=null;
    const toMm=e=>{const r=canvas.getBoundingClientRect();return {x:(e.clientX-r.left)/scale,y:(e.clientY-r.top)/scale};};
    const redraw=()=>{const ctx=canvas.getContext('2d');drawLabel(ctx,s,set,scale,{forExport:false,cv2:L._cv2,cv1:L._cv1,texts:L._t});};
    canvas.addEventListener('pointerdown',e=>{
      const p=toMm(e);key=hitTest(p,set);L.selected=key;
      if(key){const el=L.el[key];
        if(inHandle(p,el,scale))mode='resize';else{mode='move';grab={x:p.x-el.xMm,y:p.y-el.yMm};}
        try{canvas.setPointerCapture(e.pointerId);}catch(_){}}
      redraw();
    });
    canvas.addEventListener('pointermove',e=>{
      if(!mode||!key)return;const p=toMm(e),el=L.el[key];
      if(mode==='move'){const[nx,ny]=snapPos(p.x-grab.x,p.y-grab.y,el,set);el.xMm=nx;el.yMm=ny;}
      else{let nw=Math.max(3,p.x-el.xMm);if(set.snap)nw=Math.round(nw);
        if(el.aspect){el.wMm=Math.min(nw,set.wMm-el.xMm);el.hMm=el.wMm/el.aspect;}
        else{const k=nw/Math.max(1,el.wMm);el.wMm=Math.min(nw,set.wMm-el.xMm);el.fontMm=clamp((el.fontMm||3)*k,1,30);}}
      redraw();
    });
    const end=e=>{mode=null;key=null;try{canvas.releasePointerCapture(e.pointerId);}catch(_){}};
    canvas.addEventListener('pointerup',end);
    canvas.addEventListener('pointercancel',end);
  }

  const fitScale=(stage,set)=>{const availW=Math.max(140,(stage.clientWidth||600)-32),maxH=560;
    return Math.max(1,Math.min(availW/set.wMm,maxH/set.hMm));};

  // --- build code canvases + (re)arrange for the current state ---
  function prepare(s,set,serialOverride){
    let t,cv2=null,cv1=null,nat2=null,nat1=null,errMsg='';
    try{
      t=texts(s,serialOverride);
      if(set.on.twoD){cv2=codeCanvas(s,'2d',t.twoD);nat2=natMm(cv2,s.dpi);}
      if(set.on.oneD){cv1=codeCanvas(s,'1d',t.oneD);nat1=natMm(cv1,s.dpi);}
    }catch(e){errMsg=String(e);t=t||{twoD:'',oneD:'',hri:''};}
    ensure();
    const sig=`${set.wMm}x${set.hMm}|${+set.on.twoD}${+set.on.oneD}${+set.on.title}${+set.on.hri}`;
    const missing=(set.on.twoD&&!L.el.twoD)||(set.on.oneD&&!L.el.oneD)||(set.on.title&&!L.el.title)||(set.on.hri&&!L.el.hri);
    if(sig!==L.sig||missing){arrange(s,set,{nat2,nat1});L.sig=sig;}
    // keep code boxes at the right aspect when the data (and so the natural size) changes
    if(L.el.twoD&&nat2){L.el.twoD.aspect=nat2.wMm/nat2.hMm;L.el.twoD.hMm=L.el.twoD.wMm/L.el.twoD.aspect;}
    if(L.el.oneD&&nat1){L.el.oneD.aspect=nat1.wMm/nat1.hMm;L.el.oneD.hMm=L.el.oneD.wMm/L.el.oneD.aspect;}
    return {t,cv2,cv1,nat2,nat1,errMsg};
  }

  // --- main render (screen) ---
  function render(s){
    const stage=$('stage');if(!stage)return;
    stage.innerHTML='';$('err').textContent='';
    const set=settings();
    if(isSerial(s)){renderSheet(s,set);return;}
    const pr=prepare(s,set,null);
    if(pr.errMsg)$('err').textContent=pr.errMsg;
    L._cv2=pr.cv2;L._cv1=pr.cv1;L._t=pr.t;
    const scale=fitScale(stage,set);
    const canvas=document.createElement('canvas');
    canvas.className='label-canvas';
    canvas.width=Math.round(set.wMm*scale);canvas.height=Math.round(set.hMm*scale);
    canvas.style.touchAction='none';
    drawLabel(canvas.getContext('2d'),s,set,scale,{forExport:false,cv2:pr.cv2,cv1:pr.cv1,texts:pr.t});
    bindPointer(canvas,s,set,scale);
    const card=document.createElement('div');card.className='card label-card';card.appendChild(canvas);
    stage.appendChild(card);
    readout(s,set,pr);
    bgHint(s,set);
    renderLog({...s,mode:'2d',sgtinFormat:s.kind==='sgtin'?'dl':s.sgtinFormat});
  }

  // --- serialized label sheet (tile composed labels) ---
  function composeLabelCanvas(s,set,serial,ppm){
    const t=texts(s,serial);
    let cv2=null,cv1=null;
    if(set.on.twoD)cv2=codeCanvas(s,'2d',t.twoD);
    if(set.on.oneD)cv1=codeCanvas(s,'1d',t.oneD);
    const c=document.createElement('canvas');
    c.width=Math.round(set.wMm*ppm);c.height=Math.round(set.hMm*ppm);
    drawLabel(c.getContext('2d'),s,set,ppm,{forExport:true,cv2,cv1,texts:t});
    return c;
  }
  function sheetGeom(s,set){
    const fmt=pageFmt(s),m=8,gap=3,continuous=fmt.h===Infinity;
    const cellW=set.wMm,cellH=set.hMm,contentW=fmt.w-2*m;
    const cols=Math.max(1,Math.floor((contentW+gap)/(cellW+gap)));
    const n=Math.min(s.scount,2000);
    let rows,perPage,pageCount;
    if(continuous){perPage=Math.max(1,n);rows=Math.ceil(n/cols);pageCount=1;}
    else{const contentH=fmt.h-2*m;rows=Math.max(1,Math.floor((contentH+gap)/(cellH+gap)));perPage=cols*rows;pageCount=Math.max(1,Math.ceil(n/perPage));}
    return {fmt,m,gap,cols,rows,perPage,pageCount,n,continuous,cellW,cellH};
  }
  function renderSheet(s,set){
    const stage=$('stage');
    const pr=prepare(s,set,firstSerial(s)); // fixes positions/sizes from the first serial
    if(pr.errMsg){$('err').textContent=pr.errMsg;}
    const g=sheetGeom(s,set);
    sheetPage=Math.min(Math.max(0,sheetPage),g.pageCount-1);
    lastSheetLayout={fmt:g.fmt,cols:g.cols,perPage:g.perPage,pageCount:g.pageCount,n:g.n,continuous:g.continuous};
    const start=g.continuous?0:sheetPage*g.perPage;
    const itemsOnPage=g.continuous?g.n:Math.min(g.perPage,g.n-start);
    const cap=24,shown=Math.max(1,Math.min(itemsOnPage,cap));
    const availW=Math.max(160,(stage.clientWidth||600)-32);
    const cellScale=Math.max(1,Math.min((availW/g.cols)/set.wMm,3));
    const grid=document.createElement('div');grid.className='label-sheet';
    grid.style.gridTemplateColumns=`repeat(${g.cols}, ${Math.round(set.wMm*cellScale)}px)`;
    for(let i=0;i<shown;i++){
      const serial=s.sprefix+String(s.sstart+start+i).padStart(s.spad,'0');
      grid.appendChild(composeLabelCanvas(s,set,serial,cellScale));
    }
    const card=document.createElement('div');card.className='card';card.appendChild(grid);
    stage.appendChild(card);
    fitCardToStage(card,stage);
    if(shown<itemsOnPage){const note=document.createElement('div');note.className='cap';note.style.color='#888';note.style.marginTop='8px';
      note.textContent=`Showing first ${shown} of ${itemsOnPage} on this page · all ${g.n} export to PDF`;stage.appendChild(note);}
    stage.appendChild(pageControls({continuous:g.continuous,fmtLabel:g.fmt.label,pageCount:g.pageCount,page:sheetPage,total:g.n}));
    readout(s,set,pr);
    bgHint(s,set);
    renderLog({...s,mode:'2dSerial',sgtinFormat:s.kind==='sgtin'?'dl':s.sgtinFormat});
  }

  // --- readout & hints ---
  function effXdim(s,el,nat){return el&&nat?(s.xdim*el.wMm/nat.wMm):null;}
  function readout(s,set,pr){
    const r=$('readout');if(!r)return;
    const wpx=Math.round(set.wMm*ppmm(s.dpi)),hpx=Math.round(set.hMm*ppmm(s.dpi));
    const cells=[];
    cells.push(kv('Label',`${set.wMm} × ${set.hMm} mm · ${(set.wMm/25.4).toFixed(2)} × ${(set.hMm/25.4).toFixed(2)} in`));
    cells.push(kv('At '+s.dpi+' DPI',`${wpx} × ${hpx} px`));
    const x2=effXdim(s,L.el.twoD,pr.nat2),x1=effXdim(s,L.el.oneD,pr.nat1);
    if(set.on.twoD&&x2)cells.push(kv('2D module',`${x2.toFixed(3)} mm${x2<0.25?' ⚠ small':''}`));
    if(set.on.oneD&&x1)cells.push(kv('1D X-dim',`${x1.toFixed(3)} mm${x1<0.19?' ⚠ small':''}`));
    cells.push(`<div class="full">2D → Digital Link URL · 1D → GS1 element string · one shared HRI</div>`);
    r.innerHTML=cells.join('');
  }
  function bgHint(s,set){
    const el=$('lblBgHint');if(!el)return;
    const wpx=Math.round(set.wMm*ppmm(s.dpi)),hpx=Math.round(set.hMm*ppmm(s.dpi));
    el.textContent=L.bgImage
      ?`Background loaded. Paint future backgrounds at ${wpx} × ${hpx} px (${set.wMm}×${set.hMm} mm @ ${s.dpi} DPI).`
      :`Export the template, design your background at ${wpx} × ${hpx} px (${set.wMm}×${set.hMm} mm @ ${s.dpi} DPI), then import it — QSeq overlays the codes on top.`;
  }

  // --- exports ---
  function downloadPng(s){
    s=s||state();const set=settings();
    try{
      if(isSerial(s)){$('err').textContent='Use Download PDF for a serialized label sheet; PNG exports a single label.';}
      const ppm=ppmm(s.dpi),pr=prepare(s,set,isSerial(s)?firstSerial(s):null);
      const c=document.createElement('canvas');c.width=Math.round(set.wMm*ppm);c.height=Math.round(set.hMm*ppm);
      drawLabel(c.getContext('2d'),s,set,ppm,{forExport:true,cv2:pr.cv2,cv1:pr.cv1,texts:pr.t});
      saveCanvas(c,'qseq-label.png');
    }catch(e){$('err').textContent=String(e);}
  }
  function canvasURL(c){return c.toDataURL('image/png');}
  function downloadPdf(s){
    s=s||state();const set=settings();
    const J=window.jspdf&&window.jspdf.jsPDF;
    if(!J){$('err').textContent='PDF library still loading — try again.';return;}
    const ppm=ppmm(s.dpi);
    try{
      if(!isSerial(s)){
        prepare(s,set,null);
        const doc=new J({unit:'mm',format:[set.wMm,set.hMm]});
        const img=composeLabelCanvas(s,set,s.serial,ppm);
        doc.addImage(canvasURL(img),'PNG',0,0,set.wMm,set.hMm);
        doc.save('qseq-label.pdf');
        return;
      }
      prepare(s,set,firstSerial(s));
      const g=sheetGeom(s,set);
      let doc,contentH;
      if(g.continuous){
        const rows=Math.ceil(g.n/g.cols);const pageH=g.m+rows*(g.cellH+g.gap)+g.m;
        doc=new J({unit:'mm',format:[g.fmt.w,pageH]});contentH=pageH-2*g.m;
      }else{doc=new J({unit:'mm',format:[g.fmt.w,g.fmt.h]});contentH=g.fmt.h-2*g.m;}
      let col=0,x=g.m,y=g.m;
      for(let i=0;i<g.n;i++){
        const serial=s.sprefix+String(s.sstart+i).padStart(s.spad,'0');
        if(!g.continuous&&y+g.cellH>g.m+contentH){doc.addPage([g.fmt.w,g.fmt.h]);x=g.m;y=g.m;col=0;}
        const img=composeLabelCanvas(s,set,serial,ppm);
        doc.addImage(canvasURL(img),'PNG',x,y,g.cellW,g.cellH);
        col++;if(col>=g.cols){col=0;x=g.m;y+=g.cellH+g.gap;}else{x+=g.cellW+g.gap;}
      }
      doc.save('qseq-label-sheet.pdf');
    }catch(e){$('err').textContent=String(e);}
  }

  // --- label template (empty frame + keep-out outlines, at exact px) ---
  function exportTemplate(){
    const s=state(),set=settings(),ppm=ppmm(s.dpi);
    prepare(s,set,isSerial(s)?firstSerial(s):null); // ensures element boxes exist
    const c=document.createElement('canvas');c.width=Math.round(set.wMm*ppm);c.height=Math.round(set.hMm*ppm);
    const ctx=c.getContext('2d');
    // transparent background so the designer fills it; mark the frame + keep-outs
    ctx.strokeStyle='#000';ctx.lineWidth=Math.max(1,ppm*0.18);ctx.setLineDash([ppm*1.6,ppm*1.2]);
    const o=ctx.lineWidth/2;ctx.strokeRect(o,o,c.width-ctx.lineWidth,c.height-ctx.lineWidth);
    ctx.setLineDash([ppm*1.0,ppm*0.8]);ctx.strokeStyle='rgba(0,0,0,.55)';ctx.fillStyle='rgba(0,0,0,.06)';
    ['twoD','oneD','title','hri'].forEach(k=>{if(!set.on[k])return;const el=L.el[k];if(!el)return;
      ctx.fillRect(el.xMm*ppm,el.yMm*ppm,el.wMm*ppm,el.hMm*ppm);
      ctx.strokeRect(el.xMm*ppm,el.yMm*ppm,el.wMm*ppm,el.hMm*ppm);});
    ctx.setLineDash([]);
    saveCanvas(c,'qseq-label-template.png');
  }

  // --- background image import (reuses the openLogo pattern) ---
  function importBg(){
    const inp=document.createElement('input');inp.type='file';inp.accept='image/png,image/jpeg,image/svg+xml,image/*';
    inp.onchange=()=>{const f=inp.files&&inp.files[0];if(!f)return;const r=new FileReader();
      r.onload=()=>{const img=new Image();img.onload=()=>{ensure();L.bgImage=img;L.bgURL=r.result;$('err').textContent='';render(state());};
        img.onerror=()=>{$('err').textContent='Could not load that background image.';};img.src=r.result;};
      r.readAsDataURL(f);};
    inp.click();
  }
  function clearBg(){ensure();L.bgImage=null;L.bgURL=null;render(state());}

  // --- project I/O (web-only label block) ---
  function toJSON(s){const set=settings();ensure();
    return {webMode:s.mode,wMm:set.wMm,hMm:set.hMm,title:set.title,on:set.on,
      frameShown:set.frameShown,framePrinted:set.framePrinted,snap:set.snap,el:L.el};}
  function fromJSON(j){
    const setV=(id,v)=>{const e=$(id);if(e&&v!=null)e.value=v;};
    const setC=(id,v)=>{const e=$(id);if(e)e.checked=!!v;};
    if(j.webMode)setV('mode',j.webMode);
    setV('lblW',j.wMm);setV('lblH',j.hMm);setV('lblTitle',j.title);
    if(j.on){setC('lblTwoD',j.on.twoD);setC('lblOneD',j.on.oneD);setC('lblTitleOn',j.on.title);setC('lblHriOn',j.on.hri);}
    if(j.frameShown!=null)setC('lblFrameShow',j.frameShown);setC('lblFramePrint',j.framePrinted);
    if(j.snap!=null)setC('lblSnap',j.snap);
    ensure();L.el=j.el||{};
    L.sig=j.el?`${j.wMm}x${j.hMm}|${+(!!(j.on&&j.on.twoD))}${+(!!(j.on&&j.on.oneD))}${+(!!(j.on&&j.on.title))}${+(!!(j.on&&j.on.hri))}`:null;
  }

  // --- wire the label-only controls ---
  const PRESETS={'90x50':[90,50],'100x50':[100,50],'100x70':[100,70],'76x51':[76,51],'50x25':[50,25]};
  function wire(){
    const on=(id,fn)=>{const e=$(id);if(e)e.addEventListener('click',fn);};
    on('lblArrange',()=>{ensure();L.sig=null;render(state());});
    on('lblTemplate',exportTemplate);
    on('lblBgOpen',importBg);
    on('lblBgClear',clearBg);
    const pre=$('lblPreset');
    if(pre)pre.addEventListener('input',()=>{const v=pre.value;if(PRESETS[v]){setvNum('lblW',PRESETS[v][0]);setvNum('lblH',PRESETS[v][1]);}ensure();L.sig=null;render(state());});
  }
  function setvNum(id,v){const e=$(id);if(e)e.value=v;}
  document.addEventListener('DOMContentLoaded',wire);

  return {render,downloadPng,downloadPdf,exportTemplate,importBg,clearBg,toJSON,fromJSON};
})();
