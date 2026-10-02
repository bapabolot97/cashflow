# 💰 CashFlow — Aplikasi Catat Pengeluaran & Pemasukan

Satu file `index.html`. Semua fitur ada di dalamnya. Gratis, bisa diakses dari HP.

---

## ⚡ Cara Pakai Cepat (Local Mode — tanpa setup apa-apa)

1. Buka `index.html` di browser (double-click)
2. Klik **Daftar**, isi nama + email + password
3. Langsung pakai

Data tersimpan di browser (localStorage). History tetap ada walau ditutup dan dibuka lagi.

---

## ☁️ Cara Pakai Cloud (bisa diakses dari HP & PC, data tersinkron)

Cuma perlu **satu langkah sekali saja**:

### Langkah 1 — Buat tabel di Supabase

1. Buka: https://supabase.com/dashboard/project/xmgdrigxjiazmseyspup/sql/new
2. Buka file **`supabase-setup.sql`** (ada di folder ini), copy SEMUA isinya
3. Paste ke SQL Editor
4. Klik **Run** (atau Ctrl+Enter)
5. Tunggu sampai muncul "Success"

### Langkah 2 — Matikan verifikasi email (biar bisa langsung login)

1. Buka: https://supabase.com/dashboard/project/xmgdrigxjiazmseyspup/auth/providers
2. Cari bagian **Email**
3. Matikan **"Confirm email"**
4. Klik **Save**

*(Kalau tidak dimatikan, setelah daftar kamu harus klik link verifikasi di email dulu. Email dari Supabase free tier juga sering kena limit.)*

### Langkah 3 — Pakai aplikasinya

1. Buka aplikasi
2. Klik tombol **☁️** di halaman login → berubah jadi **💾** = Mode Cloud aktif
3. Klik **Daftar**, isi nama + email + password
4. Selesai — data sekarang tersimpan di cloud, bisa dibuka dari HP

---

## 🌐 Cara Online-kan (biar bisa dibuka dari HP, gratis)

### Cara A — Netlify Drop (paling gampang, 30 detik)

1. Buka https://app.netlify.com/drop
2. Drag folder `cashflow-app` ke halaman itu
3. Dapat URL gratis seperti `https://xxxx.netlify.app`
4. Buka URL itu di HP — selesai

### Cara B — GitHub Pages

1. Buat repository baru di GitHub
2. Upload `index.html`
3. Settings → Pages → Source: `main` branch → Save
4. Dapat URL `https://username.github.io/nama-repo`

### Cara C — Jalankan lokal (buat testing di PC)

```bash
cd D:/cashflow-app
node server.js
```

Lalu buka `http://localhost:8080`

---

## 📋 Fitur

| Fitur | Keterangan |
|---|---|
| **Beranda** | Ringkasan pemasukan/pengeluaran/saldo bulan ini, catat cepat, transaksi terbaru, kategori dominan |
| **Transaksi** | Semua transaksi, filter by tipe/kategori/tanggal, edit & hapus |
| **Catat Cepat** | Tap nominal → pilih kategori → Simpan. Auto-save tanggal + jam (tanpa detik) |
| **Amplop/Budget** | Bagi budget per kategori, progress bar, peringatan kalau hampir habis |
| **Berulang** | Tagihan bulanan/mingguan/tahunan, tampilan kalender |
| **Dompet** | Bank, e-wallet, tunai, kartu kredit — saldo dihitung otomatis dari transaksi |
| **Investasi** | Saham, crypto, emas, reksadana — modal, nilai sekarang, untung/rugi, alokasi |
| **Laporan** | Filter periode, ringkasan, grafik batang + pie, tabel detail |
| **Export** | CSV (Excel-ready) dan PDF (via print dialog) |
| **Admin Panel** | Kategori (tambah/edit/hapus + icon + warna), 5 tema, settings, nominal cepat, backup/restore JSON |
| **Mobile** | Responsive penuh, tombol besar, enak dipakai di HP |

### Tema tersedia
Terang · Gelap · Zen Hijau · Senja · Koran Lama

---

## 📁 Isi Folder

```
cashflow-app/
├── index.html            ← aplikasinya (satu file, semua ada di sini)
├── supabase-setup.sql    ← script buat tabel Supabase (jalankan sekali)
├── server.js             ← server lokal buat testing
├── test.js               ← test otomatis (61 test)
└── README.md             ← file ini
```

---

## 🔒 Keamanan Data

- **Row Level Security** aktif di Supabase — tiap user cuma bisa lihat datanya sendiri
- Anon key yang dipakai di aplikasi memang **public** (aman, itu memang fungsinya)
- **Jangan pernah** share `service_role` key atau `secret` key ke siapa pun

---

## ❓ Troubleshooting

**"Tabel database belum dibuat"**
→ Jalankan `supabase-setup.sql` di SQL Editor Supabase (Langkah 1 di atas)

**Daftar berhasil tapi tidak bisa login**
→ Matikan "Confirm email" di Supabase Auth settings (Langkah 2 di atas)

**Data hilang setelah ganti HP**
→ Pastikan pakai Mode Cloud (tombol 💾), bukan Mode Local

**Mau pakai tanpa internet**
→ Mode Local tetap jalan penuh, data di browser

---

## 🧪 Test

```bash
cd D:/cashflow-app
node test.js
```

Harus muncul: `Total: 61  Passed: 61  Failed: 0`
