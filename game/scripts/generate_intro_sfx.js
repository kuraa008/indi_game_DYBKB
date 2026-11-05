#!/usr/bin/env node
'use strict';
// ══════════════════════════════════════════════════════════════════════════════
//  generate_intro_sfx.js — звуки вступления (scripts/IntroCutscene.gd)
//  Запуск:  node game/scripts/generate_intro_sfx.js [имя ...]
//  Пишет game/assets/audio/intro/*.wav (44.1 кГц, 16 бит). Всё собрано из шума,
//  генераторов, фильтров и затухающих резонаторов; у каждого звука свой seed,
//  поэтому файлы воспроизводимы. Петли записываются с блоком smpl — Godot
//  сам включает повтор при импорте («Detect From WAV»).
// ══════════════════════════════════════════════════════════════════════════════

const fs = require('fs');
const path = require('path');

const SR = 44100;
const TAU = Math.PI * 2;
const OUT_DIR = path.join(__dirname, '..', 'assets', 'audio', 'intro');

// ───────── случайные числа (mulberry32) ─────────
let _s = 1;
function seed(n) { _s = (n >>> 0) || 1; }
function R() {
  _s = (_s + 0x6D2B79F5) >>> 0;
  let t = _s;
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}
const rnd = (a = 0, b = 1) => a + (b - a) * R();
const logU = (a, b) => a * Math.pow(b / a, R());
const expR = mean => -Math.log(1 - R() * 0.999999) * mean;
const pick = a => a[Math.floor(R() * a.length)];

// ───────── буферы и огибающие ─────────
const N = s => Math.max(0, Math.round(s * SR));
const buf = s => new Float32Array(N(s));
const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
const lerp = (a, b, t) => a + (b - a) * t;
const sstep = (a, b, v) => { const t = clamp((v - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };

function add(dst, src, at = 0, g = 1) {
  const o = N(at);
  for (let i = 0; i < src.length; i++) {
    const j = o + i;
    if (j >= 0 && j < dst.length) dst[j] += src[i] * g;
  }
  return dst;
}
function env(x, f) { for (let i = 0; i < x.length; i++) x[i] *= f(i / SR); return x; }
function gain(x, g) { for (let i = 0; i < x.length; i++) x[i] *= g; return x; }
function mix(...parts) {
  const len = Math.max(...parts.map(p => p[0].length));
  const y = new Float32Array(len);
  for (const [a, g] of parts) for (let i = 0; i < a.length; i++) y[i] += a[i] * g;
  return y;
}
function peakOf(chs) { let m = 1e-9; for (const x of chs) for (let i = 0; i < x.length; i++) m = Math.max(m, Math.abs(x[i])); return m; }
function norm(chs, db) { const g = Math.pow(10, db / 20) / peakOf(chs); for (const x of chs) gain(x, g); return chs; }
function normRms(x) { let s = 0; for (let i = 0; i < x.length; i++) s += x[i] * x[i]; return gain(x, 1 / Math.sqrt(s / x.length + 1e-12)); }
function sat(x, drive) { const k = Math.tanh(drive); for (let i = 0; i < x.length; i++) x[i] = Math.tanh(x[i] * drive) / k; return x; }
// Сглаживание вперёд-назад: формантные дорожки без запаздывания
function smooth2(x, tau) {
  const a = Math.exp(-1 / (tau * SR));
  let y = x[0];
  for (let i = 0; i < x.length; i++) { y = a * y + (1 - a) * x[i]; x[i] = y; }
  y = x[x.length - 1];
  for (let i = x.length - 1; i >= 0; i--) { y = a * y + (1 - a) * x[i]; x[i] = y; }
  return x;
}

// ───────── шумы ─────────
function white(len) { const x = new Float32Array(len); for (let i = 0; i < len; i++) x[i] = R() * 2 - 1; return x; }
function pink(len) {
  const x = new Float32Array(len);
  let b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0;
  for (let i = 0; i < len; i++) {
    const w = R() * 2 - 1;
    b0 = 0.99886 * b0 + w * 0.0555179; b1 = 0.99332 * b1 + w * 0.0750759; b2 = 0.969 * b2 + w * 0.153852;
    b3 = 0.8665 * b3 + w * 0.3104856; b4 = 0.55 * b4 + w * 0.5329522; b5 = -0.7616 * b5 - w * 0.016898;
    x[i] = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362) * 0.11;
    b6 = w * 0.115926;
  }
  return x;
}
function brown(len) { const x = new Float32Array(len); let v = 0; for (let i = 0; i < len; i++) { v = v * 0.996 + (R() * 2 - 1) * 0.06; x[i] = v; } return x; }
// Плавный случайный сигнал −1…1 (дрожание высоты, «дребезг»)
function wobble(len, hz) {
  const w = white(len); lp1(w, hz); lp1(w, hz);
  let s = 0; for (let i = 0; i < len; i++) s += w[i] * w[i];
  const g = 1 / (Math.sqrt(s / len) * 2.5 + 1e-12);
  for (let i = 0; i < len; i++) w[i] = clamp(w[i] * g, -1, 1);
  return w;
}

// ───────── фильтры (RBJ biquad) ─────────
function coef(type, f, q, db) {
  f = clamp(f, 10, SR * 0.49);
  const w = TAU * f / SR, c = Math.cos(w), s = Math.sin(w), al = s / (2 * q);
  let b0, b1, b2, a0, a1, a2;
  if (type === 'lp') { b0 = (1 - c) / 2; b1 = 1 - c; b2 = b0; a0 = 1 + al; a1 = -2 * c; a2 = 1 - al; }
  else if (type === 'hp') { b0 = (1 + c) / 2; b1 = -(1 + c); b2 = b0; a0 = 1 + al; a1 = -2 * c; a2 = 1 - al; }
  else if (type === 'bp') { b0 = al; b1 = 0; b2 = -al; a0 = 1 + al; a1 = -2 * c; a2 = 1 - al; }
  else { const A = Math.pow(10, db / 40); b0 = 1 + al * A; b1 = -2 * c; b2 = 1 - al * A; a0 = 1 + al / A; a1 = -2 * c; a2 = 1 - al / A; }
  return [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0];
}
function bq(x, type, f, q = 0.707, db = 0) {
  const [b0, b1, b2, a1, a2] = coef(type, f, q, db);
  let z1 = 0, z2 = 0;
  for (let i = 0; i < x.length; i++) { const v = x[i], y = b0 * v + z1; z1 = b1 * v - a1 * y + z2; z2 = b2 * v - a2 * y; x[i] = y; }
  return x;
}
// Фильтр с меняющейся частотой: fFn/qFn — функции времени
function bqv(x, type, fFn, qFn, db = 0) {
  let c = null, z1 = 0, z2 = 0;
  for (let i = 0; i < x.length; i++) {
    if ((i & 15) === 0) { const t = i / SR; c = coef(type, fFn(t), typeof qFn === 'function' ? qFn(t) : qFn, db); }
    const v = x[i], y = c[0] * v + z1; z1 = c[1] * v - c[3] * y + z2; z2 = c[2] * v - c[4] * y; x[i] = y;
  }
  return x;
}
function lp1(x, f) { const a = Math.exp(-TAU * f / SR); let y = 0; for (let i = 0; i < x.length; i++) { y = (1 - a) * x[i] + a * y; x[i] = y; } return x; }
function hp1(x, f) { const a = Math.exp(-TAU * f / SR); let y = 0, px = 0; for (let i = 0; i < x.length; i++) { y = a * (y + x[i] - px); px = x[i]; x[i] = y; } return x; }

// ───────── резонаторы и события ─────────
// Затухающая синусоида: «звон» металла, стекла, дерева (вращение комплексного числа)
function ring(dst, at, f, tau, amp, ph = rnd(0, TAU)) {
  if (f >= SR * 0.45 || amp === 0) return;
  const o = N(at), w = TAU * f / SR, r = Math.exp(-1 / (tau * SR)), c = Math.cos(w), s = Math.sin(w);
  let re = Math.cos(ph) * amp, im = Math.sin(ph) * amp;
  const len = Math.min(dst.length - o, Math.ceil(tau * SR * 7));
  for (let i = 0; i < len; i++) {
    const j = o + i;
    if (j >= 0) dst[j] += im;
    const nr = (re * c - im * s) * r; im = (re * s + im * c) * r; re = nr;
  }
}
function modes(dst, at, amp, list, spread = 0.02) { for (const [f, tau, g] of list) ring(dst, at, f * rnd(1 - spread, 1 + spread), tau, amp * g); }
function burst(dst, at, dur, amp, type = null, f = 2000, q = 0.7, tau = dur / 3) {
  const x = white(N(dur));
  env(x, t => (1 - Math.exp(-t / 0.0004)) * Math.exp(-t / tau));
  if (type) bq(x, type, f, q);
  add(dst, x, at, amp);
}
function click(dst, at, amp, f = 3000) { burst(dst, at, 0.003, amp, 'hp', f, 0.7, 0.0008); }
// Генератор с меняющейся частотой и набором гармоник
function osc(dst, at, dur, fFn, aFn, harm = [1]) {
  const o = N(at), n = N(dur);
  let ph = rnd(0, TAU);
  for (let i = 0; i < n; i++) {
    const t = i / SR, f = fFn(t);
    ph += TAU * f / SR;
    if (ph > 1e4) ph -= TAU * Math.floor(1e4 / TAU);
    let v = 0;
    for (let k = 0; k < harm.length; k++) if (harm[k] && f * (k + 1) < SR * 0.45) v += harm[k] * Math.sin(ph * (k + 1));
    const j = o + i;
    if (j < dst.length) dst[j] += v * aFn(t);
  }
}
// Россыпь крошечных резонансов: гравий, хвоя, стеклянная крошка
function particles(dst, t0, t1, rateFn, fLo, fHi, tauLo, tauHi, ampFn) {
  let t = t0;
  for (;;) {
    t += expR(1 / Math.max(1, rateFn(t - t0)));
    if (t >= t1) break;
    ring(dst, t, logU(fLo, fHi), rnd(tauLo, tauHi), ampFn(t - t0) * expR(0.5));
  }
}
// Скрип «прилипание-срыв»: серия импульсов возбуждает резонаторы (двери, ворота, сухожилия)
function creak(dst, at, dur, rateFn, res, amp, jit = 0.25, ampFn = () => 1) {
  let t = 0;
  for (;;) {
    t += (1 / Math.max(2, rateFn(t / dur))) * (1 + rnd(-jit, jit));
    if (t >= dur) break;
    const a = amp * rnd(0.55, 1) * ampFn(t / dur);
    for (const [f, tau, g] of res) ring(dst, at + t, f * rnd(0.985, 1.015), tau, a * g);
  }
}

// ───────── пространство ─────────
function freeverb(x, { room = 0.8, damp = 0.5, wet = 0.3, dry = 1, pre = 0.02 } = {}) {
  const combs = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617].map(l => ({ b: new Float32Array(l), i: 0, f: 0 }));
  const aps = [556, 441, 341, 225].map(l => ({ b: new Float32Array(l), i: 0 }));
  const fb = room * 0.28 + 0.7, d1 = damp * 0.4, pd = N(pre);
  const y = new Float32Array(x.length);
  for (let n = 0; n < x.length; n++) {
    const inp = (n >= pd ? x[n - pd] : 0) * 0.015;
    let out = 0;
    for (const c of combs) { const o = c.b[c.i]; c.f = o * (1 - d1) + c.f * d1; c.b[c.i] = inp + c.f * fb; if (++c.i >= c.b.length) c.i = 0; out += o; }
    for (const a of aps) { const bo = a.b[a.i]; const o2 = -out + bo; a.b[a.i] = out + bo * 0.5; if (++a.i >= a.b.length) a.i = 0; out = o2; }
    y[n] = x[n] * dry + out * wet * 3;
  }
  return y;
}
// Плавающая задержка: детонация и «плавание» плёнки
function wowDelay(x, baseMs, depthMs, rate, flutterMs, flutterHz) {
  const y = new Float32Array(x.length);
  for (let n = 0; n < x.length; n++) {
    const t = n / SR;
    const d = (baseMs + depthMs * Math.sin(TAU * rate * t) + flutterMs * Math.sin(TAU * flutterHz * t)) * SR / 1000;
    const p = n - d, i0 = Math.floor(p), fr = p - i0;
    y[n] = (i0 >= 0 && i0 + 1 < x.length) ? x[i0] * (1 - fr) + x[i0 + 1] * fr : 0;
  }
  return y;
}
// Бесшовная петля: хвост длиной X плавно перетекает в начало
function loopXf(x, L, X) {
  const n = N(L), m = N(X), y = new Float32Array(n);
  for (let i = 0; i < n; i++) y[i] = x[i];
  for (let i = 0; i < m; i++) { const u = i / m; y[i] = x[i] * Math.sin(u * Math.PI / 2) + x[n + i] * Math.cos(u * Math.PI / 2); }
  return y;
}

// ───────── голос: формантный синтез (шёпот и крик) ─────────
const VOW = {
  a: [760, 1260, 2550], o: [520, 900, 2450], u: [340, 790, 2300], i: [300, 2250, 2950],
  y: [380, 1550, 2450], e: [480, 1880, 2600], E: [560, 1720, 2520], '@': [520, 1350, 2450],
};
const CONS = {
  t: { k: 'stop', band: ['hp', 3800, 0.8], burst: 0.9 }, d: { k: 'stop', band: ['hp', 3500, 0.8], burst: 0.5 },
  k: { k: 'stop', band: ['bp', 1900, 1.8], burst: 0.8 }, g: { k: 'stop', band: ['bp', 1800, 1.8], burst: 0.45 },
  p: { k: 'stop', band: ['bp', 900, 0.7], burst: 0.6 }, b: { k: 'stop', band: ['bp', 800, 0.7], burst: 0.35 },
  s: { k: 'fric', band: ['bp', 6500, 1.2], amp: 0.55 }, z: { k: 'fric', band: ['bp', 6000, 1.2], amp: 0.4, voiced: true },
  sh: { k: 'fric', band: ['bp', 3200, 1.0], amp: 0.6 }, zh: { k: 'fric', band: ['bp', 3000, 1.0], amp: 0.45, voiced: true },
  f: { k: 'fric', band: ['bp', 4500, 0.4], amp: 0.2 }, v: { k: 'fric', band: ['bp', 4000, 0.4], amp: 0.15, voiced: true },
  h: { k: 'fric', band: ['bp', 1800, 0.8], amp: 0.35 },
  n: { k: 'son', F: [260, 1150, 2300], amp: 0.28 }, m: { k: 'son', F: [250, 1000, 2200], amp: 0.25 },
  l: { k: 'son', F: [360, 1050, 2500], amp: 0.45 }, r: { k: 'son', F: [460, 1350, 1750], amp: 0.5, trill: true },
  j: { k: 'son', F: [300, 2200, 2950], amp: 0.5 },
};

// Источник (голосовые складки или шум дыхания) → три форманты с меняющейся частотой
function formantSynth(f0, F, A, o = {}) {
  const len = f0.length, src = new Float32Array(len);
  const BW = o.BW || (o.voiced ? [80, 110, 160] : [130, 170, 230]);
  const W = o.W || [1, 0.65, 0.4];
  if (o.voiced) {
    const vs = new Float32Array(len), as = white(len);
    const gl = p => p < 0.4 ? 0.5 * (1 - Math.cos(Math.PI * p / 0.4)) : p < 0.56 ? Math.cos(Math.PI / 2 * (p - 0.4) / 0.16) : 0;
    let ph = 0, ph2 = 0, jit = 1, sh = 1, prev = 0;
    for (let i = 0; i < len; i++) {
      ph += f0[i] * jit / SR; ph2 += f0[i] * jit / SR / 2;
      if (ph >= 1) { ph -= 1; jit = 1 + rnd(-0.012, 0.012); sh = 1 + rnd(-0.06, 0.06); }
      if (ph2 >= 1) ph2 -= 1;
      let g = gl(ph) * sh;
      if (o.sub) g += o.sub[i] * gl(ph2);
      vs[i] = g - prev; prev = g;
      as[i] *= 0.3 + 0.7 * g;
    }
    normRms(vs); normRms(as);
    const br = o.breath ?? 0.15;
    for (let i = 0; i < len; i++) src[i] = vs[i] + as[i] * br;
  } else {
    const w = white(len);
    for (let i = 0; i < len; i++) src[i] = w[i];
  }
  const out = new Float32Array(len);
  const at = t => Math.min(len - 1, Math.round(t * SR));
  for (let k = 0; k < 3; k++) {
    const z = src.slice();
    bqv(z, 'bp', t => F[k][at(t)], t => Math.max(0.5, F[k][at(t)] / BW[k]));
    for (let i = 0; i < len; i++) out[i] += z[i] * W[k];
  }
  for (let i = 0; i < len; i++) out[i] *= A[i];
  return out;
}

// Фраза из фонем: [символ, мс, громкость, f0 начала, f0 конца]
function speak(tokens, o = {}) {
  const segs = [];
  let t = 0;
  for (const [sym, ms, g = 1, fa, fb] of tokens) { segs.push({ sym, t0: t, t1: t + ms / 1000, g, fa, fb }); t += ms / 1000; }
  const len = N(t + 0.35);
  const F = [0, 1, 2].map(() => new Float32Array(len)), A = new Float32Array(len), f0 = new Float32Array(len);
  let lastF = VOW['@'], lastF0 = o.f0 || 120;
  const nextV = si => { for (let j = si + 1; j < segs.length; j++) if (VOW[segs[j].sym]) return VOW[segs[j].sym]; return null; };
  for (let si = 0; si < segs.length; si++) {
    const s = segs[si], v = VOW[s.sym], c = CONS[s.sym];
    const tf = v || (c && c.F) || nextV(si) || lastF;
    if (v) lastF = v;
    let a = 0;
    if (v) a = s.g;
    else if (c && c.k === 'son') a = c.amp * s.g;
    else if (c && c.voiced && o.voiced) a = 0.22 * s.g;
    const i0 = N(s.t0), i1 = Math.min(len, N(s.t1));
    for (let i = i0; i < i1; i++) {
      const u = (i - i0) / Math.max(1, i1 - i0);
      for (let k = 0; k < 3; k++) F[k][i] = tf[k];
      A[i] = a * (c && c.trill ? 0.35 + 0.65 * Math.abs(Math.sin(Math.PI * 27 * (i - i0) / SR)) : 1);
      f0[i] = s.fa ? lerp(s.fa, s.fb ?? s.fa, u) : lastF0;
    }
    if (s.fa) lastF0 = s.fb ?? s.fa;
  }
  for (let i = N(t); i < len; i++) { for (let k = 0; k < 3; k++) F[k][i] = F[k][i - 1] || lastF[k]; f0[i] = f0[i - 1] || lastF0; }
  for (let k = 0; k < 3; k++) smooth2(F[k], 0.022);
  smooth2(A, 0.01); smooth2(f0, 0.04);
  const out = formantSynth(f0, F, A, o);
  norm([out], -2);
  const fricG = o.voiced ? 0.3 : 0.45;
  for (const s of segs) {
    const c = CONS[s.sym];
    if (!c) continue;
    const d = s.t1 - s.t0;
    if (c.k === 'fric') {
      const z = white(N(d + 0.03)); bq(z, c.band[0], c.band[1], c.band[2]); norm([z], 0);
      env(z, tt => sstep(0, 0.018, tt) * (1 - sstep(d - 0.01, d + 0.03, tt)) * c.amp * s.g);
      add(out, z, s.t0, fricG);
    } else if (c.k === 'stop') {
      const tb = s.t0 + d * 0.6;
      const z = white(N(0.016)); bq(z, c.band[0], c.band[1], c.band[2]); norm([z], 0);
      env(z, tt => Math.exp(-tt / 0.004));
      add(out, z, tb, c.burst * s.g * 0.5);
      const asp = white(N(d * 0.4 + 0.02)); bq(asp, 'bp', 1600, 0.5); norm([asp], 0);
      env(asp, tt => 0.12 * Math.exp(-tt / 0.02));
      add(out, asp, tb + 0.005);
    }
  }
  bq(out, 'hp', 110, 0.7);
  return out;
}
// Вдох/выдох: шум через форманты рта
function breathSeg(kind, dur, amp = 1, shaky = 0) {
  const x = white(N(dur)), y = new Float32Array(x.length);
  const F = kind === 'in' ? [650, 1750, 2700] : [520, 1500, 2450];
  F.forEach((f, k) => { const z = x.slice(); bq(z, 'bp', f, f / 260); for (let i = 0; i < y.length; i++) y[i] += z[i] * [1, 0.7, 0.45][k]; });
  hp1(y, 350);
  normRms(y); gain(y, 0.25);
  return env(y, t => {
    const u = t / dur;
    const e = kind === 'in' ? Math.pow(u, 1.4) * (1 - sstep(0.88, 1, u)) : sstep(0, 0.12, u) * Math.pow(1 - u, 1.3);
    return e * amp * (1 + shaky * Math.sin(TAU * 9 * t));
  });
}
// Нечеловеческий вдох между словами: хрип с дребезгом и утробным гулом
function rattle(dur) {
  const x = white(N(dur)), y = new Float32Array(x.length);
  for (const [f, q, g] of [[650, 2, 1], [1300, 3, 0.6], [2400, 4, 0.3]]) { const z = x.slice(); bq(z, 'bp', f, q); for (let i = 0; i < y.length; i++) y[i] += z[i] * g; }
  normRms(y); gain(y, 0.3);
  const e = t => Math.pow(sstep(0, dur * 0.8, t), 1.2) * (1 - sstep(dur * 0.85, dur, t));
  let ph = 0;
  for (let i = 0; i < y.length; i++) {
    const t = i / SR;
    ph += (26 + 8 * Math.sin(TAU * 1.3 * t)) / SR;
    const rat = Math.pow(0.5 + 0.5 * Math.sin(TAU * ph), 6);
    y[i] *= (0.35 + 0.65 * rat) * e(t);
  }
  osc(y, 0, dur, () => 41, t => 0.14 * e(t), [1, 0.5, 0.33, 0.25, 0.2]);
  for (let k = 0; k < 3; k++) ring(y, rnd(0.1, dur - 0.1), rnd(1500, 2200), 0.004, 0.12);
  return y;
}

// ───────── запись WAV (+ блок smpl для петель) ─────────
function writeWav(name, chs, loop) {
  const ch = chs.length, n = chs[0].length, data = Buffer.alloc(n * ch * 2);
  for (let i = 0; i < n; i++) for (let c = 0; c < ch; c++) {
    const v = clamp(chs[c][i] + (R() - R()) / 32768, -1, 1);
    data.writeInt16LE(Math.round(v * 32767), (i * ch + c) * 2);
  }
  const fmt = Buffer.alloc(24);
  fmt.write('fmt ', 0); fmt.writeUInt32LE(16, 4); fmt.writeUInt16LE(1, 8); fmt.writeUInt16LE(ch, 10);
  fmt.writeUInt32LE(SR, 12); fmt.writeUInt32LE(SR * ch * 2, 16); fmt.writeUInt16LE(ch * 2, 20); fmt.writeUInt16LE(16, 22);
  const dh = Buffer.alloc(8); dh.write('data', 0); dh.writeUInt32LE(data.length, 4);
  const parts = [fmt, dh, data];
  if (loop) {
    const s = Buffer.alloc(68);
    s.write('smpl', 0); s.writeUInt32LE(60, 4);
    s.writeUInt32LE(Math.round(1e9 / SR), 16); s.writeUInt32LE(60, 20);
    s.writeUInt32LE(1, 36);                       // одна петля
    s.writeUInt32LE(0, 48); s.writeUInt32LE(0, 52); s.writeUInt32LE(n, 56);  // вперёд, 0…n
    parts.push(s);
  }
  const body = Buffer.concat(parts);
  const head = Buffer.alloc(12);
  head.write('RIFF', 0); head.writeUInt32LE(4 + body.length, 4); head.write('WAVE', 8);
  fs.writeFileSync(path.join(OUT_DIR, name + '.wav'), Buffer.concat([head, body]));
}

// ══════════════════════════════════════════════════════════════════════════════
//  Звуки
// ══════════════════════════════════════════════════════════════════════════════
const SOUNDS = [];
function sound(name, sd, fn) { SOUNDS.push({ name, sd, fn }); }

// ── Кассета и видеомагнитофон ──
sound('vcr_insert', 101, () => {
  const x = buf(1.6);
  const slide = white(N(0.15)); bq(slide, 'bp', 1400, 0.9); env(slide, t => sstep(0, 0.12, t)); add(x, slide, 0, 0.3);
  burst(x, 0.15, 0.012, 0.9, 'bp', 2400, 0.8);
  modes(x, 0.15, 0.8, [[180, 0.05, 1], [410, 0.04, 0.7], [960, 0.03, 0.5], [1730, 0.02, 0.35], [2900, 0.015, 0.25]]);
  const mot = buf(0.75);
  osc(mot, 0, 0.75, t => lerp(92, 124, sstep(0, 0.3, t)), t => sstep(0, 0.05, t) * (1 - sstep(0.62, 0.75, t)) * 0.22, [1, 0.5, 0.33, 0.25, 0.2, 0.15]);
  const gear = white(N(0.75)); bq(gear, 'bp', 2800, 3);
  env(gear, t => sstep(0, 0.05, t) * (1 - sstep(0.62, 0.75, t)) * 0.25 * (0.6 + 0.4 * Math.sin(TAU * 330 * t)));
  add(x, mot, 0.22); add(x, gear, 0.22);
  modes(x, 0.56, 0.45, [[240, 0.03, 1], [620, 0.02, 0.6], [1500, 0.015, 0.4]]); click(x, 0.56, 0.3);
  osc(x, 0.98, 0.5, t => lerp(900, 1750, sstep(0, 0.45, t)), t => sstep(0, 0.08, t) * (1 - sstep(0.4, 0.5, t)) * 0.035, [1, 0.3]);
  osc(x, 0.98, 0.5, t => lerp(22, 30, t / 0.5), t => sstep(0, 0.1, t) * (1 - sstep(0.4, 0.5, t)) * 0.25, [1, 0.6, 0.4, 0.3]);
  click(x, 1.3, 0.5, 2500); modes(x, 1.3, 0.3, [[1300, 0.01, 1], [3100, 0.006, 0.6]]);
  return { chs: [x], peak: -3 };
});
sound('vcr_stop', 102, () => {
  const x = buf(0.9);
  click(x, 0, 0.6, 2200); modes(x, 0, 0.35, [[1200, 0.012, 1], [2700, 0.007, 0.5]]);
  osc(x, 0.03, 0.42, t => lerp(1700, 500, t / 0.42), t => (1 - t / 0.42) * 0.05, [1, 0.3]);
  osc(x, 0.03, 0.42, t => lerp(120, 60, t / 0.42), t => (1 - t / 0.42) * 0.2, [1, 0.5, 0.3]);
  burst(x, 0.47, 0.01, 0.8, 'bp', 1800, 0.8);
  modes(x, 0.47, 0.7, [[160, 0.05, 1], [380, 0.04, 0.6], [900, 0.025, 0.4], [2100, 0.015, 0.3]]);
  return { chs: [x], peak: -3 };
});
sound('tape_hiss', 103, () => {
  const L = 4, X = 0.5, pre = 0.3;
  let n = white(N(pre + L + X)); hp1(n, 1800); bq(n, 'lp', 9000, 0.6);
  n = loopXf(n.subarray(N(pre)), L, X);
  for (let i = 0; i < n.length; i++) {
    const t = i / SR;
    n[i] = n[i] * 0.35 * (1 + 0.12 * Math.sin(TAU * 0.5 * t))
      + 0.035 * (Math.sin(TAU * 60 * t) + 0.5 * Math.sin(TAU * 120 * t + 1) + 0.3 * Math.sin(TAU * 180 * t + 2));
  }
  return { chs: [n], loop: true, peak: -6 };
});
sound('tape_static', 104, () => {
  const L = 2, X = 0.3, pre = 0.2, T = pre + L + X;
  let n = white(N(T)); hp1(n, 120); bq(n, 'pk', 3500, 0.8, 4);
  for (let k = 0; k < 70; k++) burst(n, rnd(0, T), rnd(0.001, 0.004), rnd(0.5, 1.4), 'hp', 1500);
  n = loopXf(n.subarray(N(pre)), L, X);
  for (let i = 0; i < n.length; i++) {
    const t = i / SR;
    let b = 0;
    for (let k = 1; k <= 20; k++) b += Math.sin(TAU * 60 * k * t) / k;
    n[i] = n[i] * 0.6 + b * 0.05;
  }
  return { chs: [n], loop: true, peak: -2 };
});
// Шёпот Сэма на кассете: фраза А с 0.05 с, фраза Б с 3.35 с
sound('tape_whisper', 105, () => {
  const A = speak([['i', 70, 0.8], ['t', 60], ['a', 170], ['n', 90], ['_', 150],
    ['j', 40, 0.7], ['e', 100], ['s', 85], ['l', 45], ['i', 70, 0.8], ['_', 40],
    ['E', 110], ['t', 60], ['@', 70, 0.7], ['_', 50],
    ['p', 55], ['@', 50, 0.7], ['p', 55], ['a', 55, 0.8], ['d', 50], ['j', 35, 0.6], ['o', 150], ['t', 70], ['_', 60],
    ['k', 55], ['t', 45], ['i', 50, 0.7], ['b', 50], ['e', 140], ['_', 200],
    ['n', 50], ['i', 40, 0.7], ['p', 50], ['r', 40], ['i', 60, 0.8], ['j', 30, 0.6], ['e', 50, 0.8], ['zh', 110], ['a', 150], ['j', 70, 0.6]]);
  const B = speak([['E', 140], ['t', 70], ['@', 60, 0.7], ['_', 60], ['n', 55], ['i', 45, 0.7], ['_', 30], ['@', 60, 0.8], ['l', 50], ['e', 170], ['n', 110]]);
  const x = buf(5.2);
  add(x, A, 0.05); add(x, breathSeg('in', 0.4, 0.9), 2.85); add(x, B, 3.35);
  bq(x, 'hp', 320, 0.7); bq(x, 'lp', 3300, 0.7); bq(x, 'lp', 3600, 0.7);
  const y = wowDelay(x, 12, 0.9, 0.6, 0.12, 7.5);
  sat(norm([y], 0)[0], 1.5);
  const hiss = white(y.length); hp1(hiss, 2000); bq(hiss, 'lp', 7500, 0.7);
  for (let i = 0; i < y.length; i++) y[i] += hiss[i] * 0.04 + 0.012 * Math.sin(TAU * 60 * i / SR);
  return { chs: [y], peak: -2 };
});

// ── Фонари и радио ──
sound('lamp_buzz', 209, () => {
  const L = 2, X = 0.3, pre = 0.2, T = pre + L + X;
  let s = white(N(T)); bq(s, 'bp', 4500, 0.8);
  env(s, t => 0.12 * (0.3 + 0.7 * Math.pow(Math.abs(Math.sin(TAU * 60 * t)), 4)));
  for (let k = 0; k < 8; k++) burst(s, rnd(0, T), 0.002, rnd(0.2, 0.4), 'hp', 2000);
  s = loopXf(s.subarray(N(pre)), L, X);
  const amps = [0.6, 1.0, 0.45, 0.5, 0.3, 0.32, 0.18, 0.2, 0.12, 0.12, 0.08, 0.08, 0.05, 0.05];
  const ph = amps.map(() => rnd(0, TAU));
  for (let i = 0; i < s.length; i++) {
    const t = i / SR;
    let v = 0;
    for (let k = 0; k < amps.length; k++) v += amps[k] * Math.sin(TAU * 120 * (k + 1) * t + ph[k]);
    s[i] += v * 0.12;
  }
  return { chs: [s], loop: true, peak: -6 };
});
sound('lamp_pop', 210, () => {
  const x = buf(0.9);
  particles(x, 0, 0.13, () => 1500, 2000, 7000, 0.0006, 0.002, () => 0.5);
  osc(x, 0, 0.16, () => 120, t => 0.35 * (1 - sstep(0.1, 0.16, t)) * (0.6 + 0.4 * R()), [1, 0.8, 0.6, 0.5, 0.4, 0.3, 0.25, 0.2, 0.15, 0.1]);
  ring(x, 0.1, 4300, 0.05, 0.5); ring(x, 0.1, 6150, 0.03, 0.3); ring(x, 0.1, 9800, 0.015, 0.15);
  ring(x, 0.11, 150, 0.06, 0.6); ring(x, 0.11, 310, 0.04, 0.3); burst(x, 0.11, 0.005, 0.4, 'lp', 3000);
  osc(x, 0.15, 0.6, () => 120, t => 0.12 * Math.exp(-t / 0.15), [1, 1, 0.5, 0.5, 0.3, 0.3]);
  for (let k = 0; k < 4; k++) burst(x, rnd(0.15, 0.5), 0.002, rnd(0.1, 0.3), 'hp', 2000);
  return { chs: [x], peak: -2 };
});
sound('radio_static', 211, () => {
  const L = 6, X = 0.4, pre = 0.2, T = pre + L + X;
  let n = white(N(T)); bq(n, 'hp', 250, 0.7); bq(n, 'lp', 4500, 0.7); bq(n, 'pk', 1600, 0.6, 3);
  for (let k = 0; k < 50; k++) burst(n, rnd(0, T), rnd(0.001, 0.003), rnd(0.4, 1.2), 'hp', 1200);
  // Обрывки далёкой передачи
  const vs = Object.values(VOW);
  for (const [t0, d] of [[0.9, 0.9], [2.9, 0.6], [4.5, 0.8]]) {
    const len = N(d), f0 = new Float32Array(len), F = [0, 1, 2].map(() => new Float32Array(len)), A = new Float32Array(len);
    let cur = pick(vs), next = 0;
    for (let i = 0; i < len; i++) {
      const t = i / SR;
      if (t >= next) { cur = pick(vs); next = t + rnd(0.08, 0.16); }
      f0[i] = 118 + 12 * Math.sin(TAU * 1.7 * t);
      for (let k = 0; k < 3; k++) F[k][i] = cur[k];
      A[i] = Math.pow(Math.abs(Math.sin(TAU * 2.3 * t)), 0.7) * Math.sin(Math.PI * t / d);
    }
    for (let k = 0; k < 3; k++) smooth2(F[k], 0.02);
    const v = formantSynth(f0, F, A, { voiced: true, breath: 0.1 });
    bq(v, 'hp', 300, 0.7); bq(v, 'lp', 3000, 0.7); norm([v], -8);
    add(n, v, pre + t0);
  }
  n = loopXf(n.subarray(N(pre)), L, X);
  const ns = norm([n], 0)[0];
  for (let i = 0; i < ns.length; i++) {
    const t = i / SR;
    ns[i] = ns[i] * 0.5 * (0.75 + 0.25 * Math.sin(TAU * t / 3))
      + 0.04 * Math.sin(TAU * 2100 * t - 150 * 6 * Math.cos(TAU * t / 6)) * (0.5 + 0.5 * Math.sin(TAU * t / 2));
  }
  return { chs: [ns], loop: true, peak: -3 };
});
sound('radio_cut', 212, () => {
  const x = buf(0.6);
  const b = white(N(0.2)); bq(b, 'bp', 1600, 0.4); env(b, t => Math.pow(t / 0.2, 1.5)); add(x, b, 0, 0.8);
  click(x, 0.2, 0.5, 1500); ring(x, 0.2, 2800, 0.004, 0.4); ring(x, 0.2, 900, 0.01, 0.3);
  osc(x, 0.2, 0.25, t => lerp(2500, 600, t / 0.25), t => 0.06 * (1 - t / 0.25), [1]);
  return { chs: [x], peak: -2 };
});

// ── Пикап: V8 снаружи и в кабине ──
function engineLoop(interior) {
  const fF = 146, L = 4, X = 0.5, pre = 0.6, T = pre + L + X, n = N(T), per = SR / fF;
  // Восемь вспышек на два оборота с неровным рисунком — «бульканье» V8; рисунок строго
  // повторяется, поэтому петля бесшовная
  const pat = [1.0, 0.78, 0.92, 0.7, 0.97, 0.82, 0.88, 0.74], off = [0, 0.03, -0.02, 0.04, -0.01, 0.025, -0.03, 0.015];
  const pulses = new Float32Array(n);
  for (let p = 0; ; p++) {
    const pos = (p + off[p % 8]) * per;
    if (pos >= n - 400) break;
    const a = pat[p % 8];
    for (let i = 0; i < 300; i++) {
      const t = i / SR;
      const j = Math.floor(pos) + i;
      if (j < n) pulses[j] += a * (1 - Math.exp(-t / 0.0003)) * Math.exp(-t / 0.0022) * (1 + 0.5 * Math.sin(TAU * 420 * t));
    }
  }
  bq(pulses, 'lp', 900, 0.7); bq(pulses, 'pk', 95, 1.2, 9); bq(pulses, 'pk', 290, 1.5, 4);
  norm([pulses], 0); sat(pulses, 2.2);
  if (interior) { bq(pulses, 'lp', 520, 0.8); bq(pulses, 'pk', 55, 1, 6); } else bq(pulses, 'lp', 2600, 0.7);
  const eng = pulses.slice(N(pre), N(pre) + N(L));
  norm([eng], 0);
  // Шумовая часть: впуск, шины по асфальту, ветер / дребезг салона
  const y = new Float32Array(n);
  const intake = white(n); bq(intake, 'bp', 1100, 1.2);
  for (let i = 0; i < n; i++) intake[i] *= 0.4 + 0.6 * Math.abs(Math.sin(Math.PI * fF * i / SR));
  const road = pink(n); bq(road, 'lp', interior ? 500 : 1000, 0.7); bq(road, 'pk', 125, 2, 5);
  const rumble = brown(n); bq(rumble, 'lp', 180, 0.7);
  norm([intake], 0); norm([road], 0); norm([rumble], 0);
  for (let i = 0; i < n; i++) y[i] = intake[i] * (interior ? 0.03 : 0.1) + road[i] * (interior ? 0.3 : 0.35) + rumble[i] * (interior ? 0.45 : 0.2);
  if (!interior) {
    const w = white(n); bq(w, 'bp', 900, 0.4); norm([w], 0);
    for (let i = 0; i < n; i++) y[i] += w[i] * 0.15 * (1 + 0.15 * Math.sin(TAU * i / SR / 4));
  } else {
    for (let k = 0; k < 10; k++) modes(y, rnd(0, T), 0.04, [[logU(800, 3000), 0.01, 1]]);
  }
  const nz = loopXf(y.subarray(N(pre)), L, X);
  const out = new Float32Array(N(L));
  for (let i = 0; i < out.length; i++) out[i] = eng[i] * 0.8 + nz[i];
  return { chs: [out], loop: true, peak: -2 };
}
sound('engine_ext', 213, () => engineLoop(false));
sound('engine_int', 214, () => engineLoop(true));

// ── Сигнал: два рожка 415 и 494 Гц, хриплые, с горловым резонансом ──
function hornWave(len, fFn, aFn) {
  const y = new Float32Array(len);
  for (const [base, g] of [[415, 1], [494, 0.9]]) {
    let ph = rnd(0, TAU);
    for (let i = 0; i < len; i++) {
      const t = i / SR, f = base * fFn(t);
      ph += TAU * f / SR;
      if (ph > 1e4) ph -= TAU * Math.floor(1e4 / TAU);
      let v = 0;
      for (let k = 1; k <= 22 && f * k < 11000; k++) v += ((k & 1) ? 1 : 0.55) / Math.pow(k, 0.9) * Math.sin(ph * k);
      y[i] += v * g * aFn(t);
    }
  }
  bq(y, 'hp', 280, 0.7); bq(y, 'pk', 2600, 1.4, 8); bq(y, 'pk', 1150, 1.2, 4); bq(y, 'lp', 9000, 0.7);
  norm([y], 0); sat(y, 1.6);
  return y;
}
sound('horn_double', 215, () => {
  const honks = [[0.0, 0.3], [0.42, 1.02]];
  const aFn = t => { for (const [a, b] of honks) if (t >= a && t < b + 0.05) return sstep(a, a + 0.012, t) * (1 - sstep(b, b + 0.04, t)); return 0; };
  const fFn = t => { let s = 1; for (const [a] of honks) if (t >= a) s = 1 - 0.04 * Math.exp(-(t - a) / 0.012); return s * (1 + 0.0025 * Math.sin(TAU * 7 * t)); };
  const y = hornWave(N(1.25), fFn, aFn);
  click(y, 0, 0.15, 2000); click(y, 0.42, 0.15, 2000);
  return { chs: [y], peak: -1 };
});
sound('horn_stuck', 216, () => {
  const L = 3, pre = 0.3;
  const y = hornWave(N(pre + L), t => 1 + 0.002 * Math.sin(TAU * t * 2 / 3) + 0.0012 * Math.sin(TAU * t * 7 / 3 + 1), () => 1);
  return { chs: [y.slice(N(pre), N(pre) + N(L))], loop: true, peak: -2 };
});
sound('horn_die', 217, () => {
  const y = hornWave(N(0.75), t => 1 - 0.18 * sstep(0.06, 0.2, t), t => (t < 0.06 ? 1 : Math.exp(-(t - 0.06) / 0.05)));
  click(y, 0.05, 0.4, 1500); modes(y, 0.05, 0.4, [[2400, 0.006, 1], [4100, 0.004, 0.6], [700, 0.01, 0.4]]);
  for (let k = 0; k < 6; k++) burst(y, rnd(0.06, 0.25), 0.002, rnd(0.05, 0.15), 'hp', 2500);
  return { chs: [y], peak: -2 };
});

// ── Шины: визг — узкополосный шум и «тон» с дрожанием высоты, а не чистые синусы ──
function squeal(dur, f0Fn, gateFn) {
  const len = N(dur), y = new Float32Array(len);
  const jit = wobble(len, 120), chat = wobble(len, 45);
  const tonal = new Float32Array(len), fa = new Float32Array(len);
  let ph = 0;
  for (let i = 0; i < len; i++) {
    const f = f0Fn(i / SR) * (1 + 0.025 * jit[i]);
    fa[i] = f; ph += TAU * f / SR;
    tonal[i] = Math.sin(ph) + 0.42 * Math.sin(2 * ph) + 0.2 * Math.sin(3 * ph) + 0.08 * Math.sin(5 * ph);
  }
  const at = t => Math.min(len - 1, N(t));
  const n1 = white(len); bqv(n1, 'bp', t => fa[at(t)], 7);
  const n2 = white(len); bqv(n2, 'bp', t => 2 * fa[at(t)], 7);
  const sc = white(len); bq(sc, 'bp', 1800, 0.6);
  norm([n1], 0); norm([n2], 0); norm([sc], 0); norm([tonal], 0);
  for (let i = 0; i < len; i++) y[i] = (tonal[i] * 0.5 + n1[i] * 0.6 + n2[i] * 0.3 + sc[i] * 0.18) * (1 + 0.35 * chat[i]) * gateFn(i / SR);
  return y;
}
sound('brake_squeal', 218, () => {
  const D = 1.9;
  const y = squeal(D, t => lerp(1080, 960, t / D), t => sstep(0, 0.12, t) * (1 - sstep(D - 0.3, D, t)) * (0.85 + 0.15 * t / D));
  const th = brown(N(D)); bq(th, 'lp', 160, 0.7); norm([th], 0);
  for (let i = 0; i < y.length; i++) { const t = i / SR; y[i] += th[i] * 0.3 * (0.7 + 0.3 * Math.sin(TAU * 16 * t)) * sstep(0, 0.1, t) * (1 - sstep(D - 0.3, D, t)); }
  sat(y, 1.3);
  return { chs: [y], peak: -1 };
});
sound('tire_screech', 219, () => {
  const D = 1.6, g = wobble(N(D), 9);
  const gate = t => sstep(0, 0.06, t) * (1 - sstep(1.15, D, t)) * (0.55 + 0.45 * clamp(g[Math.min(g.length - 1, N(t))] * 3, -1, 1));
  const f = t => lerp(1250, 1520, sstep(0, 1.1, t));
  const y = mix([squeal(D, f, gate), 1], [squeal(D, t => 1.27 * f(t), t => gate(t) * 0.7), 0.7]);
  sat(y, 1.4);
  return { chs: [y], peak: -0.5 };
});
sound('gravel_skid', 220, () => {
  const D = 1.2, x = buf(D);
  const e = t => sstep(0, 0.03, t) * (1 - sstep(0.75, 1.15, t));
  particles(x, 0, 1.15, t => 2600 * e(t) + 1, 800, 7000, 0.0008, 0.003, t => 0.35 * e(t));
  const gr = white(N(D)); bq(gr, 'bp', 2500, 0.5); env(gr, t => 0.12 * e(t)); add(x, gr);
  const ru = brown(N(D)); bq(ru, 'lp', 140, 0.7); norm([ru], 0); env(ru, t => 0.5 * e(t) * (1 + 0.6 * Math.sin(TAU * 11 * t))); add(x, ru);
  ring(x, 0.02, 55, 0.12, 0.9); ring(x, 0.02, 110, 0.06, 0.4); burst(x, 0.02, 0.006, 0.5, 'lp', 3000);
  ring(x, 0.36, 62, 0.1, 0.6); burst(x, 0.36, 0.005, 0.3, 'lp', 3000);
  // Камешки бьют в днище
  for (let k = 0; k < 14; k++) {
    const t = rnd(0.05, 0.9), f = logU(1800, 4800), tau = rnd(0.02, 0.06), a = rnd(0.08, 0.25);
    ring(x, t, f, tau, a); ring(x, t, f * 2.76, tau * 0.6, a * 0.4);
  }
  return { chs: [x], peak: -1 };
});

// ── Удар о валун: удар, мнущийся металл, стекло, обломки, пар ──
sound('crash_impact', 201, () => {
  const x = buf(3.8);
  burst(x, 0, 0.02, 1.0, 'lp', 7000, 0.7, 0.004);
  const th = buf(1.2);
  osc(th, 0, 1.2, t => 38 + 62 * Math.exp(-t / 0.06), t => Math.exp(-t / 0.28), [1, 0.25]);
  sat(th, 2.2); add(x, th, 0, 0.95);
  const rum = brown(N(1.6)); bq(rum, 'lp', 180, 0.7); env(rum, t => Math.exp(-t / 0.45) * sstep(0, 0.01, t)); norm([rum], 0); add(x, rum, 0, 0.45);
  // Кузов и капот гудят низко
  modes(x, 0.002, 0.5, [[92, 0.5, 1], [141, 0.45, 0.8], [233, 0.35, 0.65], [352, 0.3, 0.55], [517, 0.22, 0.45], [761, 0.18, 0.35]], 0.03);
  // Металл сминается серией надломов
  const metal = [];
  for (let k = 0; k < 30; k++) metal.push([logU(300, 4500), rnd(0.015, 0.12)]);
  for (let k = 0; k < 95; k++) {
    const t = Math.min(0.62, expR(0.17)), a = 0.6 * Math.exp(-t / 0.25) * Math.pow(R(), 1.5);
    for (let m = 0; m < 6; m++) { const [f, tau] = pick(metal); ring(x, t, f * rnd(0.99, 1.01), tau, a * rnd(0.3, 1)); }
    burst(x, t, rnd(0.002, 0.006), a * 0.8, 'bp', logU(1000, 5000), 1.2);
  }
  // Лобовое и стекло фары
  burst(x, 0.004, 0.004, 0.6, 'hp', 3000, 0.7, 0.001);
  particles(x, 0.004, 0.07, () => 3000, 2500, 9000, 0.004, 0.02, () => 0.25);
  for (let k = 0; k < 260; k++) {
    const t = 0.01 + Math.min(1.7, expR(0.22)), a = 0.35 * Math.exp(-t / 0.35) * R();
    const f = logU(2400, 8500), tau = rnd(0.008, 0.055);
    ring(x, t, f, tau, a); ring(x, t, f * rnd(1.4, 2.7), tau * 0.7, a * 0.5);
  }
  const sh = white(N(0.6)); hp1(sh, 3000); bq(sh, 'hp', 3000, 0.7); env(sh, t => Math.exp(-t / 0.12)); add(x, sh, 0.02, 0.35);
  // Обломки пластика и железа, оседающая крошка, металл ещё «дышит»
  for (let k = 0; k < 36; k++) {
    const t = rnd(0.25, 3.0), a = 0.22 * Math.exp(-(t - 0.25) / 0.9) * rnd(0.3, 1);
    if (R() < 0.6) modes(x, t, a, [[logU(500, 1800), rnd(0.015, 0.04), 1], [logU(1500, 3500), rnd(0.01, 0.025), 0.5]]);
    else modes(x, t, a, [[logU(1500, 4000), rnd(0.04, 0.12), 1], [logU(3000, 7000), rnd(0.02, 0.06), 0.5]]);
  }
  particles(x, 0.3, 2.6, t => 60 * Math.exp(-t / 0.8), 2000, 8000, 0.002, 0.01, t => 0.08 * Math.exp(-t / 0.9));
  creak(x, 0.9, 0.8, u => 14 + 20 * u, [[310, 0.04, 1], [680, 0.03, 0.6], [1250, 0.02, 0.4]], 0.05, 0.3, u => Math.sin(Math.PI * u));
  // Радиатор лопнул
  const hs = white(N(3.4)); hp1(hs, 1500); bq(hs, 'pk', 4000, 0.8, 5); env(hs, t => sstep(0, 0.35, t) * (0.7 + 0.3 * Math.exp(-t / 0.4))); add(x, hs, 0.25, 0.09);
  sat(x, 1.6);
  return { chs: [x], peak: -0.3 };
});
sound('tinnitus', 202, () => {
  const x = buf(6.5);
  osc(x, 0, 6.5, () => 3720, t => Math.exp(-t / 2.3) * (1 - Math.exp(-t / 0.008)), [1]);
  osc(x, 0, 6.5, () => 3727, t => 0.12 * Math.exp(-t / 1.6), [1]);
  const hi = white(N(6.5)); bq(hi, 'bp', 7000, 1.5); env(hi, t => 0.03 * Math.exp(-t / 1.2)); add(x, hi);
  env(x, t => 1 - sstep(5.4, 6.5, t));
  return { chs: [x], peak: -4 };
});

// ── «Олень»: хруст суставов и крик ──
sound('bone_crack', 203, () => {
  const x = buf(1.7);
  for (const t0 of [0.0, 0.17, 0.26, 0.52, 0.6, 0.83, 1.06, 1.19, 1.31]) {
    const a = rnd(0.5, 1);
    burst(x, t0, 0.002, a, 'hp', 1200, 0.7, 0.0006);
    modes(x, t0, a * 0.6, [[rnd(1200, 2200), 0.018, 1], [rnd(2500, 4500), 0.009, 0.7], [rnd(180, 320), 0.025, 0.9]]);
    particles(x, t0, t0 + rnd(0.02, 0.05), () => 2500, 1500, 6000, 0.0008, 0.003, () => a * 0.35);
    if (R() < 0.4) {
      const t1 = t0 + rnd(0.012, 0.03);
      burst(x, t1, 0.002, a * 0.6, 'hp', 1500, 0.7, 0.0005);
      modes(x, t1, a * 0.35, [[rnd(1400, 2600), 0.012, 1]]);
    }
  }
  // Влажный скрип растягиваемых сухожилий
  creak(x, 0, 1.45, u => 18 + 28 * u, [[420, 0.03, 1], [870, 0.022, 0.6], [1450, 0.016, 0.4]], 0.06, 0.35, u => Math.sin(Math.PI * u) * 0.8 + 0.2);
  return { chs: [x], peak: -1 };
});
sound('creature_shriek', 204, () => {
  const len = N(2.2);
  const f0 = new Float32Array(len), F = [0, 1, 2].map(() => new Float32Array(len)), A = new Float32Array(len), sub = new Float32Array(len);
  const vE = [550, 1850, 2700], vA = [850, 1300, 2600], vI = [420, 2400, 3200];
  for (let i = 0; i < len; i++) {
    const t = i / SR;
    // блеяние → протяжный рёв → визг, срывающийся вниз
    let f = t < 0.15 ? lerp(380, 620, sstep(0, 0.15, t)) : t < 0.9 ? lerp(620, 700, (t - 0.15) / 0.75)
      : t < 1.45 ? lerp(700, 960, sstep(0.9, 1.45, t)) : lerp(960, 420, sstep(1.45, 2.0, t));
    f0[i] = f * (1 + 0.03 * Math.sin(TAU * 7 * t));
    const m1 = sstep(0.1, 0.5, t), m2 = sstep(1.1, 1.6, t);
    for (let k = 0; k < 3; k++) F[k][i] = lerp(lerp(vE[k], vA[k], m1), vI[k], m2);
    A[i] = sstep(0, 0.03, t) * (1 - sstep(1.75, 2.15, t)) * (t > 0.15 && t < 0.7 ? 0.8 + 0.2 * Math.sin(TAU * 23 * t) : 1);
    sub[i] = 0.35 * sstep(0.6, 1.0, t);
  }
  const v1 = formantSynth(f0, F, A, { voiced: true, breath: 0.25, sub, BW: [110, 140, 200] });
  const Fb = [new Float32Array(len).fill(700), new Float32Array(len).fill(1150), new Float32Array(len).fill(2400)];
  const v2 = formantSynth(f0.map(v => v * 0.707), Fb, A, { voiced: true, breath: 0.15, BW: [120, 160, 220] });
  let x = mix([norm([v1], 0)[0], 1], [norm([v2], 0)[0], 0.45]);
  sat(norm([x], 0)[0], 1.8); bq(x, 'hp', 180, 0.7);
  x = freeverb(x, { room: 0.6, damp: 0.5, wet: 0.18, dry: 1 });
  return { chs: [x], peak: -1 };
});
// Нарастающий гул, пока фонари гаснут один за другим
sound('dread_drone', 205, () => {
  const D = 6.5, x = buf(D), rise = t => sstep(0, 4.2, t);
  osc(x, 0, D, () => 41, t => 0.5 * rise(t), [1]);
  osc(x, 0, D, () => 43.6, t => 0.4 * rise(t), [1]);
  const mid = buf(D);
  for (const f of [110, 116.5, 123.5]) osc(mid, 0, D, () => f, () => 0.12, [1, 0.5, 0.33, 0.25, 0.2, 0.16, 0.14, 0.12]);
  bqv(mid, 'lp', t => lerp(180, 1900, sstep(0, 4.6, t)), 0.9); env(mid, rise); add(x, mid);
  const hi = buf(D);
  osc(hi, 0, D, () => 1975, () => 0.04, [1]); osc(hi, 0, D, () => 2093, () => 0.035, [1]);
  env(hi, t => rise(t) * (0.6 + 0.4 * Math.sin(TAU * lerp(6, 14, t / D) * t))); add(x, hi);
  const wn = white(N(D)); bqv(wn, 'bp', t => lerp(500, 3000, sstep(0, 4.5, t)), 1.2); env(wn, t => 0.12 * rise(t)); add(x, wn);
  return { chs: [x], peak: -1 };
});
sound('sub_hit', 206, () => {
  const x = buf(2.6), b = buf(2.6);
  osc(b, 0, 2.6, t => 32 + 48 * Math.exp(-t / 0.09), t => Math.exp(-t / 0.7) * (1 - sstep(2.2, 2.6, t)), [1, 0.3, 0.15]);
  sat(b, 2.5); add(x, b);
  burst(x, 0, 0.05, 0.5, 'lp', 2000, 0.7, 0.012);
  ring(x, 0, 87, 1.1, 0.25); ring(x, 0, 131, 0.9, 0.18); ring(x, 0, 263, 0.5, 0.08);
  return { chs: [x], peak: -1 };
});

// ── После удара: пар, остывающий мотор ──
sound('steam_loop', 207, () => {
  const L = 3, X = 0.5, pre = 0.4, T = pre + L + X;
  const mk = () => {
    const n = white(N(T)); hp1(n, 1200); bq(n, 'hp', 1200, 0.7); bq(n, 'pk', 4200, 0.8, 6); bq(n, 'lp', 11000, 0.7);
    const turb = wobble(n.length, 30);
    for (let i = 0; i < n.length; i++) n[i] *= 0.6 * (1 + 0.1 * turb[i]);
    for (let k = 0; k < Math.round(T * 3); k++) osc(n, rnd(0, T), 0.03, t => lerp(300, 700, t / 0.03), t => 0.08 * Math.exp(-t / 0.01), [1]);
    for (let k = 0; k < Math.round(T * 6); k++) burst(n, rnd(0, T), 0.003, rnd(0.1, 0.3), 'hp', 2500);
    return loopXf(n.subarray(N(pre)), L, X);
  };
  const l = mk(), r = mk();
  for (const c of [l, r]) env(c, t => 1 + 0.2 * Math.sin(TAU * t / 1.5) + 0.1 * Math.sin(TAU * t / 0.75 + 1));
  return { chs: [l, r], loop: true, peak: -3 };
});
sound('engine_tick', 208, () => {
  const L = 8, X = 0.2, x = buf(L + X);
  for (let t = 0.2; t < L; t += rnd(0.35, 1.6)) {
    const a = rnd(0.2, 1);
    click(x, t, a * 0.3, 3000);
    modes(x, t, a * 0.5, [[rnd(2200, 3400), 0.008, 1], [rnd(4000, 6000), 0.005, 0.6], [rnd(900, 1400), 0.012, 0.4]]);
  }
  // Капли антифриза в лужу
  for (let k = 0; k < 6; k++) {
    const t0 = rnd(0.3, L - 0.3), f = rnd(900, 1250);
    osc(x, t0, 0.06, u => f * (1 + 0.6 * sstep(0, 0.02, u)), u => 0.25 * Math.exp(-u / 0.025), [1]);
    burst(x, t0, 0.006, 0.05, 'hp', 2500);
  }
  return { chs: [loopXf(x, L, X)], loop: true, peak: -3 };
});

// ── В кабине и у машины ──
sound('seatbelt', 301, () => {
  const x = buf(0.75);
  click(x, 0, 0.6, 2500); modes(x, 0, 0.5, [[2500, 0.006, 1], [4100, 0.004, 0.6]]);
  click(x, 0.012, 0.5, 3000); modes(x, 0.012, 0.6, [[3100, 0.015, 1], [5300, 0.01, 0.6]]);
  const z = white(N(0.38)); bq(z, 'bp', 1800, 1.0);
  env(z, t => Math.sin(Math.PI * t / 0.38) * (0.55 + 0.45 * Math.pow(0.5 + 0.5 * Math.sin(TAU * 55 * t), 3)));
  add(x, z, 0.05, 0.35);
  modes(x, 0.45, 0.7, [[900, 0.03, 1], [1700, 0.02, 0.7], [3200, 0.012, 0.4]]); click(x, 0.45, 0.4, 1500);
  return { chs: [x], peak: -2 };
});
sound('glovebox', 302, () => {
  const x = buf(0.85);
  click(x, 0, 0.6, 2000); modes(x, 0, 0.5, [[1800, 0.01, 1], [3600, 0.006, 0.5]]);
  const f = white(N(0.2)); bq(f, 'bp', 900, 1.2); env(f, t => Math.sin(Math.PI * t / 0.2) * 0.15); add(x, f, 0.05);
  modes(x, 0.25, 0.8, [[280, 0.05, 1], [520, 0.045, 0.7], [940, 0.03, 0.5], [1900, 0.015, 0.3]]); burst(x, 0.25, 0.008, 0.4, 'lp', 2500);
  for (let k = 0; k < 6; k++) modes(x, rnd(0.28, 0.6), rnd(0.08, 0.25), [[logU(1200, 4000), rnd(0.008, 0.03), 1]]);
  modes(x, 0.33, 0.3, [[1240, 0.06, 1], [3410, 0.03, 0.5]]);   // внутри перекатился фонарик
  return { chs: [x], peak: -2 };
});
sound('door_creak', 303, () => {
  const x = buf(2.0);
  click(x, 0, 0.5, 2000); modes(x, 0, 0.5, [[600, 0.03, 1], [1100, 0.025, 0.7], [2300, 0.015, 0.4]]); ring(x, 0.01, 120, 0.06, 0.6);
  // Смятая дверь поддаётся рывками: металл стонет
  creak(x, 0.1, 1.05, u => 12 + 58 * sstep(0, 0.7, u) + 10 * Math.sin(u * 13),
    [[310, 0.04, 1], [540, 0.035, 0.8], [890, 0.03, 0.6], [1430, 0.025, 0.45], [2210, 0.018, 0.3]], 0.12, 0.3, u => sstep(0, 0.15, u));
  const sc = white(N(1.0)); bq(sc, 'bp', 2600, 2); env(sc, t => 0.05 * Math.sin(Math.PI * t)); add(x, sc, 0.15);
  burst(x, 1.15, 0.01, 0.9, 'lp', 5000); modes(x, 1.15, 0.8, [[180, 0.2, 1], [410, 0.15, 0.7], [760, 0.1, 0.5], [1500, 0.05, 0.3]]);
  creak(x, 1.25, 0.5, u => 140 - 40 * u, [[1800, 0.01, 1], [2900, 0.008, 0.6]], 0.06, 0.15, u => Math.sin(Math.PI * u));
  return { chs: [x], peak: -1 };
});
sound('body_fall', 304, () => {
  const x = buf(1.2);
  osc(x, 0, 0.4, t => 75 - 25 * sstep(0, 0.15, t), t => Math.exp(-t / 0.1), [1, 0.4]);
  const lo = white(N(0.3)); bq(lo, 'lp', 400, 0.7); env(lo, t => Math.exp(-t / 0.08)); norm([lo], 0); add(x, lo, 0, 0.6);
  particles(x, 0, 0.28, t => 3500 * Math.exp(-t / 0.08), 900, 6500, 0.0008, 0.003, t => 0.5 * Math.exp(-t / 0.1));
  const cl = white(N(0.25)); bq(cl, 'bp', 1500, 0.8); env(cl, t => Math.exp(-t / 0.06)); norm([cl], 0); add(x, cl, 0.01, 0.25);
  // В рюкзаке звякают бутылки с заправки
  const bottle = () => [[1150, 0.35, 1], [2890, 0.22, 0.6], [4630, 0.12, 0.35]];
  modes(x, 0.07, 0.18, bottle(), 0.03); modes(x, 0.115, 0.1, bottle(), 0.03); modes(x, 0.19, 0.06, bottle(), 0.03);
  particles(x, 0.3, 0.9, () => 25, 1500, 6000, 0.001, 0.003, () => 0.08);
  return { chs: [x], peak: -1 };
});
sound('flashlight_click', 305, () => {
  const x = buf(0.25);
  click(x, 0, 0.7, 2000); modes(x, 0, 0.6, [[2200, 0.006, 1], [4700, 0.004, 0.6]]);
  click(x, 0.07, 0.35, 3000); modes(x, 0.07, 0.35, [[5500, 0.004, 1], [3300, 0.005, 0.5]]);
  return { chs: [x], peak: -3 };
});
sound('flashlight_drop', 306, () => {
  const x = buf(1.8), tube = [[1240, 0.18, 1], [3410, 0.1, 0.6], [6680, 0.06, 0.35]];
  burst(x, 0, 0.004, 0.8, 'hp', 1500); modes(x, 0, 0.7, tube);
  particles(x, 0, 0.12, () => 2500, 900, 6000, 0.0008, 0.003, t => 0.4 * Math.exp(-t / 0.04));
  burst(x, 0.21, 0.003, 0.4, 'hp', 1500); modes(x, 0.21, 0.35, tube);
  particles(x, 0.21, 0.28, () => 1500, 900, 6000, 0.0008, 0.003, () => 0.2);
  // Катится по гравию и замирает
  let rate = 40;
  for (let t = 0.34; t < 1.45; t += 1 / rate) {
    const a = 0.18 * (1 - (t - 0.34) / 1.2);
    particles(x, t, t + 0.004, () => 3000, 1500, 6000, 0.0008, 0.002, () => a);
    ring(x, t, 1240 * rnd(0.98, 1.02), 0.03, a * 0.35);
    rate = Math.max(6, rate * 0.955);
  }
  const rr = brown(N(1.2)); bq(rr, 'lp', 200, 0.7); norm([rr], 0); env(rr, u => 0.25 * (1 - u / 1.2)); add(x, rr, 0.34);
  modes(x, 1.5, 0.08, [[1240, 0.05, 1]]);
  return { chs: [x], peak: -1 };
});
for (let v = 1; v <= 4; v++) {
  sound('step_gravel_' + v, 400 + v, () => {
    const x = buf(0.45);
    osc(x, 0, 0.12, () => rnd(80, 100), t => 0.4 * Math.exp(-t / 0.03), [1]);
    particles(x, 0, 0.06, () => 3200, 1000, 6000, 0.0008, 0.0035, t => 0.55 * Math.exp(-t / 0.03));
    particles(x, 0.08 + rnd(0, 0.03), 0.24, () => 1100, 1200, 6500, 0.0008, 0.003, t => 0.25 * Math.exp(-t / 0.06));
    const sc = white(N(0.1)); bq(sc, 'bp', 2500, 0.8); env(sc, t => Math.exp(-t / 0.04)); add(x, sc, 0.09, 0.08);
    return { chs: [x], peak: -1 };
  });
}
sound('trailcam_click', 307, () => {
  const x = buf(0.6);
  click(x, 0, 0.5, 3000); modes(x, 0, 0.4, [[3800, 0.006, 1], [6200, 0.004, 0.5]]);
  click(x, 0.025, 0.4, 3000); modes(x, 0.025, 0.35, [[3600, 0.006, 1], [5900, 0.004, 0.5]]);
  osc(x, 0.05, 0.17, () => 2600, t => 0.06 * Math.sin(Math.PI * t / 0.17), [1, 0.4, 0.2]);
  osc(x, 0.05, 0.17, () => 410, t => 0.05 * Math.sin(Math.PI * t / 0.17), [1, 0.5, 0.3, 0.2]);
  click(x, 0.26, 0.6, 2000); modes(x, 0.26, 0.4, [[2100, 0.01, 1], [4300, 0.006, 0.5]]);
  return { chs: [x], peak: -3 };
});
sound('twig_snap', 308, () => {
  let x = buf(0.9);
  burst(x, 0, 0.002, 1, 'hp', 1500, 0.7, 0.0005); burst(x, 0, 0.012, 0.6, 'bp', 3200, 1.0, 0.004);
  modes(x, 0, 0.6, [[780, 0.025, 1], [1630, 0.015, 0.7], [2890, 0.01, 0.5], [220, 0.03, 0.6]]);
  burst(x, 0.021, 0.002, 0.5, 'hp', 1500, 0.7, 0.0005); modes(x, 0.021, 0.3, [[900, 0.02, 1], [2100, 0.01, 0.5]]);
  const ru = white(N(0.55)); bq(ru, 'bp', 3000, 0.8); env(ru, t => 0.12 * Math.exp(-t / 0.15) * (0.5 + R())); add(x, ru, 0.04);
  bq(x, 'lp', 6000, 0.7);
  x = freeverb(x, { room: 0.75, damp: 0.6, wet: 0.35, dry: 0.8, pre: 0.025 });
  return { chs: [x], peak: -1 };
});
sound('breath_panic', 309, () => {
  const x = buf(3.6);
  add(x, breathSeg('in', 0.36, 1.0), 0.0); add(x, breathSeg('out', 0.5, 0.75, 0.4), 0.42);
  add(x, breathSeg('in', 0.3, 0.9), 1.05); add(x, breathSeg('out', 0.55, 0.7, 0.45), 1.4);
  add(x, breathSeg('in', 0.28, 0.85), 2.1); add(x, breathSeg('out', 0.75, 0.6, 0.5), 2.42);
  return { chs: [x], peak: -2 };
});

// ── Ночной лес ──
sound('crickets', 310, () => {
  const L = 6, n = N(L), l = new Float32Array(n), r = new Float32Array(n);
  // [несущая, стрекотов за петлю, импульсов в стрекоте, громкость, панорама]
  const bugs = [[4100, 9, 3, 0.9, -0.6], [4650, 10, 4, 0.6, 0.5], [4900, 12, 3, 0.45, 0.1], [5200, 11, 5, 0.35, -0.2],
    [4450, 8, 4, 0.3, 0.8], [3900, 13, 3, 0.25, -0.9], [5450, 15, 2, 0.2, 0.3]];
  for (const [fc, chirps, pulses, amp, pan] of bugs) {
    const period = L / chirps, prate = rnd(28, 36), off = rnd(0, period), fcv = fc * rnd(0.99, 1.01), plen = N(0.022);
    for (let c = 0; c < chirps; c++) for (let p = 0; p < pulses; p++) {
      const s0 = N((off + c * period + p / prate) % L);
      for (let i = 0; i < plen; i++) {
        const t = i / SR, v = Math.sin(TAU * fcv * t + p) * sstep(0, 0.002, t) * Math.exp(-t / 0.008) * amp;
        const j = (s0 + i) % n;
        l[j] += v * (1 - pan) * 0.5; r[j] += v * (1 + pan) * 0.5;
      }
    }
  }
  for (const c of [l, r]) {
    const pre = 0.2, X = 0.4;
    let b = white(N(pre + L + X)); bq(b, 'bp', 7200, 1.5);
    env(b, t => 0.025 * (0.6 + 0.4 * Math.abs(Math.sin(TAU * 47 * t))));
    b = loopXf(b.subarray(N(pre)), L, X);
    for (let i = 0; i < n; i++) c[i] += b[i];
  }
  return { chs: [l, r], loop: true, peak: -3 };
});
sound('forest_wind', 311, () => {
  const L = 8, X = 1.0, pre = 0.5, T = pre + L + X;
  const mk = () => {
    const b = brown(N(T)); bq(b, 'lp', 350, 0.7);
    const p = pink(N(T)); bq(p, 'bp', 800, 0.5);
    const h = white(N(T)); bq(h, 'bp', 3500, 0.7);
    norm([b], -6); norm([p], -10); norm([h], -16);
    const y = new Float32Array(N(T));
    for (let i = 0; i < y.length; i++) y[i] = b[i] + p[i] + h[i] * 0.6;
    return loopXf(y.subarray(N(pre)), L, X);
  };
  const l = mk(), r = mk();
  const gust = t => 0.55 + 0.25 * Math.sin(TAU * t / 8 + 0.4) + 0.12 * Math.sin(TAU * 3 * t / 8 + 1.3) + 0.08 * Math.sin(TAU * 5 * t / 8 + 2.1);
  for (const c of [l, r]) env(c, gust);
  // Где-то скрипит сосна
  const cr = buf(L);
  creak(cr, 5.1, 0.9, u => 9 + 6 * u, [[180, 0.08, 1], [410, 0.06, 0.6], [760, 0.04, 0.3]], 0.05, 0.2, u => Math.sin(Math.PI * u));
  for (let i = 0; i < l.length; i++) { l[i] += cr[i] * 0.8; r[i] += cr[i] * 0.5; }
  return { chs: [l, r], loop: true, peak: -3 };
});

// ── Эпилог: Итана тащат к особняку ──
sound('drag_pull', 312, () => {
  const x = buf(1.3);
  burst(x, 0, 0.05, 0.5, 'bp', 400, 0.8, 0.02); ring(x, 0, 70, 0.05, 0.6);
  const sw = white(N(0.8)); bq(sw, 'bp', 1800, 0.6); env(sw, t => sstep(0, 0.08, t) * (1 - sstep(0.4, 0.78, t))); norm([sw], 0); add(x, sw, 0.02, 0.3);
  particles(x, 0.03, 0.78, t => 700 * Math.sin(Math.PI * Math.min(1, t / 0.75)) + 50, 2000, 7000, 0.001, 0.003, t => 0.3 * Math.sin(Math.PI * Math.min(1, t / 0.75)));
  const lo = brown(N(0.8)); bq(lo, 'lp', 300, 0.7); norm([lo], 0); env(lo, t => Math.sin(Math.PI * Math.min(1, t / 0.78))); add(x, lo, 0.02, 0.3);
  for (const t0 of [rnd(0.2, 0.35), rnd(0.45, 0.65)]) {
    burst(x, t0, 0.002, 0.3, 'hp', 1500, 0.7, 0.0005);
    modes(x, t0, 0.15, [[rnd(800, 1600), 0.015, 1], [rnd(2000, 3000), 0.008, 0.5]]);
  }
  return { chs: [x], peak: -1 };
});
sound('gate_creak', 313, () => {
  let x = buf(2.8);
  creak(x, 0.05, 2.0, u => 6 + 16 * Math.sin(Math.PI * u) + 4 * Math.sin(u * 17),
    [[210, 0.12, 1], [395, 0.1, 0.8], [640, 0.08, 0.6], [1120, 0.06, 0.45], [1730, 0.04, 0.3], [2600, 0.03, 0.2]],
    0.1, 0.25, u => sstep(0, 0.1, u) * (1 - sstep(0.85, 1, u)));
  const gr = white(N(2.0)); bq(gr, 'bp', 900, 1.2); env(gr, t => 0.04 * Math.sin(Math.PI * t / 2.0)); add(x, gr, 0.05);
  x = freeverb(x, { room: 0.82, damp: 0.5, wet: 0.28, dry: 0.9, pre: 0.03 });
  return { chs: [x], peak: -1 };
});
sound('gate_slam', 314, () => {
  let x = buf(3.2);
  burst(x, 0, 0.01, 1, 'lp', 6000, 0.7, 0.003);
  osc(x, 0, 0.5, t => 60 - 15 * sstep(0, 0.2, t), t => Math.exp(-t / 0.15), [1, 0.3]);
  modes(x, 0.002, 0.7, [[74, 1.4, 1], [157, 1.2, 0.85], [288, 0.9, 0.7], [461, 0.8, 0.6], [672, 0.6, 0.5],
    [935, 0.5, 0.4], [1290, 0.35, 0.3], [1760, 0.25, 0.25], [2390, 0.18, 0.18]], 0.01);
  modes(x, 0.05, 0.4, [[1900, 0.03, 1], [3300, 0.02, 0.6]]); click(x, 0.05, 0.3, 2000);
  for (let k = 0; k < 12; k++) modes(x, 0.1 + Math.min(0.6, expR(0.18)), rnd(0.04, 0.15), [[logU(2000, 5000), rnd(0.02, 0.06), 1], [logU(3000, 7000), 0.02, 0.4]]);
  x = freeverb(x, { room: 0.85, damp: 0.45, wet: 0.3, dry: 0.9, pre: 0.035 });
  return { chs: [x], peak: -0.5 };
});

// ── Голоса ──
// «Итан!.. Итан, я здесь!» — далеко в лесу, с отражениями от стволов
sound('voice_call', 315, () => {
  const v = speak([
    ['i', 90, 0.8, 228, 255], ['t', 70], ['a', 430, 1, 305, 280], ['n', 150, 1, 270, 225], ['_', 560],
    ['i', 80, 0.8, 222, 240], ['t', 60], ['a', 200, 1, 272, 250], ['n', 80, 1, 238, 230], ['_', 110],
    ['j', 50, 0.7, 255, 275], ['a', 150, 1, 285, 295], ['z', 70, 1, 290, 290], ['d', 45], ['j', 35, 0.6, 300, 300],
    ['e', 240, 1, 305, 270], ['s', 170], ['_', 100]], { voiced: true, breath: 0.2 });
  let x = buf(5.2);
  add(x, v, 0.05);
  bq(x, 'hp', 180, 0.7); bq(x, 'lp', 2800, 0.7); bq(x, 'lp', 3200, 0.7);
  const er = new Float32Array(x.length);
  for (const [d, g] of [[0.017, 0.5], [0.029, 0.4], [0.043, 0.33], [0.061, 0.25], [0.083, 0.2]]) add(er, x, d, g);
  for (let i = 0; i < x.length; i++) x[i] += er[i];
  // Лес глушит верха и не даёт длинного хвоста, как в зале
  x = freeverb(x, { room: 0.76, damp: 0.72, wet: 0.36, dry: 0.75, pre: 0.035 });
  return { chs: [x], peak: -1 };
});
// «Итан… обернись. Посмотри на меня» — у самого уха; между словами нечеловеческий вдох
sound('whisper_behind', 316, () => {
  const p1 = speak([['i', 90, 0.8], ['t', 70], ['a', 260], ['n', 210], ['_', 60]]);
  const p2 = speak([['@', 60, 0.7], ['b', 55], ['e', 70, 0.8], ['r', 55], ['n', 50], ['i', 170], ['s', 180], ['_', 60]]);
  const p3 = speak([['p', 55], ['@', 60, 0.7], ['s', 95], ['m', 55], ['@', 55, 0.7], ['t', 50], ['r', 45], ['i', 160], ['_', 70],
    ['n', 45], ['a', 60, 0.7], ['_', 25], ['m', 50], ['i', 50, 0.7], ['n', 45], ['j', 40, 0.6], ['a', 240], ['_', 60]]);
  const x = buf(4.9);
  add(x, p1, 0.0); add(x, rattle(0.72), 0.78); add(x, p2, 1.55); add(x, rattle(0.42), 2.36); add(x, p3, 2.85);
  bq(x, 'pk', 240, 0.8, 4); bq(x, 'hp', 90, 0.7);
  return { chs: [x], peak: -1 };
});

// ══════════════════════════════════════════════════════════════════════════════
fs.mkdirSync(OUT_DIR, { recursive: true });
const only = process.argv.slice(2);
for (const s of SOUNDS) {
  if (only.length && !only.includes(s.name)) continue;
  seed(s.sd);
  const t0 = Date.now();
  const r = s.fn();
  if (!r.loop) for (const c of r.chs) hp1(c, 18);      // убрать постоянную составляющую
  norm(r.chs, r.peak ?? -1);
  writeWav(s.name, r.chs, r.loop);
  console.log(`${s.name.padEnd(18)} ${(r.chs[0].length / SR).toFixed(2)}s ${r.chs.length}ch${r.loop ? ' loop' : ''}  ${Date.now() - t0} ms`);
}
