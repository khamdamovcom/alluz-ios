# All Uzbekistan — iOS ilova

alluzbekistan.com ning native iOS ilovasi (SwiftUI, iOS 17+, iOS 26 da Liquid Glass). Uch til (uz/ru/en), oflayn kesh,
TLS pin (Let's Encrypt ildizlari), kuzatuv/reklama/hisob yo'q.

- Kod: `AllUz/` — `App/` (kirish, navigatsiya, holat), `Data/` (API, modellar, til), `UI/` (dizayn tizimi), `Screens/<bo'lim>/`.
- Server API: `docs/API.md` (`/opt/alluz/src/pages/app.js`), ishlab chiqish qoidalari: `docs/BRIEF.md`.
- Tekshirish (serverda, Mac'siz): `bash scripts/typecheck.sh`.
- CI (`.github/workflows/ios.yml`, macOS): har push — simulyator yig'ish; qo'lda `gh workflow run iOS -f mode=shots -f list="tab:home=home …"`
  — skrinshotlar (artifact `shots`), `-f mode=release` — App Store Connect (TestFlight).
- Ikonka va ranglar: `node tools/appicon.mjs`.
