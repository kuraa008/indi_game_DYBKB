#!/usr/bin/env node
'use strict';
// ══════════════════════════════════════════════════════════════════════════════
//  generate_cutscene_audio.js — звуки и черновая озвучка сюжетных кат-сцен
//  (scripts/cutscenes/*.gd). Запуск:  node game/scripts/generate_cutscene_audio.js [имя ...]
//
//  • Звуки пишутся в game/assets/audio/cutscenes/*.wav, голоса — в .../cutscenes/voice/*.wav.
//  • Голоса — ЧЕРНОВИК: Windows TTS (Microsoft Pavel / Irina, русский пакет речи) через
//    tools/cutscene_tts.ps1 + обработка под персонажа (телефон, старуха, существо, лес…).
//    Bekasyl: замените voice/<id>.wav своей записью с тем же именем — кат-сцена сама
//    подстроит паузы под новую длину. Тексты реплик — в таблице VOICES ниже (из сюжета Досыма).
//  • Остальное собрано из шума, генераторов и резонаторов (помощники из generate_intro_sfx.js).
// ══════════════════════════════════════════════════════════════════════════════

const fs = require('fs');
const path = require('path');
const os = require('os');
const cp = require('child_process');
const crypto = require('crypto');
const K = require('./generate_intro_sfx.js');
const { SR, TAU, seed, R, rnd, logU, expR, N, clamp, sstep, add, env, gain, norm, normRms, sat, smooth2,
  white, pink, brown, wobble, bq, bqv, lp1, hp1, ring, modes, burst, click, osc, particles, creak,
  freeverb, wowDelay, loopXf, breathSeg, rattle } = K;

const OUT = path.join(__dirname, '..', 'assets', 'audio', 'cutscenes');
const VOUT = path.join(OUT, 'voice');
const TTS_PS = path.join(__dirname, '..', '..', 'tools', 'cutscene_tts.ps1');
const TTS_CACHE = path.join(os.tmpdir(), 'escape_cutscene_tts');

// ───────── общие помощники ─────────
const buf = s => new Float32Array(N(s));
function pad(x, sec) { const y = new Float32Array(x.length + N(sec)); y.set(x); return y; }
function rms(x) { let s = 0; for (let i = 0; i < x.length; i++) s += x[i] * x[i]; return Math.sqrt(s / Math.max(1, x.length)); }
function scaleTo(x, len) { const y = new Float32Array(len); y.set(x.subarray(0, Math.min(len, x.length))); return y; }
function mono2st(x, w = 0) {
  // Псевдостерео: правый канал — чуть задержанная и отфильтрованная копия
  const l = x.slice(), r = x.slice();
  if (w > 0) { const d = N(0.011); for (let i = x.length - 1; i >= d; i--) r[i] = x[i] * (1 - w) + x[i - d] * w; }
  return [l, r];
}
function revSt(x, o) { return [freeverb(x, { ...o, pre: (o.pre || 0.02) }), freeverb(x, { ...o, pre: (o.pre || 0.02) + 0.011, room: (o.room || 0.8) * 0.97 })]; }
function envelope(x, att = 0.005, rel = 0.06) {
  const e = new Float32Array(x.length), aa = Math.exp(-1 / (att * SR)), ar = Math.exp(-1 / (rel * SR));
  let v = 0;
  for (let i = 0; i < x.length; i++) { const a = Math.abs(x[i]); v = a > v ? aa * v + (1 - aa) * a : ar * v + (1 - ar) * a; e[i] = v; }
  return e;
}
function readWav(file) {
  const b = fs.readFileSync(file);
  let p = 12, fmt = null, data = null;
  while (p + 8 <= b.length) {
    const id = b.toString('ascii', p, p + 4), sz = b.readUInt32LE(p + 4);
    if (id === 'fmt ') fmt = { ch: b.readUInt16LE(p + 10), sr: b.readUInt32LE(p + 12) };
    else if (id === 'data') data = b.subarray(p + 8, p + 8 + sz);
    p += 8 + sz + (sz & 1);
  }
  const n = Math.floor(data.length / 2 / fmt.ch), x = new Float32Array(n);
  for (let i = 0; i < n; i++) x[i] = data.readInt16LE(i * 2 * fmt.ch) / 32768;
  return { sr: fmt.sr, x };
}
function resample(x, from, to) {
  const n = Math.floor(x.length * to / from), y = new Float32Array(n), r = from / to;
  for (let i = 0; i < n; i++) { const p = i * r, i0 = Math.floor(p), f = p - i0; const a = x[i0] || 0, b = x[i0 + 1] || 0; y[i] = a + (b - a) * f; }
  return y;
}
// k > 1 — выше и быстрее, k < 1 — ниже и медленнее
function speed(x, k) { return resample(x, SR * k, SR); }
function trim(x, thr = 0.006, padS = 0.05) {
  let a = 0, b = x.length - 1;
  while (a < b && Math.abs(x[a]) < thr) a++;
  while (b > a && Math.abs(x[b]) < thr) b--;
  a = Math.max(0, a - N(padS)); b = Math.min(x.length - 1, b + N(padS));
  return x.slice(a, b + 1);
}
function fadeEdges(x, a = 0.01, b = 0.05) { return env(x, t => sstep(0, a, t) * (1 - sstep(x.length / SR - b, x.length / SR, t))); }
// Шум дыхания по огибающей голоса: хрип, шёпот, старость
function breathy(x, amt, lo = 1000, hi = 5000) {
  const e = envelope(x, 0.008, 0.07), n = white(x.length);
  bq(n, 'hp', lo, 0.7); bq(n, 'lp', hi, 0.7); normRms(n);
  const y = new Float32Array(x.length);
  for (let i = 0; i < x.length; i++) y[i] = x[i] * (1 - amt * 0.55) + n[i] * e[i] * amt * 1.3;
  return y;
}
function subOctave(x, f = 170) {
  const s = new Float32Array(x.length);
  for (let i = 0; i < x.length; i++) s[i] = Math.abs(x[i]);
  hp1(s, 35); bq(s, 'lp', f, 0.7); bq(s, 'lp', f, 0.7);
  return s;
}
function delayAdd(x, sec, g) { const d = N(sec), y = pad(x, sec); for (let i = 0; i < x.length; i++) y[i + d] += x[i] * g; return y; }

// ───────── запись WAV ─────────
function writeWav(dir, name, chs, loop) {
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
    s.writeUInt32LE(1, 36); s.writeUInt32LE(0, 48); s.writeUInt32LE(0, 52); s.writeUInt32LE(n, 56);
    parts.push(s);
  }
  const body = Buffer.concat(parts);
  const head = Buffer.alloc(12);
  head.write('RIFF', 0); head.writeUInt32LE(4 + body.length, 4); head.write('WAVE', 8);
  fs.writeFileSync(path.join(dir, name + '.wav'), Buffer.concat([head, body]));
}

// ══════════════════════════════════════════════════════════════════════════════
//  ГОЛОСА (тексты — из сюжета Досыма, файл «syuzhet»)
// ══════════════════════════════════════════════════════════════════════════════
const br = ms => `<break time="${ms}ms"/>`;
const ETHAN = { v: 'Pavel', rate: '-8%', pitch: '-3%' };
const SAM = { v: 'Pavel', rate: '-14%', pitch: '+9%' };
const POLICE = { v: 'Pavel', rate: '-4%', pitch: '-12%' };
const GRANDMA = { v: 'Irina', rate: '-11%', pitch: '-16%' };
const FATHER = { v: 'Pavel', rate: '-16%', pitch: '-10%' };

const VOICES = [
  // Предыстория (пролог)
  { id: 'sam_go', v: 'Pavel', rate: '-10%', pitch: '+9%', fx: 'ethan_room', body: `Езжай, брат.${br(500)} Учись.${br(500)} За отцом я сам присмотрю.` },
  // Звонок (пролог)
  { id: 'police_1', ...POLICE, fx: 'phone', body: `Итан?${br(500)} Это полиция округа.` },
  { id: 'police_2', ...POLICE, fx: 'phone', body: `Ваш отец найден мёртвым в своей кровати.${br(700)} Ваш брат, Сэм, пропал.${br(500)} Мы не можем его найти.` },
  { id: 'ethan_kak', ...ETHAN, rate: '-45%', pitch: '-8%', fx: 'whisper', body: 'Как' },
  // Заправка (бабушка) — монолог целиком
  { id: 'grandma_1', ...GRANDMA, fx: 'grandma', body: `В этих лесах живёт тот, кто носит чужую шкуру.${br(600)} Старики зовут его скинволкер.` },
  { id: 'grandma_2', ...GRANDMA, fx: 'grandma', body: `Днём он прячется.${br(400)} А ночью выходит к дороге в облике чёрного оленя.${br(500)} Глаза у него светятся не как у зверя,${br(250)} а как у человека.` },
  { id: 'grandma_3', ...GRANDMA, fx: 'grandma', body: `Он ничего не забывает.${br(400)} Он запоминает голоса тех, кого забрал, и зовёт их голосами живых.${br(500)} Зовёт по имени.${br(400)} Тех, кто по ним скучает.` },
  { id: 'grandma_4', ...GRANDMA, fx: 'grandma', body: `Мой муж ушёл на голос сына.${br(500)} Сын к тому времени три года как лежал в земле.${br(800)} Мужа я больше не видела.` },
  { id: 'grandma_5', ...GRANDMA, rate: '-24%', fx: 'grandma', body: 'Запомни, сынок.' },
  { id: 'grandma_rule_1', ...GRANDMA, fx: 'grandma', body: `Увидишь на дороге чёрного оленя${br(300)} — не останавливайся.` },
  { id: 'grandma_rule_2', ...GRANDMA, fx: 'grandma', body: `Позовут по имени из леса${br(300)} — не отзывайся.` },
  { id: 'grandma_rule_3', ...GRANDMA, fx: 'grandma', body: `Почувствуешь, что кто-то идёт следом,${br(300)} — не оборачивайся.` },
  // Конец главы 2: существо голосом Сэма из дома
  { id: 'mimic_sam_where', ...SAM, rate: '-22%', fx: 'mimic', body: `Итан?${br(900)} Итан, куда ты ушёл?` },
  // Конец главы 3
  { id: 'creature_mine', v: 'Pavel', rate: '-45%', pitch: '-30%', fx: 'creature', body: `Это.${br(850)} Моё.` },
  // Глава 4
  { id: 'ethan_sam_eto_ya', ...ETHAN, rate: '-18%', fx: 'ethan_soft', body: `Сэм.${br(800)} Сэм, это я.` },
  // Глава 5
  { id: 'ethan_not_father', ...ETHAN, rate: '-14%', fx: 'ethan', body: `Ты не мой отец.${br(700)} Мой отец сделал всё, чтобы я сюда не вернулся.` },
  { id: 'ethan_name', ...ETHAN, rate: '-6%', pitch: '+14%', fx: 'shout', body: 'Джозеф Крейн!' },
  { id: 'crane_1', v: 'Pavel', rate: '-42%', pitch: '-22%', fx: 'crane', body: `Марта.${br(900)} Мальчики.` },
  { id: 'crane_2', v: 'Pavel', rate: '-42%', pitch: '-22%', fx: 'crane', body: 'Я не хотел.' },
  { id: 'crane_3', v: 'Pavel', rate: '-46%', pitch: '-24%', fx: 'crane', body: 'Зима была такая долгая.' },
  { id: 'sam_ethan_weak', ...SAM, rate: '-38%', fx: 'weak', body: 'Итан.' },
  // Рассвет
  { id: 'sam_why', ...SAM, rate: '-24%', fx: 'weak', body: 'Почему ты вернулся?' },
  { id: 'ethan_late', ...ETHAN, rate: '-18%', fx: 'ethan_soft', body: `Опоздал.${br(900)} Но вернулся.` },
  // Финал на заправке
  { id: 'ethan_right', ...ETHAN, rate: '-12%', fx: 'ethan_room', body: `Вы были правы.${br(700)} Во всём.` },
  { id: 'grandma_husband', ...GRANDMA, rate: '-24%', fx: 'grandma', body: `А мой муж?${br(900)} Ты его там не видел?` },
  { id: 'forest_marta', v: 'Pavel', rate: '-45%', pitch: '-14%', fx: 'forest', body: `Марта.${br(1400)} Марта.` },
  // Плохая концовка
  { id: 'ethan_here', ...ETHAN, rate: '-26%', pitch: '-5%', fx: 'ethan_soft', body: 'Я здесь, пап.' },
  // Голоса снаружи (подложка плохой концовки) и телевизор (подложка звонка)
  { id: 'bed_father', ...FATHER, fx: 'raw', body: `Ответь мне, сынок.${br(600)} Один раз.` },
  { id: 'bed_sam', ...SAM, fx: 'raw', body: `Брат, мне страшно.${br(500)} Не бросай меня опять.` },
  { id: 'bed_father2', ...FATHER, fx: 'raw', body: `Итан, сынок.${br(400)} Это же я.` },
  { id: 'tv_1', v: 'Irina', rate: '+8%', pitch: '+12%', fx: 'raw', body: 'Ну и где ты пропадал всю ночь?' },
  { id: 'tv_2', v: 'Pavel', rate: '+10%', pitch: '+6%', fx: 'raw', body: 'Ты не поверишь, что со мной случилось!' },
  { id: 'tv_3', v: 'Irina', rate: '+5%', pitch: '+15%', fx: 'raw', body: 'Опять?' },
  { id: 'tv_4', v: 'Pavel', rate: '+8%', pitch: '+4%', fx: 'raw', body: 'Да клянусь, это была не моя собака!' },
];

function ssml(v) {
  return `<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="ru-RU"><prosody rate="${v.rate || '0%'}" pitch="${v.pitch || '0%'}">${v.body}</prosody></speak>`;
}
function ttsFile(v) {
  const h = crypto.createHash('md5').update(v.v + '|' + ssml(v)).digest('hex').slice(0, 12);
  return path.join(TTS_CACHE, `${v.id}_${h}.wav`);
}
function renderTTS(list) {
  fs.mkdirSync(TTS_CACHE, { recursive: true });
  const jobs = list.filter(v => !fs.existsSync(ttsFile(v))).map(v => ({ voice: v.v, ssml: ssml(v), out: ttsFile(v) }));
  if (!jobs.length) return;
  const jf = path.join(TTS_CACHE, 'jobs.json');
  fs.writeFileSync(jf, JSON.stringify(jobs), 'utf8');
  console.log(`TTS: озвучиваю ${jobs.length} реплик…`);
  cp.execFileSync('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', TTS_PS, '-Jobs', jf], { stdio: 'inherit' });
}
function ttsRaw(id) {
  const v = VOICES.find(q => q.id === id);
  const w = readWav(ttsFile(v));
  let x = resample(w.x, w.sr, SR);
  bq(x, 'lp', w.sr * 0.47, 0.7); bq(x, 'lp', w.sr * 0.47, 0.7);
  return trim(x);
}

// Обработка под персонажа
const FX = {
  raw: x => x,
  ethan: x => { bq(x, 'hp', 85, 0.7); sat(x, 1.15); return freeverb(pad(x, 0.4), { room: 0.35, damp: 0.6, wet: 0.05 }); },
  ethan_soft: x => { bq(x, 'hp', 85, 0.7); x = breathy(x, 0.28, 1200, 6000); bq(x, 'lp', 7000, 0.7); return freeverb(pad(x, 0.5), { room: 0.4, damp: 0.6, wet: 0.06 }); },
  ethan_room: x => { bq(x, 'hp', 85, 0.7); x = breathy(x, 0.18); return freeverb(pad(x, 0.5), { room: 0.45, damp: 0.5, wet: 0.09 }); },
  whisper: x => { x = breathy(x, 0.78, 900, 5200); bq(x, 'lp', 5500, 0.7); return gain(fadeEdges(x), 0.8); },
  weak: x => { x = breathy(x, 0.62, 900, 5000); bq(x, 'lp', 5800, 0.7); sat(x, 1.25); return freeverb(pad(x, 0.6), { room: 0.5, damp: 0.6, wet: 0.08 }); },
  phone: x => {
    for (let k = 0; k < 2; k++) { bq(x, 'hp', 330, 0.8); bq(x, 'lp', 3300, 0.8); }
    bq(x, 'peak', 1700, 1.0, 5); sat(x, 1.9);
    const n = pink(x.length); bq(n, 'hp', 300, 0.7); bq(n, 'lp', 3000, 0.7); normRms(n);
    const r = rms(x);
    for (let i = 0; i < x.length; i++) x[i] = x[i] * (0.92 + 0.08 * Math.sin(TAU * 0.7 * i / SR)) + n[i] * r * 0.035;
    return x;
  },
  grandma: x => {
    let y = wowDelay(x, 2.0, 0.24, 5.4, 0.05, 11.0);
    for (let i = 0; i < y.length; i++) y[i] *= 1 + 0.09 * Math.sin(TAU * 5.4 * i / SR);
    y = breathy(y, 0.24, 1300, 6500); bq(y, 'lp', 7200, 0.7); bq(y, 'hp', 140, 0.7);
    return freeverb(pad(y, 0.5), { room: 0.42, damp: 0.55, wet: 0.08 });
  },
  mimic: x => {
    let y = wowDelay(x, 6.0, 1.3, 0.45, 0.18, 7.0);
    y = breathy(y, 0.3, 900, 4500);
    const s = subOctave(y, 150);
    for (let i = 0; i < y.length; i++) y[i] += s[i] * 0.6;
    bq(y, 'lp', 3600, 0.7);
    return freeverb(pad(y, 1.6), { room: 0.78, damp: 0.55, wet: 0.32, dry: 0.75 });
  },
  creature: x => {
    let y = speed(x, 0.84);
    const s = subOctave(y, 140);
    for (let i = 0; i < y.length; i++) {
      const t = i / SR, g = 0.7 + 0.3 * Math.sin(TAU * 26 * t + 2 * Math.sin(TAU * 2.7 * t));
      y[i] = y[i] * g + s[i] * 1.6;
    }
    y = breathy(y, 0.45, 600, 3500);
    sat(y, 2.6); bq(y, 'lp', 2400, 0.7); bq(y, 'peak', 160, 1.0, 6);
    const r = rattle(y.length / SR); for (let i = 0; i < y.length; i++) y[i] += r[i] * 0.25;
    return freeverb(pad(y, 1.0), { room: 0.55, damp: 0.7, wet: 0.16 });
  },
  crane: x => {
    let y = wowDelay(x, 2.0, 0.4, 6.8, 0.12, 13.0);
    y = breathy(y, 0.58, 800, 4600); sat(y, 1.35); bq(y, 'lp', 5000, 0.7); bq(y, 'hp', 110, 0.7);
    return freeverb(pad(y, 0.9), { room: 0.55, damp: 0.6, wet: 0.12 });
  },
  forest: x => {
    bq(x, 'hp', 220, 0.7); bq(x, 'lp', 1700, 0.7); bq(x, 'lp', 1700, 0.7);
    let y = breathy(x, 0.3, 500, 2500);
    y = delayAdd(delayAdd(y, 0.33, 0.32), 0.74, 0.2);
    return freeverb(pad(y, 3.0), { room: 0.95, damp: 0.7, wet: 0.7, dry: 0.4, pre: 0.06 });
  },
  shout: x => {
    bq(x, 'hp', 150, 0.7); bq(x, 'peak', 2600, 0.9, 7);
    const dbl = wowDelay(x, 14, 1.8, 0.35, 0, 1);
    for (let i = 0; i < x.length; i++) x[i] = x[i] + dbl[i] * 0.55;
    sat(x, 3.4); x = breathy(x, 0.2, 1500, 7000);
    return freeverb(pad(x, 0.8), { room: 0.5, damp: 0.5, wet: 0.16 });
  },
};

function buildVoice(v) {
  let x = FX[v.fx](ttsRaw(v.id));
  x = fadeEdges(trim(x, 0.0025, 0.08), 0.008, 0.08);
  const r = rms(x);
  gain(x, Math.pow(10, -19 / 20) / Math.max(r, 1e-6));
  let pk = 0; for (let i = 0; i < x.length; i++) pk = Math.max(pk, Math.abs(x[i]));
  if (pk > 0.89) gain(x, 0.89 / pk);
  return x;
}

// ══════════════════════════════════════════════════════════════════════════════
//  ЗВУКИ
// ══════════════════════════════════════════════════════════════════════════════
const SOUNDS = [];
function sound(name, sd, fn) { SOUNDS.push({ name, sd, fn }); }
const V = id => buildVoiceCache[id] || (buildVoiceCache[id] = FX.raw(ttsRaw(id)));
const buildVoiceCache = {};

// Удар копыта по дереву: щелчок рога + стук доски
function hoofWood(x, at, amp, muffled = false) {
  burst(x, at, 0.012, amp * 0.9, 'bp', 2400, 1.2, 0.003);
  modes(x, at, amp * 0.5, [[190, 0.06, 1], [410, 0.04, 0.6], [880, 0.025, 0.35], [1650, 0.012, 0.2]], 0.05);
  const th = buf(0.12); osc(th, 0, 0.12, t => 70 - 30 * t, t => Math.exp(-t / 0.03), [1]); add(x, th, at, amp * 0.6);
  if (rnd() < 0.5) creak(x, at + 0.02, 0.12, () => 90, [[620, 0.01, 1], [1300, 0.006, 0.5]], amp * 0.04);
  if (muffled) { /* фильтр снаружи */ }
}
function hoofGround(x, at, amp) {
  const th = buf(0.16); osc(th, 0, 0.16, t => 58 - 20 * t, t => Math.exp(-t / 0.04), [1, 0.3]); add(x, th, at, amp);
  burst(x, at, 0.05, amp * 0.35, 'bp', 900, 0.8, 0.015);
  particles(x, at, at + 0.12, () => 260, 1800, 6500, 0.0015, 0.004, () => amp * 0.06);
}
function stepGrass(x, at, amp) {
  const th = buf(0.1); osc(th, 0, 0.1, t => 75 - 30 * t, t => Math.exp(-t / 0.025), [1]); add(x, th, at, amp * 0.5);
  const n = white(N(0.32)); bqv(n, 'bp', t => 2600 + 1800 * t, 0.8); env(n, t => sstep(0, 0.02, t) * Math.exp(-t / 0.09)); add(x, n, at, amp * 0.25);
}

// Лай собаки за стеной: хриплые вспышки с формантами
function bark(x, at, amp, f0 = 520) {
  const d = rnd(0.13, 0.18), y = buf(d);
  osc(y, 0, d, t => f0 * (1.15 - 0.5 * t / d), t => sstep(0, 0.01, t) * Math.exp(-t / (d * 0.5)), [1, 0.8, 0.6, 0.45, 0.3, 0.2]);
  const n = white(y.length); env(n, t => Math.exp(-t / 0.05)); for (let i = 0; i < y.length; i++) y[i] = y[i] * 0.7 + n[i] * 0.4 * Math.exp(-i / SR / 0.05);
  const z = y.slice(); bq(y, 'bp', 900, 2.0); bq(z, 'bp', 1900, 2.5); for (let i = 0; i < y.length; i++) y[i] = y[i] + z[i] * 0.6;
  sat(y, 2.2); add(x, y, at, amp);
}
// Смех человека из телевизора: «ха-ха-ха» с падающим тоном
function laughVoice(x, at, amp, f0 = 150, n = 6, rate = 5.2) {
  for (let k = 0; k < n; k++) {
    const t0 = at + k / rate * rnd(0.92, 1.08), d = 0.11 * rnd(0.9, 1.2), f = f0 * (1.25 - 0.06 * k) * rnd(0.97, 1.03);
    const y = buf(d + 0.05);
    osc(y, 0.03, d, t => f * (1 - 0.15 * t / d), t => sstep(0, 0.015, t) * (1 - sstep(d * 0.6, d, t)), [1, 0.7, 0.5, 0.35, 0.25, 0.18, 0.12]);
    const h = white(y.length); env(h, t => (t < 0.05 ? sstep(0, 0.02, t) : Math.exp(-(t - 0.05) / 0.03)) * 0.5); bq(h, 'bp', 1500, 0.8);
    for (let i = 0; i < y.length; i++) y[i] += h[i];
    const z = y.slice(), w = y.slice(); bq(y, 'bp', 760, 3); bq(z, 'bp', 1250, 3.5); bq(w, 'bp', 2550, 4);
    for (let i = 0; i < y.length; i++) y[i] = y[i] + z[i] * 0.7 + w[i] * 0.35;
    add(x, y, t0, amp * Math.pow(0.88, k));
  }
}
function tvSpeaker(x) { bq(x, 'hp', 180, 0.7); bq(x, 'lp', 5200, 0.7); bq(x, 'peak', 2400, 1, 3); sat(x, 1.5); return x; }

// ─────────── Звонок ───────────
sound('amb_rain_window', 501, () => {
  const L = 14, X = 1.5, len = N(L + X);
  const chs = [0, 1].map(c => {
    const x = pink(len); bq(x, 'hp', 350, 0.7); bq(x, 'lp', 5200, 0.7); normRms(x); gain(x, 0.12);
    const w = wobble(len, 0.15); for (let i = 0; i < len; i++) x[i] *= 0.75 + 0.25 * w[i];
    particles(x, 0, L + X, () => 140, 2500, 7000, 0.002, 0.006, () => 0.05);
    particles(x, 0, L + X, () => 7, 700, 1600, 0.01, 0.03, () => 0.08);
    return loopXf(x, L, X);
  });
  return { chs, loop: true, peak: -6 };
});
sound('amb_apartment', 502, () => {
  const L = 10, X = 1.0, len = N(L + X), x = new Float32Array(len);
  osc(x, 0, L + X, () => 50, () => 0.05, [1, 0.6, 0.3, 0.2]);
  const n = brown(len); bq(n, 'lp', 300, 0.7); normRms(n); for (let i = 0; i < len; i++) x[i] += n[i] * 0.04;
  const h = pink(len); bq(h, 'hp', 2000, 0.7); bq(h, 'lp', 6000, 0.7); normRms(h); for (let i = 0; i < len; i++) x[i] += h[i] * 0.006;
  return { chs: mono2st(loopXf(x, L, X), 0.3), loop: true, peak: -14 };
});
sound('tv_show', 503, () => {
  // Сериал за кадром: реплики, смех зала, музыкальная перебивка — петля 16 с
  const L = 16, X = 1.0, x = buf(L + X);
  const lines = [['tv_1', 0.6], ['tv_2', 3.2], ['tv_3', 6.6], ['tv_4', 8.4]];
  for (const [id, t] of lines) add(x, V(id), t, 0.5);
  laughVoice(x, 5.2, 0.12, 170, 5); laughVoice(x, 5.25, 0.1, 210, 6);
  for (let k = 0; k < 14; k++) laughVoice(x, 11.0 + rnd(0, 0.3), 0.05, rnd(150, 280), 5 + Math.floor(rnd(0, 3)), rnd(4.5, 6));
  osc(x, 13.4, 2.2, t => [262, 330, 392][Math.floor(t * 3) % 3], t => 0.06 * sstep(0, 0.05, t) * (1 - sstep(1.8, 2.2, t)), [1, 0.4, 0.2]);
  tvSpeaker(x);
  const y = freeverb(x, { room: 0.45, damp: 0.6, wet: 0.12 });
  return { chs: mono2st(loopXf(y, L, X), 0.25), loop: true, peak: -8 };
});
sound('tv_laugh', 504, () => {
  const x = buf(3.2);
  laughVoice(x, 0.05, 0.6, 140, 7, 5.0);
  for (let k = 0; k < 18; k++) laughVoice(x, 0.35 + rnd(0, 0.4), 0.12, rnd(140, 300), 5 + Math.floor(rnd(0, 4)), rnd(4.4, 6.2));
  tvSpeaker(x);
  return { chs: mono2st(freeverb(x, { room: 0.45, damp: 0.6, wet: 0.14 }), 0.2), peak: -3 };
});
sound('dog_bark_wall', 505, () => {
  const x = buf(2.4);
  let t = 0.05; for (let k = 0; k < 3; k++) { bark(x, t, 0.7, rnd(480, 560)); t += rnd(0.28, 0.42); }
  bark(x, 1.6, 0.6, 500);
  bq(x, 'lp', 1100, 0.7); bq(x, 'lp', 1100, 0.7);
  return { chs: mono2st(freeverb(x, { room: 0.5, damp: 0.7, wet: 0.2 }), 0.3), peak: -4 };
});
sound('phone_vibrate', 506, () => {
  const x = buf(1.7);
  for (const [a, b] of [[0.0, 0.45], [0.75, 1.2]]) {
    osc(x, a, b - a, () => 170, t => sstep(0, 0.02, t) * (1 - sstep(b - a - 0.03, b - a, t)), [1, 0.5, 0.45, 0.3, 0.2, 0.15]);
    particles(x, a, b, () => 340, 1500, 4000, 0.001, 0.002, () => 0.05);
  }
  bq(x, 'hp', 120, 0.7);
  return { chs: mono2st(x), peak: -4 };
});
sound('phone_tap', 507, () => { const x = buf(0.08); click(x, 0.005, 0.8, 3500); modes(x, 0.005, 0.2, [[2400, 0.008, 1]]); return { chs: mono2st(x), peak: -8 }; });
sound('phone_line', 508, () => {
  const L = 6, X = 0.6, x = pink(N(L + X)); bq(x, 'hp', 300, 0.7); bq(x, 'lp', 3200, 0.7); normRms(x); gain(x, 0.05);
  return { chs: mono2st(loopXf(x, L, X)), loop: true, peak: -26 };
});
sound('heartbeat_slow', 509, () => {
  const L = 4.0, x = buf(L + 0.5);
  for (let k = 0; k < 4; k++) { const t = k * 1.0; for (const [o, a] of [[0, 1], [0.27, 0.7]]) { const y = buf(0.25); osc(y, 0, 0.25, tt => 55 - 25 * tt, tt => Math.exp(-tt / 0.05), [1, 0.4]); add(x, y, t + o, a); } }
  bq(x, 'lp', 160, 0.7);
  return { chs: mono2st(loopXf(x, L, 0.4)), loop: true, peak: -6 };
});

// ─────────── Ночь у дома ───────────
sound('amb_night_wind', 511, () => {
  const L = 16, X = 2, len = N(L + X);
  const chs = [0, 1].map(c => {
    const x = brown(len); bq(x, 'lp', 700, 0.7); normRms(x);
    const w = wobble(len, 0.12), w2 = wobble(len, 0.4);
    for (let i = 0; i < len; i++) x[i] *= 0.35 + 0.65 * (0.5 + 0.5 * w[i]) * (0.8 + 0.2 * w2[i]);
    const h = pink(len); bqv(h, 'bp', t => 900 + 500 * Math.sin(TAU * 0.07 * t + c), 3.5); normRms(h);
    for (let i = 0; i < len; i++) x[i] += h[i] * 0.08 * (0.5 + 0.5 * w[i]);
    particles(x, 0, L + X, () => 25, 2500, 6000, 0.002, 0.005, () => 0.03);
    return loopXf(gain(x, 0.3), L, X);
  });
  return { chs, loop: true, peak: -6 };
});
sound('hand_slide_wood', 512, () => {
  const x = buf(1.6), n = white(N(1.5));
  bq(n, 'bp', 1800, 0.8); env(n, t => sstep(0, 0.08, t) * (1 - sstep(1.2, 1.5, t)) * (0.6 + 0.4 * Math.sin(TAU * 3.1 * t)));
  add(x, n, 0.03, 0.25);
  for (let k = 0; k < 5; k++) click(x, 0.15 + k * 0.27 + rnd(-0.03, 0.03), 0.2, 2200);
  return { chs: mono2st(x, 0.2), peak: -8 };
});
for (let k = 1; k <= 4; k++) sound('step_grass_' + k, 512 + k, () => { const x = buf(0.45); stepGrass(x, 0.01, 0.9); return { chs: mono2st(x), peak: -6 }; });
for (let k = 1; k <= 4; k++) sound('hoof_wood_' + k, 520 + k, () => { const x = buf(0.4); hoofWood(x, 0.005, 0.9); return { chs: mono2st(freeverb(x, { room: 0.5, damp: 0.6, wet: 0.12 })), peak: -3 }; });
for (let k = 1; k <= 4; k++) sound('hoof_muffled_' + k, 524 + k, () => {
  const x = buf(0.5); hoofWood(x, 0.005, 0.9); bq(x, 'lp', 420, 0.7); bq(x, 'lp', 420, 0.7);
  const th = buf(0.2); osc(th, 0, 0.2, t => 50 - 20 * t, t => Math.exp(-t / 0.05), [1]); add(x, th, 0.005, 0.7);
  return { chs: mono2st(x), peak: -4 };
});
for (let k = 1; k <= 4; k++) sound('hoof_ground_' + k, 528 + k, () => { const x = buf(0.4); hoofGround(x, 0.005, 0.9); return { chs: mono2st(x), peak: -4 }; });
sound('stinger_hit', 533, () => {
  const x = buf(4.5);
  osc(x, 0, 2.5, t => 48 * Math.exp(-t * 0.5), t => Math.exp(-t / 0.7), [1, 0.5, 0.3]);
  burst(x, 0, 0.3, 0.8, 'lp', 2500, 0.7, 0.08);
  const s = white(N(2)); bqv(s, 'bp', t => 3200 - 1200 * t, 6); env(s, t => sstep(0, 0.02, t) * Math.exp(-t / 0.5)); add(x, s, 0.0, 0.25);
  modes(x, 0, 0.12, [[310, 1.2, 1], [733, 0.9, 0.6], [1517, 0.6, 0.4], [2911, 0.4, 0.25]], 0.01);
  return { chs: revSt(x, { room: 0.85, damp: 0.5, wet: 0.35 }), peak: -1 };
});
sound('creature_breath', 534, () => {
  const x = buf(2.6);
  add(x, breathSeg('in', 0.9, 0.7, 0.3), 0.05);
  add(x, breathSeg('out', 1.3, 1.0, 0.2), 1.05);
  const r = rattle(2.3); add(x, r, 0.15, 0.5);
  bq(x, 'lp', 2800, 0.7); bq(x, 'peak', 300, 1, 5);
  return { chs: mono2st(x, 0.2), peak: -3 };
});

// ─────────── Подвал ───────────
sound('amb_basement', 541, () => {
  const L = 14, X = 1.5, len = N(L + X);
  const chs = [0, 1].map(c => {
    const x = brown(len); bq(x, 'lp', 220, 0.7); normRms(x); gain(x, 0.08);
    for (let k = 0; k < 9; k++) { const t = rnd(0.2, L); ring(x, t, rnd(1300, 2600), rnd(0.02, 0.05), 0.08); ring(x, t + 0.012, rnd(800, 1100), 0.04, 0.03); }
    for (let k = 0; k < 2; k++) creak(x, rnd(1, L - 2), rnd(0.4, 0.9), u => 25 + 30 * u, [[420, 0.02, 1], [910, 0.012, 0.5]], 0.012);
    return loopXf(x, L, X);
  });
  return { chs: chs.map(x => freeverb(x, { room: 0.6, damp: 0.6, wet: 0.2 })), loop: true, peak: -12 };
});
sound('body_shift', 542, () => {
  const x = buf(1.4), n = white(N(1.2));
  bq(n, 'bp', 2400, 0.6); env(n, t => sstep(0, 0.1, t) * (1 - sstep(0.6, 1.2, t)) * (0.5 + 0.5 * wob(t))); add(x, n, 0.05, 0.3);
  const g = white(N(0.5)); bq(g, 'bp', 600, 1.5); env(g, t => sstep(0, 0.05, t) * Math.exp(-t / 0.15)); add(x, g, 0.4, 0.4);
  return { chs: mono2st(x, 0.2), peak: -8 };
});
function wob(t) { return Math.sin(TAU * 1.7 * t) * 0.5 + Math.sin(TAU * 4.3 * t) * 0.3; }
sound('ethan_groan', 543, () => {
  const x = buf(1.8);
  add(x, breathSeg('out', 1.4, 0.8, 0.5), 0.05);
  osc(x, 0.1, 1.2, t => 105 - 15 * t, t => 0.07 * sstep(0, 0.15, t) * (1 - sstep(0.8, 1.2, t)), [1, 0.6, 0.4, 0.3, 0.2]);
  bq(x, 'lp', 2500, 0.7);
  return { chs: mono2st(x), peak: -6 };
});
sound('ethan_gasp', 544, () => {
  const x = buf(1.1);
  add(x, breathSeg('in', 0.45, 1.0, 0.6), 0.02);
  add(x, breathSeg('out', 0.5, 0.5, 0.3), 0.55);
  return { chs: mono2st(x), peak: -5 };
});
sound('ethan_breath_held', 545, () => {
  const x = buf(3.2);
  add(x, breathSeg('in', 0.6, 0.6, 0.8), 0.02);
  add(x, breathSeg('out', 1.6, 0.35, 0.9), 1.4);
  return { chs: mono2st(x), peak: -9 };
});

// ─────────── Лаз ───────────
for (let k = 1; k <= 3; k++) sound('crawl_' + k, 550 + k, () => {
  const x = buf(0.7);
  const n = white(N(0.4)); bq(n, 'bp', rnd(500, 900), 1.0); env(n, t => sstep(0, 0.02, t) * Math.exp(-t / 0.1)); add(x, n, 0.02, 0.5);
  particles(x, 0.02, 0.35, () => 300, 900, 4000, 0.002, 0.006, t => 0.08 * Math.exp(-t / 0.15));
  const c = white(N(0.45)); bq(c, 'bp', 2800, 0.7); env(c, t => sstep(0, 0.05, t) * Math.exp(-t / 0.15)); add(x, c, 0.2, 0.12);
  return { chs: mono2st(x, 0.2), peak: -6 };
});
sound('dirt_trickle', 554, () => {
  const x = buf(2.0);
  particles(x, 0.0, 1.8, t => 400 * Math.exp(-t / 0.7), 800, 4000, 0.002, 0.008, t => 0.07 * Math.exp(-t / 0.8));
  return { chs: mono2st(x, 0.3), peak: -10 };
});
sound('lid_push', 555, () => {
  const x = buf(1.6);
  creak(x, 0.1, 1.0, u => 18 + 40 * u, [[230, 0.03, 1], [520, 0.02, 0.6], [1150, 0.01, 0.3]], 0.05);
  const th = buf(0.2); osc(th, 0, 0.2, t => 80 - 30 * t, t => Math.exp(-t / 0.05), [1]); add(x, th, 0.05, 0.6);
  particles(x, 0.3, 1.4, t => 200 * Math.exp(-t), 900, 4500, 0.002, 0.006, () => 0.05);
  add(x, breathSeg('out', 0.6, 0.6, 0.4), 0.15);
  return { chs: mono2st(x, 0.2), peak: -5 };
});
sound('lid_open', 556, () => {
  const x = buf(3.2);
  creak(x, 0.0, 1.2, u => 10 + 70 * u * u, [[260, 0.03, 1], [610, 0.02, 0.6], [1350, 0.01, 0.3]], 0.06);
  const n = white(N(1.8)); bqv(n, 'bp', t => 900 + 900 * t, 0.8); env(n, t => sstep(0, 0.2, t) * Math.exp(-t / 0.6)); add(x, n, 0.8, 0.25);
  particles(x, 0.9, 2.6, t => 500 * Math.exp(-t / 0.5), 600, 5000, 0.002, 0.008, t => 0.09 * Math.exp(-t / 0.6));
  const th = buf(0.3); osc(th, 0, 0.3, t => 70 - 30 * t, t => Math.exp(-t / 0.08), [1]); add(x, th, 1.3, 0.7);
  return { chs: mono2st(x, 0.25), peak: -3 };
});
sound('grass_rustle', 557, () => {
  const x = buf(1.6), n = white(N(1.5)); bqv(n, 'bp', t => 3000 + 1500 * Math.sin(TAU * 2 * t), 0.7);
  env(n, t => sstep(0, 0.1, t) * (1 - sstep(1.0, 1.5, t)) * (0.6 + 0.4 * Math.abs(Math.sin(TAU * 1.6 * t))));
  add(x, n, 0.02, 0.3);
  return { chs: mono2st(x, 0.3), peak: -8 };
});

// ─────────── Комната отца ───────────
sound('clock_tick', 561, () => {
  const L = 4.0, x = buf(L + 0.3);
  for (let k = 0; k < 8; k++) { const t = k * 0.5; click(x, t, k % 2 ? 0.5 : 0.7, 3200); modes(x, t, 0.12, [[1850, 0.03, 1], [3100, 0.02, 0.5], [620, 0.05, 0.3]], 0.03); }
  bq(x, 'lp', 6000, 0.7);
  return { chs: mono2st(freeverb(loopXf(x, L, 0.25), { room: 0.6, damp: 0.6, wet: 0.25 })), loop: true, peak: -8 };
});
sound('skull_lift', 562, () => {
  const x = buf(1.2);
  creak(x, 0.05, 0.35, () => 140, [[2300, 0.006, 1], [4100, 0.004, 0.5]], 0.05);
  modes(x, 0.05, 0.25, [[880, 0.06, 1], [1430, 0.04, 0.6], [2700, 0.02, 0.4]], 0.03);
  const n = white(N(0.6)); bq(n, 'bp', 1600, 0.8); env(n, t => sstep(0, 0.05, t) * Math.exp(-t / 0.2)); add(x, n, 0.3, 0.12);
  return { chs: mono2st(x, 0.2), peak: -8 };
});
sound('door_handle_slow', 563, () => {
  const x = buf(4.6);
  creak(x, 0.1, 3.6, u => 30 + 20 * Math.sin(u * 7), [[1450, 0.012, 1], [2900, 0.008, 0.6], [4300, 0.005, 0.35]], 0.04, 0.35, u => 0.4 + 0.6 * Math.sin(u * Math.PI));
  modes(x, 3.75, 0.5, [[1900, 0.05, 1], [3800, 0.03, 0.5], [760, 0.08, 0.4]], 0.02);
  click(x, 3.75, 0.6, 3000);
  return { chs: mono2st(freeverb(x, { room: 0.5, damp: 0.5, wet: 0.12 }), 0.2), peak: -5 };
});
sound('silence_drop', 564, () => {
  const x = buf(2.5);
  osc(x, 0, 2.4, t => 38, t => 0.4 * Math.exp(-t / 0.9), [1, 0.3]);
  const n = pink(N(0.6)); bq(n, 'lp', 900, 0.7); env(n, t => Math.exp(-t / 0.15)); add(x, n, 0, 0.3);
  return { chs: mono2st(x), peak: -10 };
});

// ─────────── Дом Крейна ───────────
sound('amb_crane_house', 571, () => {
  const L = 16, X = 2, len = N(L + X);
  const chs = [0, 1].map(c => {
    const x = brown(len); bq(x, 'lp', 500, 0.7); normRms(x); gain(x, 0.18);
    const w = wobble(len, 0.1); for (let i = 0; i < len; i++) x[i] *= 0.5 + 0.5 * w[i];
    const h = pink(len); bqv(h, 'bp', t => 1150 + 260 * Math.sin(TAU * 0.05 * t + c * 2), 9); normRms(h);
    for (let i = 0; i < len; i++) x[i] += h[i] * 0.05 * (0.4 + 0.6 * Math.max(0, w[i]));
    for (let k = 0; k < 3; k++) creak(x, rnd(0.5, L - 2), rnd(0.5, 1.2), u => 20 + 25 * u, [[310, 0.03, 1], [700, 0.02, 0.5]], 0.01);
    return loopXf(x, L, X);
  });
  return { chs, loop: true, peak: -9 };
});
sound('finger_dust', 572, () => {
  const L = 3.0, x = buf(L + 0.3);
  let t = 0.05;
  while (t < L) { const d = rnd(0.12, 0.35), n = white(N(d)); bq(n, 'bp', rnd(2500, 4200), 1.0); env(n, u => sstep(0, 0.02, u) * (1 - sstep(d - 0.03, d, u))); add(x, n, t, rnd(0.1, 0.18)); t += d + rnd(0.05, 0.25); }
  return { chs: mono2st(loopXf(x, L, 0.25), 0.2), loop: true, peak: -14 };
});
sound('strap_cut', 573, () => {
  const x = buf(0.9);
  const n = white(N(0.25)); bqv(n, 'bp', u => 2500 + 4000 * u, 1.2); env(n, u => sstep(0, 0.02, u) * Math.exp(-u / 0.08)); add(x, n, 0.02, 0.5);
  creak(x, 0.02, 0.2, () => 180, [[900, 0.006, 1], [1800, 0.004, 0.5]], 0.08);
  burst(x, 0.24, 0.04, 0.7, 'bp', 1400, 1.2, 0.01);
  return { chs: mono2st(x, 0.2), peak: -5 };
});
sound('body_slump', 574, () => {
  const x = buf(1.6);
  const th = buf(0.4); osc(th, 0, 0.4, t => 75 - 35 * t, t => Math.exp(-t / 0.08), [1, 0.4]); add(x, th, 0.12, 0.9);
  burst(x, 0.12, 0.2, 0.35, 'bp', 700, 0.8, 0.05);
  const c = white(N(0.8)); bq(c, 'bp', 2200, 0.6); env(c, t => sstep(0, 0.05, t) * Math.exp(-t / 0.25)); add(x, c, 0.0, 0.2);
  modes(x, 0.12, 0.15, [[180, 0.08, 1], [420, 0.05, 0.6]], 0.03);
  return { chs: mono2st(freeverb(x, { room: 0.5, damp: 0.6, wet: 0.12 }), 0.2), peak: -3 };
});
sound('drag_body', 575, () => {
  const x = buf(2.4), n = white(N(2.2));
  bq(n, 'bp', 900, 0.7); env(n, t => sstep(0, 0.1, t) * (1 - sstep(1.8, 2.2, t)) * (0.4 + 0.6 * Math.abs(Math.sin(TAU * 1.1 * t))));
  add(x, n, 0.05, 0.4);
  creak(x, 0.4, 1.4, () => 40, [[350, 0.02, 1], [790, 0.012, 0.5]], 0.02);
  return { chs: mono2st(x, 0.2), peak: -7 };
});
sound('sam_voiceless', 576, () => {
  // Сэм открывает рот — и ничего: сухой выдох с щелчком
  const x = buf(1.6);
  click(x, 0.05, 0.3, 2000);
  add(x, breathSeg('out', 0.8, 0.8, 0.9), 0.1);
  add(x, breathSeg('in', 0.5, 0.5, 0.9), 1.0);
  bq(x, 'lp', 4000, 0.7);
  return { chs: mono2st(x), peak: -8 };
});
sound('sam_sob', 577, () => {
  const x = buf(3.4);
  let t = 0.05; for (let k = 0; k < 5; k++) { add(x, breathSeg('in', rnd(0.18, 0.28), 0.8, 1.5), t); t += rnd(0.22, 0.32); }
  add(x, breathSeg('out', 1.0, 0.6, 1.2), t + 0.1);
  bq(x, 'lp', 4200, 0.7);
  return { chs: mono2st(x), peak: -9 };
});

// ─────────── Огонь и смерть Крейна ───────────
sound('fire_loop', 581, () => {
  const L = 8, X = 1, len = N(L + X);
  const chs = [0, 1].map(() => {
    const x = brown(len); bq(x, 'lp', 400, 0.7); normRms(x); gain(x, 0.25);
    const w = wobble(len, 1.2); for (let i = 0; i < len; i++) x[i] *= 0.7 + 0.3 * w[i];
    particles(x, 0, L + X, () => 22, 1500, 6000, 0.001, 0.004, () => 0.35);
    particles(x, 0, L + X, () => 4, 300, 900, 0.01, 0.03, () => 0.25);
    return loopXf(x, L, X);
  });
  return { chs, loop: true, peak: -6 };
});
sound('fire_ignite', 582, () => {
  const x = buf(2.4), n = white(N(2.2));
  bqv(n, 'lp', t => 300 + 3000 * sstep(0, 0.25, t) * Math.exp(-t / 1.2), 0.7);
  env(n, t => sstep(0, 0.08, t) * Math.exp(-t / 0.8)); add(x, n, 0.02, 0.8);
  osc(x, 0.02, 1.0, t => 55, t => 0.3 * sstep(0, 0.1, t) * Math.exp(-t / 0.4), [1, 0.5]);
  particles(x, 0.15, 2.2, t => 40 * Math.exp(-t), 1500, 6000, 0.001, 0.004, () => 0.3);
  return { chs: mono2st(x, 0.3), peak: -2 };
});
sound('fire_die', 583, () => {
  const x = buf(3.2), n = white(N(3));
  bqv(n, 'bp', t => 2500 - 1500 * t / 3, 0.8); env(n, t => Math.exp(-t / 0.9)); add(x, n, 0, 0.35);
  const h = white(N(2)); bq(h, 'hp', 4000, 0.7); env(h, t => sstep(0, 0.1, t) * Math.exp(-t / 0.7)); add(x, h, 0.1, 0.12);
  particles(x, 0.0, 3.0, t => 30 * Math.exp(-t), 1500, 5000, 0.001, 0.004, () => 0.2);
  osc(x, 0, 1.5, () => 45, t => 0.25 * Math.exp(-t / 0.5), [1]);
  return { chs: mono2st(x, 0.3), peak: -4 };
});
sound('window_smash', 584, () => {
  const x = buf(3.0);
  burst(x, 0.0, 0.08, 1.0, 'lp', 3000, 0.7, 0.02);
  modes(x, 0.0, 0.5, [[140, 0.15, 1], [330, 0.09, 0.8], [720, 0.05, 0.6], [1500, 0.03, 0.4]], 0.05);
  for (let k = 0; k < 14; k++) { const t = rnd(0.02, 0.9); modes(x, t, rnd(0.1, 0.3), [[rnd(300, 900), 0.04, 1], [rnd(1200, 2500), 0.02, 0.5]], 0.05); }
  particles(x, 0.05, 1.5, t => 180 * Math.exp(-t / 0.4), 1500, 7000, 0.001, 0.004, t => 0.15 * Math.exp(-t / 0.5));
  const th = buf(0.4); osc(th, 0, 0.4, t => 60 - 25 * t, t => Math.exp(-t / 0.1), [1]); add(x, th, 0, 0.8);
  return { chs: revSt(x, { room: 0.6, damp: 0.5, wet: 0.2 }), peak: -1 };
});
sound('chair_crash', 585, () => {
  const x = buf(2.2);
  modes(x, 0.0, 0.7, [[210, 0.1, 1], [470, 0.06, 0.8], [980, 0.03, 0.5]], 0.05);
  burst(x, 0.0, 0.05, 0.8, 'bp', 1800, 0.8, 0.015);
  for (let k = 0; k < 6; k++) { const t = rnd(0.1, 0.7); modes(x, t, rnd(0.2, 0.4), [[rnd(250, 600), 0.05, 1], [rnd(900, 1600), 0.025, 0.5]], 0.05); }
  return { chs: revSt(x, { room: 0.55, damp: 0.5, wet: 0.18 }), peak: -2 };
});
sound('skull_crack', 586, () => {
  const x = buf(2.0);
  burst(x, 0.0, 0.02, 1.0, 'hp', 1500, 0.7, 0.004);
  modes(x, 0.0, 0.5, [[1250, 0.03, 1], [2600, 0.02, 0.7], [4400, 0.012, 0.5]], 0.03);
  burst(x, 0.09, 0.015, 0.7, 'hp', 1800, 0.7, 0.003);
  const n = white(N(1.5)); bqv(n, 'lp', t => 4000 * Math.exp(-t / 0.4) + 300, 0.7); env(n, t => sstep(0, 0.02, t) * Math.exp(-t / 0.5)); add(x, n, 0.05, 0.5);
  particles(x, 0.1, 1.6, t => 60 * Math.exp(-t / 0.5), 1800, 6000, 0.001, 0.004, () => 0.3);
  return { chs: mono2st(x, 0.25), peak: -2 };
});
sound('skin_slide', 587, () => {
  const x = buf(4.6);
  const n = white(N(4.2)); bqv(n, 'bp', t => 700 + 300 * Math.sin(TAU * 0.8 * t), 1.2);
  env(n, t => sstep(0, 0.4, t) * (1 - sstep(3.4, 4.2, t)) * (0.5 + 0.5 * Math.abs(Math.sin(TAU * 0.9 * t)))); add(x, n, 0.1, 0.4);
  for (let k = 0; k < 26; k++) { const t = rnd(0.2, 4.2), y = buf(0.12); osc(y, 0, 0.12, u => rnd(250, 500) * (1 + 3 * u), u => Math.exp(-u / 0.03), [1]); add(x, y, t, rnd(0.08, 0.2)); }
  for (let k = 0; k < 10; k++) ring(x, rnd(0.5, 4.3), rnd(900, 1800), 0.02, 0.12);
  const th = buf(0.5); osc(th, 0, 0.5, t => 55 - 20 * t, t => Math.exp(-t / 0.12), [1]); add(x, th, 3.6, 0.7);
  return { chs: mono2st(freeverb(x, { room: 0.5, damp: 0.6, wet: 0.12 }), 0.2), peak: -3 };
});
sound('kneel_thud', 588, () => {
  const x = buf(1.0);
  for (const t of [0.02, 0.17]) { const th = buf(0.3); osc(th, 0, 0.3, u => 70 - 30 * u, u => Math.exp(-u / 0.06), [1, 0.4]); add(x, th, t, 0.8); modes(x, t, 0.2, [[200, 0.07, 1], [460, 0.04, 0.6]], 0.03); }
  return { chs: mono2st(freeverb(x, { room: 0.5, damp: 0.6, wet: 0.12 })), peak: -3 };
});
sound('ash_crumble', 589, () => {
  const x = buf(4.2);
  particles(x, 0.0, 3.6, t => 900 * sstep(0, 0.6, t) * Math.exp(-t / 1.6), 900, 6500, 0.002, 0.006, () => 0.05);
  const n = pink(N(3.6)); bq(n, 'bp', 1800, 0.5); env(n, t => sstep(0, 0.5, t) * Math.exp(-t / 1.4)); add(x, n, 0.05, 0.18);
  const th = buf(0.6); osc(th, 0, 0.6, t => 50 - 15 * t, t => Math.exp(-t / 0.2), [1]); add(x, th, 1.2, 0.4);
  return { chs: mono2st(freeverb(x, { room: 0.6, damp: 0.6, wet: 0.2 }), 0.3), peak: -6 };
});
sound('freeze_hit', 590, () => {
  // Существо замирает: короткий удар и обрыв
  const x = buf(2.6);
  osc(x, 0, 1.8, t => 42, t => Math.exp(-t / 0.5), [1, 0.4]);
  burst(x, 0, 0.12, 0.6, 'lp', 1500, 0.7, 0.04);
  modes(x, 0, 0.15, [[523, 1.2, 1], [1046, 0.8, 0.4], [1570, 0.5, 0.25]], 0.002);
  return { chs: revSt(x, { room: 0.9, damp: 0.4, wet: 0.3 }), peak: -2 };
});
sound('creature_lunge', 591, () => {
  const x = buf(2.2);
  add(x, breathSeg('out', 0.9, 1.0, 0.4), 0.0);
  const r = rattle(1.4); add(x, r, 0.0, 0.9);
  for (let k = 0; k < 4; k++) hoofWood(x, 0.15 + k * 0.17, 0.8);
  bq(x, 'peak', 250, 1, 6);
  return { chs: revSt(x, { room: 0.5, damp: 0.6, wet: 0.15 }), peak: -1 };
});

// ─────────── Рассвет ───────────
sound('amb_dawn', 601, () => {
  const L = 18, X = 2, len = N(L + X);
  const chs = [0, 1].map(c => {
    const x = brown(len); bq(x, 'lp', 450, 0.7); normRms(x); gain(x, 0.06);
    const w = wobble(len, 0.08); for (let i = 0; i < len; i++) x[i] *= 0.6 + 0.4 * w[i];
    // Птицы: короткие трели в разных местах
    for (let k = 0; k < 16; k++) {
      const t0 = rnd(0.2, L), f = rnd(2800, 4800), n = 2 + Math.floor(rnd(0, 6)), a = rnd(0.03, 0.1) * (c === (k % 2) ? 1 : 0.5);
      for (let j = 0; j < n; j++) osc(x, t0 + j * rnd(0.07, 0.12), 0.06, u => f * (1 + 0.25 * Math.sin(TAU * 30 * u)) * (1 - 0.3 * u / 0.06), u => a * Math.sin(Math.PI * u / 0.06), [1, 0.15]);
    }
    return loopXf(x, L, X);
  });
  return { chs: chs.map(x => freeverb(x, { room: 0.8, damp: 0.4, wet: 0.2 })), loop: true, peak: -10 };
});
sound('sheet_flutter', 602, () => {
  const L = 6, X = 0.8, len = N(L + X), x = white(len);
  bq(x, 'bp', 1400, 0.6); normRms(x);
  const w = wobble(len, 2.2), w2 = wobble(len, 0.3);
  for (let i = 0; i < len; i++) x[i] *= 0.05 * Math.max(0, 0.3 + w[i]) * (0.6 + 0.4 * w2[i]);
  return { chs: mono2st(loopXf(x, L, X), 0.3), loop: true, peak: -16 };
});

// ─────────── Финал на заправке ───────────
sound('money_counter', 611, () => {
  const x = buf(1.4);
  const n = white(N(0.35)); bq(n, 'bp', 3500, 0.8); env(n, t => sstep(0, 0.02, t) * Math.exp(-t / 0.08)); add(x, n, 0.05, 0.3);
  for (const t of [0.5, 0.62, 0.7]) { click(x, t, 0.4, 4000); modes(x, t, 0.2, [[3900, 0.08, 1], [6100, 0.05, 0.6], [2300, 0.06, 0.3]], 0.03); }
  return { chs: mono2st(freeverb(x, { room: 0.4, damp: 0.5, wet: 0.1 }), 0.2), peak: -6 };
});

// ─────────── Плохая концовка ───────────
sound('skull_drop', 621, () => {
  const x = buf(2.2);
  modes(x, 0.02, 0.6, [[620, 0.05, 1], [1340, 0.03, 0.6], [2700, 0.015, 0.35], [190, 0.08, 0.5]], 0.03);
  const th = buf(0.2); osc(th, 0, 0.2, t => 90 - 40 * t, t => Math.exp(-t / 0.04), [1]); add(x, th, 0.02, 0.6);
  for (let k = 0; k < 6; k++) { const t = 0.25 + k * 0.12 * Math.pow(0.85, k); modes(x, t, 0.12 * Math.pow(0.8, k), [[640, 0.03, 1], [1400, 0.02, 0.5]], 0.05); }
  const r = white(N(1.2)); bq(r, 'bp', 900, 0.8); env(r, t => sstep(0, 0.05, t) * Math.exp(-t / 0.4)); add(x, r, 0.3, 0.12);
  return { chs: mono2st(freeverb(x, { room: 0.5, damp: 0.6, wet: 0.14 }), 0.2), peak: -3 };
});
sound('voices_outside', 622, () => {
  // Голоса за стенами: отец и Сэм сразу, с разных сторон; обрываются по сценарию
  const x = buf(7.0), y = buf(7.0);
  add(x, FX.mimic(V('bed_father')), 0.0, 0.8);
  add(y, FX.mimic(V('bed_sam')), 0.6, 0.8);
  add(x, FX.mimic(V('bed_father2')), 3.6, 0.6);
  add(y, FX.mimic(V('bed_father')), 4.2, 0.4);
  for (const z of [x, y]) { bq(z, 'lp', 3000, 0.7); }
  return { chs: [x, y], peak: -4 };
});
sound('chair_scrape', 623, () => {
  const x = buf(2.0);
  creak(x, 0.05, 1.2, u => 28 + 40 * u, [[180, 0.03, 1], [420, 0.02, 0.6], [950, 0.01, 0.3]], 0.05);
  const n = white(N(1.2)); bq(n, 'bp', 700, 0.8); env(n, t => sstep(0, 0.05, t) * (1 - sstep(1.0, 1.2, t))); add(x, n, 0.05, 0.15);
  const th = buf(0.3); osc(th, 0, 0.3, t => 65 - 25 * t, t => Math.exp(-t / 0.08), [1]); add(x, th, 1.35, 0.7);
  return { chs: mono2st(freeverb(x, { room: 0.55, damp: 0.6, wet: 0.16 }), 0.2), peak: -4 };
});
sound('drone_family', 624, () => {
  const L = 12, X = 2, len = N(L + X);
  const chs = [0, 1].map(c => {
    const x = new Float32Array(len);
    osc(x, 0, L + X, t => 41.2 * (1 + 0.004 * Math.sin(TAU * 0.11 * t + c)), () => 0.25, [1, 0.5, 0.25, 0.12]);
    osc(x, 0, L + X, t => 61.7 * (1 + 0.006 * Math.sin(TAU * 0.07 * t)), () => 0.12, [1, 0.3]);
    const n = pink(len); bqv(n, 'bp', t => 700 + 300 * Math.sin(TAU * 0.05 * t + c), 6); normRms(n);
    for (let i = 0; i < len; i++) x[i] += n[i] * 0.03;
    return loopXf(x, L, X);
  });
  return { chs, loop: true, peak: -8 };
});

// ══════════════════════════════════════════════════════════════════════════════
//  Запуск
// ══════════════════════════════════════════════════════════════════════════════
fs.mkdirSync(OUT, { recursive: true });
fs.mkdirSync(VOUT, { recursive: true });
const only = process.argv.slice(2);
renderTTS(VOICES);
for (const v of VOICES) {
  if (v.fx === 'raw') continue;
  if (only.length && !only.includes(v.id)) continue;
  seed(900 + VOICES.indexOf(v));
  const x = buildVoice(v);
  writeWav(VOUT, v.id, [x], false);
  console.log(`voice ${v.id.padEnd(18)} ${(x.length / SR).toFixed(2)}s`);
}
for (const s of SOUNDS) {
  if (only.length && !only.includes(s.name)) continue;
  seed(s.sd);
  const t0 = Date.now();
  const r = s.fn();
  if (!r.loop) for (const c of r.chs) hp1(c, 18);
  norm(r.chs, r.peak ?? -1);
  writeWav(OUT, s.name, r.chs, r.loop);
  console.log(`${s.name.padEnd(20)} ${(r.chs[0].length / SR).toFixed(2)}s ${r.chs.length}ch${r.loop ? ' loop' : ''}  ${Date.now() - t0} ms`);
}
