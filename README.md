# Aplikasi Android SIAKAD SMK PGRI 1 Ponorogo

APK pembungkus (WebView) untuk mengakses **https://siakad.smkpgri1po.sch.id/admin/login**.

## Identitas aplikasi
| Item | Nilai |
|---|---|
| Nama aplikasi | SIAKAD SMK PGRI 1 Ponorogo |
| Package ID | `id.sch.smkpgri1po.siakad` |
| Versi | 1.3 (versionCode 4) |
| Min. Android | 4.0 Ice Cream Sandwich (API 14) |
| Target Android | 14 (API 34) |
| Ukuran | 141 KB |
| Tanda tangan | v1 (SHA-1) + v2 + v3, kunci RSA 2048 |

## Penyebab "APK tidak bisa dipasang" (sudah diperbaiki)
Penyebab sebenarnya **bukan versi Android**, melainkan bentrok tanda tangan:

```
INSTALL_FAILED_UPDATE_INCOMPATIBLE:
Package id.sch.smkpgri1po.siakad signatures do not match
previously installed version
```

Di perangkat sudah ada aplikasi SIAKAD **versi 1.0.1** dengan package ID sama tetapi
ditandatangani kunci berbeda (dibuat lebih dulu). Android menolak memasang APK baru
di atas aplikasi bertanda tangan lain — di sebagian HP penolakan ini muncul tanpa pesan
("langsung berhenti").

**Solusi:** hapus aplikasi SIAKAD lama, lalu pasang APK v1.3. Sudah diuji pada perangkat
Android 9 (emulator): uninstall lama → install v1.3 → berhasil, aplikasi terbuka,
halaman login termuat, tanpa crash (`mResumedActivity` aktif).

## Fitur
- Splash screen logo resmi SMK PGRI 1 Ponorogo + indikator memuat.
- Ikon launcher logo resmi (multi-densitas mdpi–xxxhdpi).
- Login SIAKAD langsung; cookie, session, dan JavaScript aktif.
- Tombol **Back** kembali ke halaman sebelumnya di dalam aplikasi.
- Indikator progres di bagian atas + halaman "Coba Lagi" saat offline.
- Unggah berkas/foto (termasuk jalur `openFileChooser` untuk Android < 5.0).
- Unduhan PDF/Excel masuk folder **Download**.
- Tautan WhatsApp/telepon/email/peta dibuka di aplikasi lain; domain lain ke browser.
- Status bar hijau, mode portrait, tanpa izin sensitif.

## Cara memasang di HP
1. **Hapus aplikasi SIAKAD lama** bila ada:
   Pengaturan → Aplikasi → cari "SIAKAD" → **Uninstal**.
2. Salin `SIAKAD-SMKPGRI1PO-v1.3.apk` (141 KB) ke HP.
3. Buka APK dari **File Manager / My Files → Download** (jangan dari preview chat).
4. Izinkan **"Instal aplikasi tidak dikenal / Install unknown apps"** untuk File Manager.
5. Jika muncul peringatan Play Protect → pilih **"Tetap pasang / Install anyway"**.
6. Buka **SIAKAD SMK PGRI 1 Ponorogo** dari laci aplikasi.

Verifikasi file setelah dikirim (opsional, di PC):
```
SHA-256: 2D3FE41823BCF0B00391BB297DFE59CEB650DE0C45BDEEE7CC05BC480A437C2A
```
Jika hash berbeda, file terunduh tidak utuh — salin ulang.

### Jika masih gagal
1. Pastikan tidak ada sisa aplikasi SIAKAD lain: Pengaturan → Aplikasi.
2. Pada Android 13+, buka **Settings → Apps → Special access → Install unknown apps**,
   aktifkan untuk aplikasi pembuka APK. Bila muncul "Restricted setting",
   buka Settings → Apps → (aplikasi tsb) → menu ⋮ → **Allow restricted settings**.
3. Pastikan ruang penyimpanan cukup (>100 MB).
4. Jika HP dikelola sekolah/kantor (MDM), pemasangan di luar Play Store bisa diblokir kebijakan.
5. Cara paling akurat: sambungkan HP via USB (aktifkan USB debugging), lalu di PC:
   ```
   C:\Users\guru01\AndroidBuild\sdk\platform-tools\adb.exe install -r "SIAKAD-SMKPGRI1PO-v1.3.apk"
   ```
   adb akan menampilkan kode error yang sebenarnya bila masih gagal.

## Catatan keamanan
- APK ditandatangani keystore lokal `siakad-release.keystore`
  (alias `siakad`, berlaku 10.000 hari). **Simpan file ini** — pembaruan berikutnya
  harus memakai kunci yang sama, jika tidak akan muncul konflik tanda tangan lagi.
- Izin: `INTERNET`, `ACCESS_NETWORK_STATE`, plus `WRITE_EXTERNAL_STORAGE`
  (dibatasi `maxSdkVersion=18`, hanya Android 4.0–4.3).
- Kesalahan sertifikat SSL tidak dilewati.

## Membangun ulang
```powershell
# build normal (targetSdk 34, signature lengkap)
C:\Users\guru01\AndroidBuild\build.ps1 -VersionName 1.3 -VersionCode 4

# varian yang bisa berdampingan (package berbeda) bila aplikasi lama tidak boleh dihapus
C:\Users\guru01\AndroidBuild\build.ps1 -VersionName 1.3 -VersionCode 4 `
    -PackageName "id.sch.smkpgri1po.siakad.app" -Suffix "-baru"

# varian sangat toleran: targetSdk 29 + hanya signature v1
C:\Users\guru01\AndroidBuild\build.ps1 -VersionName 1.3 -VersionCode 4 -TargetSdk 29 -V1Only -Suffix "-universal"
```
Naikkan `-VersionCode` (mis. 5) tiap rilis baru agar bisa dipasang sebagai pembaruan.

## Versi iOS
Proyek iOS lengkap (SwiftUI + WKWebView) ada di `ios\`, dengan fitur setara:
splash logo, ikon resmi, login WebView, navigasi mundur, progres, halaman
"Coba Lagi", unggah foto/berkas, unduhan, dan tautan eksternal.

**Penting:** aplikasi iOS tidak dapat dikompilasi atau ditandatangani di Windows.
Kompilasi memerlukan macOS + Xcode, atau GitHub Actions (runner macOS).
Panduan langkah demi langkah, termasuk cara memasang di iPhone dari Windows
(Sideloadly + Apple ID), ada di [`ios/README-iOS.md`](ios/README-iOS.md).

- Proyek: `ios\project.yml` (XcodeGen) + `ios\SIAKAD\`
- CI: `.github\workflows\ios-build.yml` → menghasilkan `SIAKAD-unsigned.ipa`
- Aset: `tools\make-ios-assets.js` (ikon 20–1024 px tanpa alpha + logo launch)

## Struktur proyek
```
C:\Users\guru01\AndroidBuild\
├── app\
│   ├── AndroidManifest.xml
│   ├── res\ (layout, values, values-v21, logo, ikon launcher multi-densitas)
│   └── src\id\sch\smkpgri1po\siakad\MainActivity.java
├── ios\                      # proyek Xcode (SwiftUI + WKWebView) + README-iOS.md
├── .github\workflows\        # CI macOS: kompilasi + IPA tanpa tanda tangan
├── tools\make-brand.js       # generator ikon + logo Android dari logo sekolah
├── tools\make-ios-assets.js  # generator AppIcon/LaunchLogo iOS
├── tools\make-icon.js        # generator ikon alternatif
├── tools\analyze-shot.js     # analisis screenshot untuk uji tampilan via adb
├── build.ps1                 # skrip build Android tanpa Gradle
├── dist\                     # hasil APK
└── siakad-release.keystore   # kunci penandatangan Android (WAJIB DISIMPAN)
```
