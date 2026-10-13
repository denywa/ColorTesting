# Validasi Integrasi Playtesting Part II

Tanggal: 13 Oktober 2026. Cakupan: protokol v2, Manual/Auto Mix, voting final dengan mayoritas dua pemain, UI tindakan seluruh peran, serta pemulihan ballot.

## Validation Report

- DECISION: MANUAL_VERIFY_REQUIRED
- MECHANICAL_RESULTS:
  - Tests: PASS — suite macOS penuh, exit 0; 185 lulus, 0 gagal, 0 skip. Review independen terakhir: `/private/tmp/network-10-2-review.log`.
  - Build iOS: PASS — target Simulator, exit 0; `/private/tmp/network-10-2-ios.log`.
  - Konfigurasi jaringan: plist kedua artefak memuat layanan Bonjour `_colorgame._tcp` dan alasan izin jaringan lokal.
  - TBD/TODO grep: CLEAN pada implementasi jaringan dan komponen status voting baru.
  - Secrets: tidak ditemukan kredensial baru pada perubahan yang ditinjau. Token reconnect adalah UUID sementara sesi.
  - Smoke boot: PASS — artefak iOS terbaru dipasang dan dibuka pada iPhone 17 Pro Simulator; layar `Choose How to Play` terlihat. Screenshot: `/private/tmp/network-part2-launch.png`. Pemeriksaan ini tidak menguji sentuhan atau jaringan tiga perangkat.
- INTEGRATION:
  - Kontrak lintas tugas: konsisten; UI mengirim castVote, host memvalidasi kursi dan ballot, keputusan mayoritas memanggil transisi domain, lalu snapshot lengkap diterapkan secara atomik pada klien.
  - State bersama: tes membuktikan campuran, warna live, hasil, skor, timer, penugasan dan pilihan suara konvergen. Snapshot mengompresi jumlah unit dan mempertahankan urutan kemunculan pertama, bukan urutan setiap kejadian input berulang.
  - Boundary audit: bersih; perhitungan warna/skor tetap pada domain, voting pada koordinator, validasi snapshot pada mapper, dan tampilan pada SwiftUI. Tidak ada dependensi Network atau ballot pada domain ronde.
- COVERAGE:
  - Requirements mapped: 59/59 kriteria memiliki jalur implementasi dan pemetaan tugas/tes; pemetaan bukan klaim bahwa seluruh kriteria telah diverifikasi pada perangkat fisik.
  - Coverage gaps: bukti perangkat fisik untuk versi voting baru pada tugas 10.3 belum tersedia. Laporan baseline 6.5 hanya berlaku pada versi sebelumnya.
- DESIGN:
  - Architecture drift: tidak ditemukan.
  - Dependency direction: domain/model → mapper/codec/transport → koordinator → UI dipertahankan.
  - File Structure Plan: komponen jaringan tetap di LocalPlay; LocalVotingStatusView adalah komponen presentasi bersama GameView dan ResultView.
- OWNERSHIP: LOCAL
- UPSTREAM_SPEC: N/A
- BLOCKED_TASKS: tidak ada anotasi blocked; tugas 10.3 dan kelompok 10 tetap belum selesai karena uji manual wajib belum dilaporkan.
- NEXT_STEP: jalankan checklist tiga perangkat berikut pada build terbaru dan catat hasil sebelum menetapkan GO.

## Pemetaan Kebutuhan

| Kriteria | Implementasi dan bukti otomatis |
| --- | --- |
| 1.1–1.8 | ModeSelection/LocalLobby, koordinator kursi, transport Bonjour; tes ContentView, coordinator dan transport. Penemuan/izin Wi-Fi nyata perlu 10.3. |
| 2.1–2.7 | SettingsView, kontrol host, GameViewModel dan mapper; tes pengaturan, katalog kustom lokal, default Manual dan snapshot. |
| 3.1–3.7 | GameView, input per kursi, assignmentHistory dan live blend; tes input integration, coordinator dan voting UI. |
| 4.1–4.4 | Timer/epoch domain dan snapshot host; tes input di batas reassignment, preservasi unit dan countdown. |
| 5.1–5.11 | Eligibility domain, keputusan host, Game/Result/Score; tes semua tindakan dua suara, mayoritas suara ketiga, reset dan New Round host-only. |
| 6.1–6.9 | Pause, recovery token, antrean Welcome/snapshot, dan lifecycle; tes pengiriman recovery ditahan/gagal lalu retry, suara final dan deduplikasi setelah reconnect. Wi-Fi fisik perlu 10.3. |
| 7.1–7.4 | Kontrol solo langsung, satu skor, routing awal dan transport lokal; tes solo/ContentView/transport serta smoke launch terbaru. |
| 8.1–8.9 | Ballot bertipe, validasi host, ID aksi, rotasi sebelum mutasi, status UI; tes suara final/pengganti/stale, dua/ketiga suara, input pending, bowl terbaru dan ballot baru. |

## Checklist Manual Tugas 10.3

Pasang build terbaru pada tiga perangkat fisik di Wi-Fi yang sama; gunakan satu host dan dua klien.

1. Buat/join sesi, periksa tiga kursi dan izin jaringan. Perangkat keempat ditolak; build protokol lama ditolak tanpa menerapkan snapshot.
2. Manual: tambahkan warna, pilih Mix dari satu perangkat, tambahkan warna lagi, lalu pilih Mix dari perangkat kedua. Hasil/rasio sama dan memuat kontribusi terakhir. Uji Redo dan Finish dengan dua suara yang cocok.
3. Auto: tambahkan warna dari seluruh peran; warna live sama. Apply/Redo dapat ditekan oleh setiap pemain sebelum memberikan suara. Suara pertama menonaktifkan tindakan hanya bagi pemilih tersebut; warna tetap dapat ditambahkan. Suara kedua yang cocok langsung menjalankan tindakan.
4. Pilih tindakan berbeda pada dua perangkat; tindakan belum berjalan. Pilihan final tidak dapat diganti. Suara ketiga menentukan mayoritas, lalu ballot baru kosong; periksa skor yang sama dan New Round hanya host.
5. Saat suara pending, putuskan satu klien. Timer/input/vote dijeda. Sambungkan kembali; kursi, suara final, warna, penugasan, hasil dan countdown pulih sebelum resume. Keputusan tidak berjalan hanya karena reconnect.

Uji sentuh solo sebelumnya dikonfirmasi pengguna pada tugas round-flow 7.2; konfirmasi itu tidak mencakup voting tiga perangkat.
