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

## Masofalar (`/opt/alluz/src/pages/app-distances.js`, Xarita agenti)
Hisob — sayt moduli `src/pages/distances.js` (`appApi` eksporti): OSRM yo'l matritsasi (`content/distances/road.json`), to'g'ri chiziq (haversine),
mashhur juftliklar yo'l chizig'i (`routes.json`), poyezdlar (store `train`), reyslar (tablo keshi), avtobuslar (store `bus_route`). Slug'lar sayt
`/masofalar/<a>-<b>` bilan bir xil (slug'da defis yo'q).
| Yo'l | Javob |
|---|---|
| `distances` | `{cities: [City], popular: [{pair, from, to, fromName, toName, km, min}], source{road, attribution, license, fetched}}` (28 shahar, `order` bo'yicha) |
| `distances/:a-:b` yoki `distances?from=a&to=b` | `{pair, canonical, from: City, to: City, road{km, min}, air{km}, line: [[lat, lon]]\|null, train, plane, bus, web, source}` — a → b yo'nalishida (teskarisi ham ishlaydi; `canonical` — sayt URL'i tartibi). Noto'g'ri/bir xil shahar → 404 `{"error":"not_found"}` |

- **City** `{id, name, region, regionName, lat, lon, tier: "a"|"b", iata|null, rail: bool, order}`
- **train** `{available, count, fastest: Train|null, list: [Train] (≤40), noStation?, nearest?{slug, name, km}}`;
  **Train** `{slug, number, title, type: highspeed|fast|night|passenger|suburban|null, dep "HH:mm", arr, plusDay, min, from, to, days}` (`item/train/:slug`)
- **plane** `{from{iata, own, km}|null, to, noAirport: slug|null, same, count (bugun+ertaga to'g'ri reyslar), min|null, hasData}`
- **bus** `{count, daily, min|null, departures["HH:mm"]}`
- `line` faqat mashhur juftliklarda (≈150 ta); bo'lmasa — mijoz to'g'ri chiziq chizadi. `road.min` — to'xtashlarsiz taxminiy vaqt (daqiqa).
