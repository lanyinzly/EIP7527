/* Shared logic for both language versions.
   Each page defines window.I18N with chart/simulator strings before loading this. */
import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@10.9.1/dist/mermaid.esm.min.mjs";

const T = window.I18N;

/* ---------- mermaid (rendered inside the dark band) ---------- */
mermaid.initialize({
  startOnLoad: false,
  theme: "base",
  themeVariables: {
    darkMode: true,
    background: "#121613",
    primaryColor: "#1a221c",
    primaryBorderColor: "#2bee4b",
    primaryTextColor: "#e9f2ea",
    secondaryColor: "#1f2a21",
    tertiaryColor: "#161c17",
    lineColor: "#91a194",
    textColor: "#c8d2c8",
    clusterBkg: "#161c17",
    clusterBorder: "#2e362f",
    titleColor: "#e9f2ea",
    edgeLabelBackground: "#121613",
    noteBkgColor: "#1f2a21",
    noteTextColor: "#c8d2c8",
    noteBorderColor: "#2e362f",
    actorBkg: "#1a221c",
    actorBorder: "#2bee4b",
    actorTextColor: "#e9f2ea",
    signalColor: "#c8d2c8",
    signalTextColor: "#c8d2c8",
    labelBoxBkgColor: "#1a221c",
    labelBoxBorderColor: "#2e362f",
    labelTextColor: "#e9f2ea",
    loopTextColor: "#c8d2c8",
    activationBkgColor: "#1f2a21",
    activationBorderColor: "#2bee4b",
    sequenceNumberColor: "#121613",
    fontFamily: "Noto Sans SC, sans-serif",
    fontSize: "14px",
  },
  flowchart: { curve: "basis" },
  sequence: { actorMargin: 60 },
});

/* Render, then lift subgraph titles above edge paths (mermaid draws edges
   over cluster labels, so arrows entering a subgraph can cross its title). */
await mermaid.run({ querySelector: ".mermaid" });
document.querySelectorAll(".mermaid svg").forEach(svg => {
  const root = svg.querySelector("g");
  if (!root) return;
  svg.querySelectorAll("g.cluster-label").forEach(lbl => root.appendChild(lbl));
});

/* ---------- charts ---------- */
const gridColor = "rgba(18,22,19,0.08)";
Chart.defaults.font.family = "'Space Mono', 'Noto Sans SC', sans-serif";
Chart.defaults.font.size = 11;
Chart.defaults.color = "#516254";

// Linear bonding curve f(x) = 0.1 * (1 + x/100)
const xs = Array.from({ length: 101 }, (_, i) => i);
new Chart(document.getElementById("linearChart"), {
  type: "line",
  data: {
    labels: xs,
    datasets: [{
      label: T.charts.linear,
      data: xs.map(x => 0.1 * (1 + x / 100)),
      borderColor: "#121613",
      backgroundColor: "rgba(43,238,75,0.18)",
      fill: true, pointRadius: 0, borderWidth: 2, tension: 0,
    }],
  },
  options: {
    responsive: true, maintainAspectRatio: false,
    plugins: { legend: { display: false } },
    scales: {
      x: { title: { display: true, text: T.charts.xSupply }, grid: { color: gridColor }, ticks: { maxTicksLimit: 11 } },
      y: { title: { display: true, text: T.charts.yPrice }, grid: { color: gridColor } },
    },
  },
});

// Auction premium multiple (approximation): minutes since last trade → multiplier
function auctionMultiplier(tMin) {
  const tSec = tMin * 60;
  if (tSec <= 0) return 1.03;                       // same block/second: +3%
  const boundary = 1080;                            // step1: ~18 min
  if (tSec < boundary) {                            // rational interpolation: ~1.01 → ~1.03
    const x = tSec / boundary;
    return 1.0101 + (1.0299 - 1.0101) * (1 - Math.pow(1 - x, 1.6));
  }
  const m = 1.03 * Math.exp(-0.002463 * (tSec / 270 - 4));  // exponential decay
  return Math.max(m, 1.0);                          // floor: never below last traded price
}
const ts = Array.from({ length: 121 }, (_, i) => i);
new Chart(document.getElementById("auctionChart"), {
  type: "line",
  data: {
    labels: ts,
    datasets: [{
      label: T.charts.auctionMain,
      data: ts.map(auctionMultiplier),
      borderColor: "#121613",
      backgroundColor: "rgba(18,22,19,0.05)",
      fill: true, pointRadius: 0, borderWidth: 2, tension: 0.25,
    }, {
      label: T.charts.auctionFloor,
      data: ts.map(() => 1.0),
      borderColor: "#18a23a",
      borderDash: [6, 6], pointRadius: 0, borderWidth: 1.5,
    }],
  },
  options: {
    responsive: true, maintainAspectRatio: false,
    plugins: { legend: { labels: { boxWidth: 14 } } },
    scales: {
      x: { title: { display: true, text: T.charts.xMinutes }, grid: { color: gridColor }, ticks: { maxTicksLimit: 13 } },
      y: { title: { display: true, text: T.charts.yPremium }, min: 0.99, max: 1.035, grid: { color: gridColor } },
    },
  },
});

/* ---------- LIFO price stack simulator ---------- */
const BASE = 0.1;
let stack, balance;
const $ = id => document.getElementById(id);
const fmt = (tpl, vars) => tpl.replace(/\{(\w+)\}/g, (_, k) => vars[k]);

function reset() { stack = [BASE]; balance = 0; render(); }

function render() {
  const viz = $("stackViz");
  viz.innerHTML = "";
  const baseEl = document.createElement("div");
  baseEl.className = "stack-item base";
  baseEl.textContent = fmt(T.sim.base, { p: BASE.toFixed(3) });
  viz.appendChild(baseEl);
  stack.slice(1).forEach((p, i) => {
    const el = document.createElement("div");
    el.className = "stack-item";
    el.style.width = `${Math.min(100, 30 + (p / BASE - 1) * 600)}%`;
    el.textContent = fmt(T.sim.item, { i: i + 1, p: p.toFixed(4) });
    viz.appendChild(el);
  });
  const supply = stack.length - 1;
  $("statSupply").textContent = supply;
  $("statBalance").textContent = `${balance.toFixed(4)} ETH`;
  $("statNext").textContent = `${(stack[stack.length - 1] * 1.03).toFixed(4)} ETH`;
  $("statRedeem").textContent = supply > 0 ? `${stack[stack.length - 1].toFixed(4)} ETH` : "—";
  const sum = stack.slice(1).reduce((a, b) => a + b, 0);
  $("statSolvent").textContent = Math.abs(sum - balance) < 1e-9 ? T.sim.ok : T.sim.bad;
  $("btnUnwrap").disabled = supply === 0;
}

$("btnWrap").addEventListener("click", () => {
  const price = stack[stack.length - 1] * 1.03;   // simplified: +3% per trade
  stack.push(price);
  balance += price;
  render();
});
$("btnUnwrap").addEventListener("click", () => {
  if (stack.length <= 1) return;
  balance -= stack.pop();                          // redeem at top of stack
  render();
});
$("btnReset").addEventListener("click", reset);
reset();
