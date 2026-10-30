// iOS ilova ikonkasi (1024: yorug' / qorong'i / tusli), ochilish belgisi va ranglar — sayt belgisi (favicon.svg): sakkiz qirrali
// yulduz (ikki kvadrat, 45° burilgan) va markazdagi halqa — o'zbek naqshi (girih). Foydalanish: node tools/appicon.mjs
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
const require = createRequire('/opt/sam/package.json');
const sharp = require('sharp');
const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const A = path.join(ROOT, 'AllUz/Resources/Assets.xcassets');

// Yulduz: 1024 maydonda markaz 512, kvadrat tomoni 470
const star = (stroke, w = 52, ring = stroke, fillCenter = 'none') => `<g fill="none" stroke="${stroke}" stroke-width="${w}" stroke-linejoin="round">
  <rect x="277" y="277" width="470" height="470"/>
  <rect x="277" y="277" width="470" height="470" transform="rotate(45 512 512)"/>
</g><circle cx="512" cy="512" r="96" fill="${fillCenter}" stroke="${ring}" stroke-width="${w}"/>`;
const svg = (bg, body) => `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">${bg}${body}</svg>`;
const grad = (a, b) => `<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${a}"/><stop offset="1" stop-color="${b}"/></linearGradient></defs><rect width="1024" height="1024" fill="url(#g)"/>`;

const set = path.join(A, 'AppIcon.appiconset');
fs.mkdirSync(set, { recursive: true });
const png = (s, file) => sharp(Buffer.from(s)).resize(1024, 1024).flatten({ background: '#000000' }).png().toFile(file);
await png(svg(grad('#C9553A', '#8E3220'), star('#F6F1E8', 52, '#E9C27A', '#E9C27A33')), path.join(set, 'AppIcon.png'));
await png(svg(grad('#24201C', '#121110'), star('#E2805F', 52, '#D6B46B', '#D6B46B22')), path.join(set, 'AppIcon-dark.png'));
await png(svg('<rect width="1024" height="1024" fill="#000000"/>', star('#EDEDED', 52, '#EDEDED')), path.join(set, 'AppIcon-tinted.png'));
fs.writeFileSync(path.join(set, 'Contents.json'), JSON.stringify({ images: [
  { filename: 'AppIcon.png', idiom: 'universal', platform: 'ios', size: '1024x1024' },
  { appearances: [{ appearance: 'luminosity', value: 'dark' }], filename: 'AppIcon-dark.png', idiom: 'universal', platform: 'ios', size: '1024x1024' },
  { appearances: [{ appearance: 'luminosity', value: 'tinted' }], filename: 'AppIcon-tinted.png', idiom: 'universal', platform: 'ios', size: '1024x1024' },
], info: { author: 'xcode', version: 1 } }, null, 2));

// Ochilish belgisi: terrakota dumaloq kvadratda yulduz, 1x/2x/3x — 96 pt
const logo = path.join(A, 'LaunchMark.imageset');
fs.mkdirSync(logo, { recursive: true });
const mark = svg(`<rect width="1024" height="1024" rx="230" fill="#B2432A"/>`, star('#F6F1E8', 52, '#E9C27A'));
for (const [s, n] of [[1, 'LaunchMark.png'], [2, 'LaunchMark@2x.png'], [3, 'LaunchMark@3x.png']])
  await sharp(Buffer.from(mark)).resize(96 * s, 96 * s).png().toFile(path.join(logo, n));
fs.writeFileSync(path.join(logo, 'Contents.json'), JSON.stringify({ images: [
  { filename: 'LaunchMark.png', idiom: 'universal', scale: '1x' }, { filename: 'LaunchMark@2x.png', idiom: 'universal', scale: '2x' },
  { filename: 'LaunchMark@3x.png', idiom: 'universal', scale: '3x' },
], info: { author: 'xcode', version: 1 } }, null, 2));
// Ilova ichida ham (Onboarding, Haqida): «BrandMark»
const bm = path.join(A, 'BrandMark.imageset');
fs.mkdirSync(bm, { recursive: true });
for (const [s, n] of [[1, 'BrandMark.png'], [2, 'BrandMark@2x.png'], [3, 'BrandMark@3x.png']])
  await sharp(Buffer.from(mark)).resize(120 * s, 120 * s).png().toFile(path.join(bm, n));
fs.writeFileSync(path.join(bm, 'Contents.json'), JSON.stringify({ images: [
  { filename: 'BrandMark.png', idiom: 'universal', scale: '1x' }, { filename: 'BrandMark@2x.png', idiom: 'universal', scale: '2x' },
  { filename: 'BrandMark@3x.png', idiom: 'universal', scale: '3x' },
], info: { author: 'xcode', version: 1 } }, null, 2));

const rgb = (hex) => { const v = hex.replace('#', ''); return { red: `0x${v.slice(0, 2)}`, green: `0x${v.slice(2, 4)}`, blue: `0x${v.slice(4, 6)}`, alpha: '1.000' }; };
const color = (name, light, dark) => {
  const d = path.join(A, `${name}.colorset`);
  fs.mkdirSync(d, { recursive: true });
  fs.writeFileSync(path.join(d, 'Contents.json'), JSON.stringify({ colors: [
    { color: { 'color-space': 'srgb', components: rgb(light) }, idiom: 'universal' },
    { appearances: [{ appearance: 'luminosity', value: 'dark' }], color: { 'color-space': 'srgb', components: rgb(dark) }, idiom: 'universal' },
  ], info: { author: 'xcode', version: 1 } }, null, 2));
};
color('AccentColor', '#B2432A', '#E2805F');
color('LaunchBackground', '#F6F1E8', '#141311');
fs.writeFileSync(path.join(A, 'Contents.json'), JSON.stringify({ info: { author: 'xcode', version: 1 } }, null, 2));
fs.mkdirSync(path.join(ROOT, 'docs'), { recursive: true });
fs.copyFileSync(path.join(set, 'AppIcon.png'), path.join(ROOT, 'docs/icon-1024.png'));
console.log('tayyor');
