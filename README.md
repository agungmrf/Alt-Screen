<p align="center">
  <img src="AppIcon.icns" alt="Logo Alt." width="96" height="96">
</p>

<h1 align="center">Alt.</h1>

<p align="center">
  Aplikasi tangkapan layar, perekam layar, dan editor anotasi native untuk macOS.<br>
  Dirancang dengan Swift dan AppKit sebagai alternatif CleanShot X yang ringan dan tanpa langganan.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2012%2B-black?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/Bahasa-Swift%206%20%2F%20AppKit-black?style=flat-square" alt="Bahasa">
  <img src="https://img.shields.io/badge/Arsitektur-Universal%20(Apple%20Silicon%20%26%20Intel)-black?style=flat-square" alt="Arsitektur">
  <img src="https://img.shields.io/badge/Memori-%3C25MB%20RAM-black?style=flat-square" alt="Memori">
</p>

---

## Alternatif CleanShot X untuk macOS

Alt. dikembangkan bagi pengguna Mac yang membutuhkan fungsi lengkap CleanShot X tanpa biaya langganan bulanan dan tanpa beban memori dari aplikasi berbasis web (Electron).

- **Performa Native Ringan**: Ditulis murni menggunakan Swift dan AppKit. Berjalan dengan penggunaan memori di bawah 25 MB RAM dan terbuka secara instan.
- **Privasi Terjamin**: Seluruh pemrosesan teks OCR diproses langsung di perangkat lokal (*on-device*) menggunakan Apple Vision tanpa mengirim data ke server luar.
- **Alur Kerja CleanShot X**: Dilengkapi floating preview Quick Access, scrolling capture, perekam layar dengan preset crop, dan riwayat tangkapan di bawah notch.

---

## Fitur Utama

- **Mode Tangkapan Layar**: Pilihan area bebas, area sebelumnya, jendela aplikasi dengan bayangan native, layar penuh, dan self-timer hitung mundur 3 detik.
- **Scrolling Capture Pintar**: Mengambil tangkapan layar bergulir panjang dengan deteksi keberadaan kursor. Perekaman berhenti otomatis saat kursor keluar dari area target, dan berlanjut otomatis saat kursor kembali.
- **Perekam Layar & GIF**: Seleksi crop area dengan kursor bidik, pilihan preset resolusi standar (Fullscreen, 4K, 1080p, 720p, Square 1:1), perekaman audio sistem, mikrofon, dan penanda klik kursor.
- **Quick Access Floating Preview**: Panel thumbnail mengambang berukuran 240x155 pt dengan pelacak kursor stabil agar tidak tertutup mendadak. Mendukung drag-and-drop langsung ke Finder atau aplikasi chat, serta tombol aksi cepat Salin, Simpan, Pin, Markup, dan OCR.
- **Riwayat di Bawah Notch**: Tampilan riwayat carousel yang menempel tepat di bawah notch MacBook. Mendukung navigasi geser dua jari pada trackpad dan filter kategori (Semua, Screenshot, Video, GIF).
- **Ekstraksi Teks (OCR)**: Pengenalan teks otomatis pada gambar atau dokumen langsung disalin ke clipboard menggunakan Apple Vision.
- **Editor Anotasi & Beautifier**: Alat anotasi vektor (panah, nomor langkah bertahap, bentuk geometris, teks, sensor blur) dan latar belakang gradien kanvas estetik.
- **Utilitas Tambahan**: Fitur satu klik untuk menyembunyikan ikon desktop saat presentasi, dan fitur sematkan gambar mengambang di atas semua jendela (Pin).

---

## Pintasan Keyboard (Shortcuts)

| Pintasan Global | Tindakan | Keterangan |
| :--- | :--- | :--- |
| `⌘ + ⇧ + 1` | Capture Area | Kursor bidik seleksi area layar |
| `⌘ + ⇧ + 2` | Record Screen HUD | Panel kontrol rekam video dan GIF |
| `⌘ + ⇧ + 3` | Capture Fullscreen | Tangkap seluruh layar aktif |
| `⌘ + ⇧ + 4` | Scrolling Capture | Tangkap halaman bergulir vertikal |
| `⌘ + ⇧ + 5` | Capture Previous Area | Tangkap ulang area tangkapan sebelumnya |
| `⌘ + ⇧ + P` | Pick Color (Eyedropper) | Pipet pembesar sampel warna layar ke HEX (`#HEX`) |
| `⌘ + ⇧ + C` | Capture Text (OCR) | Ekstraksi teks layar ke clipboard |
| `⌘ + ⇧ + Z` | Capture History | Panel riwayat di bawah notch |
| `⌘ + ,` | Settings | Pengaturan preferensi dan lokasi penyimpanan |

---

## Pemasangan & Penggunaan

### Persyaratan Sistem
- macOS 12.0 (Monterey) atau versi lebih baru.
- Binary Universal: Mendukung Apple Silicon (M1/M2/M3/M4) dan prosesor Intel.

### Cara Build dari Kode Sumber
```bash
# 1. Kloning repositori
git clone https://github.com/your-username/Alt-Screen.git
cd Alt-Screen

# 2. Kompilasi aplikasi native
chmod +x build.sh
./build.sh

# 3. Pindahkan ke Applications dan jalankan
cp -R build/Alt.app /Applications/
open /Applications/Alt.app
```

### Izin macOS
Aktifkan izin **Perekaman Layar (Screen Recording)** di menu **Pengaturan Sistem > Privasi & Keamanan > Perekaman Layar** agar Alt. dapat mengambil gambar dan merekam layar.

---

<p align="center">
  Alt. &bull; Utilitas Layar Native macOS &bull; 2026
</p>
