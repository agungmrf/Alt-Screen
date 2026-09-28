# Panduan Kontribusi untuk Alt.

Terima kasih atas minat Anda untuk berkontribusi pada pengembangan **Alt.**! Kami menyambut baik kontribusi dari siapa pun, baik berupa perbaikan bug, penambahan fitur baru, penyempurnaan dokumentasi, maupun pelaporan kendala.

---

## Kode Etik

Harap saling menghormati, bersikap konstruktif, dan menjaga komunikasi yang positif dalam setiap diskusi, issue, maupun pull request.

---

## Persiapan Lingkungan Pengembangan

Alt. dibangun murni menggunakan **Swift dan AppKit** tanpa ketergantungan pustaka (*dependencies*) pihak ketiga.

### Persyaratan
* Komputer Mac dengan **macOS 12.0 (Monterey)** atau versi lebih baru.
* Xcode Command Line Tools yang sudah terpasang:
  ```bash
  xcode-select --install
  ```

### Langkah Memulai

1. **Fork Repositori** ini di GitHub ke akun Anda sendiri.
2. **Kloning hasil fork** ke komputer lokal Anda:
   ```bash
   git clone https://github.com/<username-anda>/Alt-Screen.git
   cd Alt-Screen
   ```
3. **Buat Branch Fitur Baru**:
   ```bash
   git checkout -b feature/nama-fitur-anda
   ```
4. **Kompilasi dan Uji Coba**:
   Jalankan skrip build lokal untuk mengompilasi aplikasi:
   ```bash
   chmod +x build.sh
   ./build.sh
   ```
   Aplikasi yang sudah dikompilasi akan berada di `build/Alt.app`.
   Jalankan untuk menguji secara langsung:
   ```bash
   open build/Alt.app
   ```

---

## Alur Kontribusi

### 1. Pelaporan Bug
* Periksa tab **Issues** untuk memastikan kendala serupa belum pernah dilaporkan.
* Buat laporan baru menggunakan template pelaporan bug yang tersedia.
* Cantumkan versi macOS, tipe prosesor (Apple Silicon atau Intel), serta langkah-langkah untuk mereproduksi masalah tersebut.

### 2. Pengajuan Ide Fitur
* Buka Issue baru dan jelaskan kegunaan fitur yang ingin ditambahkan serta kesesuaiannya dengan pedoman antarmuka Apple (HIG).

### 3. Mengirimkan Pull Request (PR)
* Pastikan perubahan terfokus pada satu tujuan perbaikan atau satu fitur per pull request.
* Ikuti kaidah penulisan kode native Swift dan pola desain AppKit.
* Pastikan kode berhasil dikompilasi tanpa pesan kesalahan melalui `./build.sh`.
* Unggah branch Anda ke GitHub fork:
  ```bash
  git push -u origin feature/nama-fitur-anda
  ```
* Buka Pull Request ke branch utama (`main`) pada repositori ini.

---

## Pedoman Penulisan Kode

* **Murni Native**: Hindari penambahan dependensi web atau framework berat. Komitmen proyek ini adalah menjaga penggunaan memori tetap di bawah 25 MB RAM.
* **Arsitektur Rapi**: Pisahkan logika modul, controller, dan tampilan di dalam folder `Sources/`.
* **Aset Retina**: Semua ikon antarmuka harus berupa vektor template (`isTemplate = true`) atau aset beresolusi tinggi (2x Retina).
