# All Uzbekistan ilova API (v1)

Server: `/opt/alluz/src/pages/app.js` (Node, faqat o'qish). Baza URL: `https://alluzbekistan.com`.
Til — yo'l prefiksi: `uz` → `/api/app/v1/...`, `ru` → `/ru/api/app/v1/...`, `en` → `/en/api/app/v1/...`
(ilovada `API.shared.get("home")` o'zi qo'yadi). Xato: `{"error": "type"|"not_found"}` + 404.

## Umumiy turlar
**Img** `{u, w, h, focus, title, author, license, licenseUrl, source, sourceName}` — URL: `site + u + "-" + W + ".webp"`,
W ∈ 480/960/1600/2400 (`Img.url(for:)`). Rasm ostida muallif/litsenziya ko'rsatilishi SHART (CC) — `CreditLine(img:)`.

**Card** `{type, slug, name, sub, kicker, summary, icon, kind, region, rating, unesco, lat, lon, img, web}`
- `sub` — «Tur · Hudud» (tayyor matn), `kicker` — qisqa shior, `summary` — ≤160 belgi.
- `type`: region, district, place, venue, org, bank, post, airport, rail_station, train, bus_station, bus_route, city_transport,
  metro, person, era, hist_event, cuisine, craft, tradition, holiday, fest, guide, route.
- `kind`: place → category (ansambl, madrasa, masjid, maqbara, minora, ziyoratgoh, qala, arxeologiya, muzey, ibodatxona, bog,
  kongilochar, madaniyat, bozor, tabiat, dam-olish, zamonaviy); venue → hotel/guesthouse/hostel/resort (stay),
  restaurant/cafe/choyxona/osh/fastfood (eat); person → field; district → type (shahar/tuman).

## Endpointlar
| Yo'l | Javob |
|---|---|
| `config` | `{site, langs, imgWidths, ios{minBuild, latestBuild, storeUrl}, counts{type: n}, links{privacy, about, photos}}` |
| `home` | `{hero[Card], regions[Card], top[Card], unesco[Card], routes[Card], fests[Card], persons[Card], cuisine[Card], guides[Card], airports[{iata, slug, name, city, region}]}` |
| `list/:type?region=&district=&kind=&unesco=1&q=&sort=name&offset=&limit=` | `ListPage {type, total, offset, limit, kinds{kind: n}, kindLabels{kind: matn}, items[Card]}` (limit ≤ 200; standart saralash — reyting, rasmlilar oldin; person — tug'ilgan yil; route — kunlar) |
| `item/:type/:slug` | `Item` — Card maydonlari + `text`, `data`, `images[Img]`, `refs{maydon: [Card]}`, `regionName`, `districtName`; region/district: `sections{places, stay, eat, persons, districts}`, `counts{places, venues, orgs}`; era: `sections{events: [Item]}` |
| `item/culture/:slug` | `/madaniyat/:slug` uchun — server turini o'zi topadi (javobdagi `type` haqiqiysi) |
| `search?q=` | `{q, items[Card]}` (≤40; ba'zi natijalarda slug=null, faqat `web`) |
| `map?types=place,venue` | `{fields, points: [[type, slug, lat, lon, name, kind, region, img0/1, rating]]}` (`MapData.parsed`) |

### Item.text (tildagi matn, turga qarab)
`name`, `kicker`, `summary`, `body: [{h, p: [..]}]`, ba'zi turlarda `tips[]`, `facts`, `role`, `title`, `lead`, `city`,
`short`… — `item.text["tips"]?.strings`, `item.body`.

### Item.data (turga xos, tilga tushirilgan)
place: `category, district, coords, era, built, unesco, rating, duration_min, hours, ticket, address, related, sources`
venue: `kind, address, phones[], website, telegram, instagram, email, stars, price, cuisine[], features[], hours, checkin, checkout, rooms, opened`
region: `iso, capital, name, center, area_km2, population, population_year, founded`
district: `type, center, coords, area_km2, population`
person: `born, died, regions[], field, places[]`
airport: `iata, icao, website, phones[], telegram`
org/bank: `kind, level, address, phones[], hotline, website, telegram, email, hours, swift, mfo, apps[{name, ios, android}], hq{…}`
route: `days, regions[], theme, best_season[oy], stops[{day, place, region, text}]`
fest: `regions[], recurring, month, start, end, place`
Hammasida: `sources[]` (manba havolalari — «Manbalar» bo'limi).
Namuna javoblar: `docs/samples/*.json`. Jonli tekshirish: `curl -s https://alluzbekistan.com/en/api/app/v1/item/place/registon | jq`.

## Saytning boshqa API'lari (tayyor, ilova ham ishlatadi)
- `GET /api/board?airport=TAS&dir=dep|arr&day=yesterday|today|tomorrow` — aeroport tablosi (`flights[]`: key, flight, airline{code,name},
  other{iata, city}, scheduled, estimated, actual, status, statusText, statusLabel, terminal, gate, desks, belt, aircraft, codeshares)
- `GET /api/board/status`, `GET /api/flight?…`, `GET /api/rail-board?…` — transport moduli (`/opt/alluz/src/pages/transport.js`)
- Bo'lim agentlari qo'shadigan: `/api/app/v1/weather…`, `/api/app/v1/currency…`, `/api/app/v1/visa…`, `/api/app/v1/post…`,
  `/api/app/v1/gov…`, `/api/app/v1/distances…` — har biri o'z faylida `/opt/alluz/src/pages/app-<bo'lim>.js` (pastda).

## Yangi server endpoint qo'shish (bo'lim agentlari)
- Fayl: `/opt/alluz/src/pages/app-<bo'lim>.js`, `export const routes = [{ path: '/api/app/v1/<bo'lim>…', handler }]`. Mavjud sahifa
  modulidan (weather.js, banks.js …) faqat import qiling — ularni o'zgartirish kerak bo'lsa, minimal `export` qo'shish mumkin.
- Javob `{ json, cacheControl: 'public, max-age=300' }`, tashqi manbaga so'rov — modulning mavjud keshidan.
- Sinov: o'z nusxangizda — `PORT=48xx NODE_ENV=development ALLUZ_NO_SERVICES=1 ALLUZ_DATA=<scratch nusxa> node src/server.js`
  (baza nusxasi: `sqlite3 /opt/alluz/data/alluz.db ".backup <scratch>/alluz.db"`). Jonli serverni (pm2 alluz) QAYTA ISHGA TUSHIRMANG
  va `_ready.json` ga tegmang — koordinator tekshirib, jonliga chiqaradi.

## Viza — `/opt/alluz/src/pages/app-visa.js` (mantiq: visa.js, maʼlumot: content/visa/*.json)
| Yo'l | Javob |
|---|---|
| `visa` | `{asof, asofText, counts{visa_free, evisa, visa_required, special, total}, modes{mode: matn}, countries[VisaCountry], guide: Card?, web}` — davlatlar tildagi nom bo'yicha saralangan |
| `visa/:code` (ISO-2, katta-kichik farqsiz) | `VisaCountry` + `{modeLabel, headline, title, unit, note, since, sinceText, special, lead[], conditions[], stepsTitle, steps[], notes[], evisaUrl, evisaLabel, embassiesUrl, embassiesLabel, after{title, items[], sources[]}, customs{…}, sourcesTitle, sources[{key, kind, number, date, title, edition, url}], contactsTitle, contacts[{id, icon, name, role, phones[{label, value, tel}], emails[], telegram, website, links[{label, url}], address, note, sources[]}], rulesTitle, rules[{id, icon, title, items[{text, sources[{label, url}]}]}], visaTypes{title, lead, items[{code, name, term}], note, sources[]}?, warning{title, text}, same[{code, name, flag}], asof, asofText, guide: Card?, web}`; noma'lum kod — 404 |

**VisaCountry** `{code, name, flag, mode: visa_free|evisa|visa_required|special, days, unlimited, big: "30"|"∞"|null, term: «30 kungacha», transit, key}`
(`key` — kod + uch tildagi nom + muqobil nomlar, kichik harf, apostrofsiz — ilova o'zi qidiradi). Barcha havolalar `https://`.

## Pochta indekslari — `/opt/alluz/src/pages/app-post.js` (mantiq: post.js data/find)
| Yo'l | Javob |
|---|---|
| `post` | `{total, active, withCoords, regions[{slug, name, count, active, prefix, min, max, checked}], soon[{slug, name}], callCenter: "1165", callCenterLabel, web}` — hududlar indeks tartibida |
| `post/:region?q=` | `{region{slug, name, count, active, prefix, min, max}, q, groups[{key, name, type: shahar|tuman|null, count, items[PostOffice]}], items[], web}`; `q` bilan — `{mode, total, items[PostOffice] (≤80), groups: []}` |
| `post-search?q=` | `{q, mode: index|dup|near|prefix|text|empty, total, items[PostOffice] (≤80)}` — 6 raqam: aniq indeks (topilmasa `near` — eng yaqinlari), 1–5 raqam: boshlanishi, matn: aholi punkti/tuman/manzil |

**PostOffice** `{type: "post", slug, index, name, settlement, address, kind: pochtamt|bolim|agentlik|boshqa, kindLabel, status: faol|binosiz|yopiq|arxiv, statusLabel (faol — null), region, regionName, district, districtName, hours, phones[], lat, lon, web}`.
Bitta bo'lim to'liq — `item/post/:slug`.

## Davlat idoralari — `/opt/alluz/src/pages/app-gov.js` (mantiq: gov.js data, sayt /davlat-idoralari bilan bir xil filtr)
`gov?region=&district=&kind=&level=&q=&offset=&limit=` (limit ≤ 200, standart 60) →
`{total, nRep, nRegions, nDistricts, filter{region, district, kind, level, q}, emergency[{num, tel, icon, label, sub}], hotlines[{num, tel, icon, kind, count, label, sub, slug}], regions[{slug, name, count}], districts[{slug, name, type, count}] (region bo'lsa), kinds[{kind, label, icon, rep, count}] (joriy doirada), levels[{level, label, count}], rep[Card] (filtrsiz — respublika idoralari), results{total, offset, limit, sections[{key, title, items[Card]}]} | null (filtr bo'lmasa), web}`
- `emergency`: 112, 101, 102, 103, 104, 1050, 1173 (manba: qo'llanma `xavfsizlik-va-favqulodda-raqamlar`, FVV yozuvi, viza qoidalari «tourism»).
- `hotlines` — idoralar ma'lumotidan (gov.js, eng ko'p ishlatiladigan qisqa raqamlar), favqulodda raqamlar takrorlanmaydi.
- Card (org): `sub` — «Tur · shahar/tuman (yoki «Respublika darajasi»)», `icon` — tur belgisi (sayt nomi), `kind` — tur.
- Hudud tanlansa respublika idoralari chiqmaydi; tur tanlanmasa respublika idoralari faqat qidiruvda yoki `level=respublika` da.
