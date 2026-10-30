#!/bin/bash
# Skrinshotlar (CI, macOS): ilovani simulyatorda -shot rejimida ochib rasmga oladi — iPhone 6.9" (1320×2868).
# Ro'yxat: SHOT_LIST="tab:home=home item:place:registon=registon board:TAS=tablo-dark" (spec=nom; nom «dark»/«-dark» bilan
# tugasa — qorong'i mavzu; «-ru»/«-en»/«-uz» qo'shimchasi — til). spec: App/ShotMode.swift. Bo'sh bo'lsa — App Store to'plami.
# WAIT — har ekranni kutish (soniya; tarmoqdan yuklanadi), WARMUP — birinchi ochilish.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=${OUT:-shots}
WAIT=${WAIT:-8}
xcodebuild -project AllUz.xcodeproj -scheme AllUz -configuration Release -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build 2>&1 | tee build.log | xcbeautify --quiet
APP=$(find build/Build/Products -maxdepth 2 -name 'AllUz.app' -path '*iphonesimulator*' | head -1)
[ -d "$APP" ] || { echo "AllUz.app topilmadi"; exit 1; }
RUNTIME=$(xcrun simctl list runtimes -j | python3 -c "
import json, sys
r = [x for x in json.load(sys.stdin)['runtimes'] if x.get('platform') == 'iOS' and x.get('isAvailable')]
r.sort(key=lambda x: [int(p) for p in x['version'].split('.')])
print(r[-1]['identifier'])")
PHONE=$(xcrun simctl list devicetypes -j | python3 -c "
import json, re, sys
ts = json.load(sys.stdin)['devicetypes']
c = sorted([t for t in ts if re.search(r'^iPhone 1[6-9] Pro Max$', t['name'])], key=lambda t: t['name'])
print(c[-1]['identifier'] if c else '')")
echo "runtime=$RUNTIME phone=$PHONE"
LIST=${SHOT_LIST:-"tab:home=home item:place:registon=registon tab:explore=explore tab:map=map tab:board=tablo item:region:xorazm=region list:venue:stay=hotels weather=weather tab:home=home-dark"}
UDID=$(xcrun simctl create "shot-phone" "$PHONE" "$RUNTIME")
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b > /dev/null
xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl install "$UDID" "$APP"
xcrun simctl privacy "$UDID" grant location com.alluzbekistan.app || true
xcrun simctl location "$UDID" set 39.6547,66.9758 || true     # Registon (xarita «yaqin atrofda» sinovi)
# birinchi ochilish — tizim bildirishnomalari o'tib ketsin
xcrun simctl launch "$UDID" com.alluzbekistan.app -shot tab:home > /dev/null; sleep ${WARMUP:-60}
mkdir -p "$OUT/phone"
i=0
for p in $LIST; do
  i=$((i + 1)); spec=${p%%=*}; name=${p##*=}
  theme=${THEME:-light}; case "$name" in dark|*-dark|*-dark-*) theme=dark ;; esac
  lang=${LANG_DEFAULT:-uz}; case "$name" in *-ru) lang=ru ;; *-en) lang=en ;; *-uz) lang=uz ;; esac
  xcrun simctl terminate "$UDID" com.alluzbekistan.app 2> /dev/null || true
  xcrun simctl launch "$UDID" com.alluzbekistan.app -shot "$spec" -theme "$theme" -app.lang "$lang" > /dev/null
  sleep "$WAIT"
  xcrun simctl io "$UDID" screenshot --type=png "$OUT/phone/$(printf %02d $i)-$name.png" > /dev/null
  echo "$i $spec → $name ($theme, $lang)"
done
xcrun simctl shutdown "$UDID" || true
xcrun simctl delete "$UDID" || true
