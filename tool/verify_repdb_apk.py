"""Read-only verification of the actual built APK, including its Dart kernel."""
import argparse
import hashlib
import json
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PREFIX = "assets/flutter_assets/"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("apk", nargs="?", default="build/app/outputs/flutter-apk/app-debug.apk")
    args = parser.parse_args()
    apk = ROOT / args.apk
    source = json.loads((ROOT / "lib/assets/repdb/SOURCE.json").read_text(encoding="utf-8"))
    with zipfile.ZipFile(apk) as bundle:
        images = source["images"]
        packed = {name.removeprefix(PREFIX + "lib/assets/repdb/") for name in bundle.namelist()
                  if name.startswith(PREFIX + "lib/assets/repdb/images/") and name.endswith(".webp")}
        assert packed == set(images), "APK image set differs from pinned source"
        for image, digest in images.items():
            assert hashlib.sha256(bundle.read(PREFIX + "lib/assets/repdb/" + image)).hexdigest() == digest, image
        assert not any("premium-samples/" in name for name in bundle.namelist())
        for name in ("exercises.json", "ar.json", "SOURCE.json", "LICENSE-DATA.md", "ATTRIBUTION.md", "legacy-mapping.json"):
            path = "lib/assets/repdb/" + name
            assert bundle.read(PREFIX + path) == (ROOT / path).read_bytes(), "Stale APK asset: " + name
        kernel = bundle.read(PREFIX + "kernel_blob.bin")
        compiled = ROOT / "build/app/intermediates/flutter/debug/flutter_assets/kernel_blob.bin"
        assert kernel == compiled.read_bytes(), "APK does not contain the newly compiled Dart kernel"
        for marker in (b"lib/assets/repdb/exercises.json", b"lib/assets/repdb/ar.json", b"repdb:", b"Exercise data by RepDB (repdb.co)"):
            assert marker in kernel, "Missing compiled RepDB integration: " + str(marker)
    result = {"apk": args.apk, "bytes": apk.stat().st_size,
              "sha256": hashlib.sha256(apk.read_bytes()).hexdigest(),
              "verified_images": len(images), "premium_assets": 0,
              "catalog_and_overlay_exact": True, "fresh_kernel": True}
    (ROOT / "docs/repdb-apk-verification.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
