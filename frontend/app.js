const API_BASE = "http://127.0.0.1:8000";
let mode = "login", token = localStorage.getItem("timmy_token"), selected = "balanced";
const $ = id => document.getElementById(id);
document.querySelectorAll(".tab").forEach(b=>b.addEventListener("click",()=>{
  mode=b.dataset.mode;document.querySelectorAll(".tab").forEach(x=>x.classList.toggle("active",x===b));
  $("authSubmit").innerHTML=(mode==="login"?"Sign in":"Create account")+' <span>→</span>';
}));
async function api(path,opts={}) {
  const headers={"Content-Type":"application/json",...(opts.headers||{})};
  if(token) headers.Authorization="Bearer "+token;
  const r=await fetch(API_BASE+path,{...opts,headers});
  const d=await r.json().catch(()=>({detail:"Server response could not be read"}));
  if(!r.ok) throw new Error(d.detail||"Request failed"); return d;
}
function showApp(){ $("authView").hidden=true;$("appView").hidden=false;loadDashboard(); }
function showAuth(){ $("authView").hidden=false;$("appView").hidden=true; }
$("authForm").addEventListener("submit",async e=>{
 e.preventDefault();$("authMsg").textContent="Connecting…";
 try{const d=await api("/api/auth/"+mode,{method:"POST",body:JSON.stringify({email:$("email").value,password:$("password").value})});token=d.access_token;localStorage.setItem("timmy_token",token);showApp();}
 catch(err){$("authMsg").textContent=err.message;}
});
async function loadDashboard(){
 try{const d=await api("/api/dashboard");$("userEmail").textContent=d.email;$("connection").textContent="MT5 NOT CONNECTED";$("connectionNote").textContent=d.message;$("balance").textContent=d.balance??"—";$("equity").textContent=d.equity??"—";$("pnl").textContent=d.daily_pnl??"—";selected=d.strategy;syncStrategy();}
 catch(e){if(e.message.includes("Sign in")||e.message.includes("expired")){logout();}else $("connectionNote").textContent=e.message;}
}
function syncStrategy(){document.querySelectorAll(".strategy").forEach(b=>b.classList.toggle("selected",b.dataset.strategy===selected));}
document.querySelectorAll(".strategy").forEach(b=>b.addEventListener("click",()=>{selected=b.dataset.strategy;syncStrategy();}));
$("saveStrategy").addEventListener("click",async()=>{try{await api("/api/strategy",{method:"PUT",body:JSON.stringify({strategy:selected})});$("strategyMsg").textContent="Strategy preference saved. It will not start trading by itself.";}catch(e){$("strategyMsg").textContent=e.message;}});
function logout(){token=null;localStorage.removeItem("timmy_token");showAuth();}
$("logout").addEventListener("click",logout);
if(token) showApp(); else showAuth();
if("serviceWorker" in navigator) navigator.serviceWorker.register("sw.js").catch(()=>{});
