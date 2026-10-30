#!/bin/bash
# iOS kodini serverda (Linux) to'liq tekshirish — macOS daqiqalarini tejash uchun CI'dan OLDIN ishga tushiriladi.
# Swift 6.2 (Linux) + iPhoneOS 26 SDK interfeyslari (SwiftUI, UIKit...) bilan type-check: kod yig'ilmaydi, faqat xatolar chiqadi.
# Vositalar: /opt/tools/swift (swift.org), /opt/tools/ios-sdk (github.com/xybp888/iOS-SDKs, sparse).
set -euo pipefail
cd "$(dirname "$0")/../AllUz"
SWIFTC=${SWIFTC:-/opt/tools/swift/swift-6.2-RELEASE-ubuntu22.04/usr/bin/swiftc}
SDK=${SDK:-/opt/tools/ios-sdk/iPhoneOS26.0.sdk}
# Linux'ning o'z dispatch/CoreFoundation modulemap'lari SDK bilan to'qnashadi ("redefinition of module 'Dispatch'") —
# shuning uchun faqat kerakli qismlardan iborat resurs papka: /opt/tools/ios-rd (symlinklar).
# -enable-cross-import-overlays — Xcode kabi (SwiftUI+QuickLook: .quickLookPreview)
RD=${RD:-/opt/tools/ios-rd}
MC=${MC:-/opt/tools/ios-mc}
if [ ! -d "$RD" ]; then
  R=$(dirname "$SWIFTC")/../lib/swift
  mkdir -p "$RD"
  for d in apinotes clang shims host embedded migrator swiftToCxx FrameworkABIBaseline; do [ -e "$R/$d" ] && ln -sfn "$R/$d" "$RD/$d"; done
fi
mkdir -p "$MC"
mapfile -t FILES < <(find . -name '*.swift' | sort)
echo "${#FILES[@]} fayl"
"$SWIFTC" -typecheck -wmo -swift-version 5 -sdk "$SDK" -target arm64e-apple-ios17.0 -resource-dir "$RD" \
  -Xfrontend -enable-cross-import-overlays -module-cache-path "$MC" -module-name AllUz "$@" "${FILES[@]}"
echo "OK — xato yo'q"
