// DOM interaction tests use explicit fixtures only; production has no demo-data path.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {JSDOM}=require('jsdom');
const root=path.join(__dirname,'..');
const source=fs.readFileSync(path.join(root,'panel/static/app.js'),'utf8');
const html=fs.readFileSync(path.join(root,'panel/static/index.html'),'utf8');
const pause=()=>new Promise(r=>setTimeout(r,25));
function harness({permissions=['dashboard','clients.read','clients.write','clients.export','admins','settings','audit'],offline=false}={}){
 const dom=new JSDOM(html,{url:'https://panel.example.test',runScripts:'outside-only'});
 const w=dom.window,calls=[];
 w.HTMLDialogElement.prototype.showModal=function(){this.setAttribute('open','');};
 w.HTMLDialogElement.prototype.close=function(){this.removeAttribute('open');this.dispatchEvent(new w.Event('close'));};
 const clients=[{name:'alice',label:'Alice fixture',state:'active',effective_state:'active',quota_bytes:1073741824,expires_at:null,upload:100,download:200,note:'',created_at:1700000000,connections:[]}];
 let signedIn=true;
 w.fetch=async(url,options={})=>{
  const method=options.method||'GET',body=options.body?JSON.parse(options.body):null;
  calls.push({url,method,body});
  let status=200,data={ok:true};
  if(url==='/api/me') data=signedIn?{username:'owner',owner:1,csrf:'test-csrf',permissions,preferences:{panel_name:'Test panel'}}:{detail:'Sign in'};
  if(url==='/api/me'&&!signedIn)status=401;
  if(url==='/api/logout')signedIn=false;
  if(url==='/api/dashboard')data={totals:{clients:1,active:1,blocked:0,upload:100,download:200},online:0,healthy:true,server:'test-server',uptime:86400,history:[]};
  if(url==='/api/clients'&&method==='GET')data=clients;
  if(url==='/api/audit')data=[{id:1,at:1700000000,actor:'owner',action:'login',target:'',result:'ok'}];
  if(url==='/api/admins')data=[{username:'owner',owner:1,enabled:1,permissions:[]}];
  if(url==='/api/settings')data={panel_name:'Test panel',default_quota_gb:50,default_days:30,public_url:'https://panel.example.test',openvpn:{proto:'udp',port:'1194',server:'10.8.0.0 255.255.255.0'}};
  if(offline&&['/api/dashboard','/api/clients'].includes(url)){status=503;data={detail:'Agent unavailable'};}
  return {ok:status===200,status,json:async()=>data,text:async()=>String(data)};
 };
 w.eval(source);
 const click=selector=>{const el=w.document.querySelector(selector);assert.ok(el,`Missing ${selector}`);el.click();};
 return {w,calls,click,close:()=>w.close()};
}

test('bilingual navigation, creation form and correct byte/time payload',async()=>{
 const h=harness();try{await pause();
 assert.equal(h.w.document.documentElement.dir,'rtl');
 assert.ok(h.w.document.querySelector('.stats'));
 h.click('[data-page="clients"]');await pause();
 assert.match(h.w.document.querySelector('#client-table').textContent,/Alice fixture/);
 h.click('[data-action="new-client"]');await pause();
 const form=h.w.document.querySelector('#client-form');assert.ok(form);
 form.elements.namedItem('name').value='test_client';
 form.elements.namedItem('quota').value='2';
 form.elements.namedItem('days').value='3';
 form.dispatchEvent(new h.w.Event('submit',{bubbles:true,cancelable:true}));await pause();
 const call=h.calls.find(c=>c.url==='/api/clients'&&c.method==='POST');
 assert.equal(call.body.quota_bytes,2*1024**3);
 assert.ok(Math.abs(call.body.expires_at-(Date.now()/1000+3*86400))<3);
 h.click('[data-action="language"]');await pause();
 assert.equal(h.w.document.documentElement.dir,'ltr');
 assert.match(h.w.document.querySelector('h1').textContent,/Clients/);
 }finally{h.close();}
});

test('view-only permissions hide write controls and admin navigation',async()=>{
 const h=harness({permissions:['dashboard','clients.read']});try{await pause();
 assert.equal(h.w.document.querySelector('[data-page="admins"]'),null);
 assert.equal(h.w.document.querySelector('[data-action="new-client"]'),null);
 h.click('[data-page="clients"]');await pause();
 assert.equal(h.w.document.querySelector('[data-action="edit-client"]'),null);
 assert.equal(h.w.document.querySelector('[data-action="profile"]'),null);
 }finally{h.close();}
});

test('server outage shows explicit unavailable state instead of fabricated cards',async()=>{
 const h=harness({offline:true});try{await pause();
 assert.ok(h.w.document.querySelector('.banner.error'));
 assert.equal(h.w.document.querySelector('.stats'),null);
 }finally{h.close();}
});

test('search, administrator form, settings and logout are interactive',async()=>{
 const h=harness();try{await pause();h.click('[data-page="clients"]');await pause();
 const search=h.w.document.querySelector('#client-search');search.value='no-match';search.dispatchEvent(new h.w.Event('input',{bubbles:true}));
 assert.equal(h.w.document.querySelector('#client-table tbody'),null);
 h.click('[data-page="admins"]');await pause();h.click('[data-action="new-admin"]');
 assert.equal(h.w.document.querySelectorAll('input[name=permission]').length,6);
 h.click('[data-action="close"]');h.click('[data-page="settings"]');await pause();
 const form=h.w.document.querySelector('#settings-form');assert.ok(form);
 form.elements.namedItem('panel_name').value='Renamed';form.dispatchEvent(new h.w.Event('submit',{bubbles:true,cancelable:true}));await pause();
 assert.equal(h.calls.find(c=>c.url==='/api/settings'&&c.method==='PUT').body.panel_name,'Renamed');
 h.click('[data-action="logout"]');await pause();assert.ok(h.w.document.querySelector('#login-form'));
 }finally{h.close();}
});
