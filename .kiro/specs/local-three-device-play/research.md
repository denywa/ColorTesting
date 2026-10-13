# Riset dan Keputusan Desain: Playtesting Part II

## Ringkasan

- **Fitur:** local-three-device-play
- **Jenis penelusuran:** Ekstensi; penelusuran ringan terfokus pada protokol/mapper/koordinator yang sudah diimplementasikan.
- **Temuan utama:** Transport, kursi, deduplikasi, riwayat penugasan dan reconnect dapat dipakai kembali. Mayoritas membutuhkan votingID tersendiri; snapshotRevision/epoch berubah saat warna/tick, sedangkan roundID/fase tidak berubah saat Auto Redo. Mode/live color/suara memerlukan protokol 2.

## Catatan Penelusuran

### Kontrak dan sumber otoritas

- **Konteks:** Suara final, dua cocok segera berlaku, input tetap diterima, campuran terbaru digunakan.
- **Sumber:** LocalPlayModels.swift, LocalPlayCoordinator.swift, LocalGameSnapshotMapper.swift, LocalMessageCodec.swift, LocalPeerTransport.swift dan pengujian terkait.
- **Temuan:** Host sekarang menjalankan tindakan fase langsung; peer hanya mengirim warna. Hook didChange menerbitkan snapshot. acceptedActionIDs direset ketika roundID berubah dan harus dipertahankan saat Redo/reconnect.
- **Dampak:** Vote bertipe melalui Input.action, seat diturunkan dari koneksi, satu jalur MainActor untuk semua peran. Ganti ballot sebelum mutasi domain agar snapshot hasil tidak memuat suara lama. Jangan await di antara mayoritas dan tindakan.

### Warna live, validasi dan pemulihan

- **Sumber:** GameViewModel.swift, mapper, LocalPlayCoordinatorTests.swift, LocalPlayInputIntegrationTests.swift dan laporan riset round-flow.
- **Temuan:** Mapper belum memvalidasi pasangan berbeda dan menolak hasil saat playing. Klien memakai applyRemoteState tanpa timer/mixer. Recovery sudah mengirim snapshot penuh sebelum resume.
- **Dampak:** Pakai currentBlend terpisah dari mixResult, hitung hanya host/solo. Mapper memvalidasi mode/fase/warna/assignment/ballot secara utuh sebelum apply. Reconnect mempertahankan votingID/records, menolak vote selama pause, dan tidak menjalankan keputusan baru sendiri.

### Kompatibilitas dan transport

- **Sumber:** LocalPlayProtocol.version, WireMessage.Hello/Reject, codec/tests, transport/config yang sudah ada.
- **Temuan:** Versi 1 tidak mempunyai mode atau suara; schema baru tidak kompatibel. Framing, Bonjour/TCP, heartbeat dan izin sudah tersedia.
- **Dampak:** Naikkan ke versi 2, pertahankan bentuk Hello/Reject agar handshake menolak build berbeda sebelum snapshot. Tidak membangun ulang transport atau menambah pustaka. Riset API eksternal baru tidak diperlukan; dokumen Apple pada catatan historis menjelaskan keputusan transport awal.

## Evaluasi Pola Arsitektur

| Opsi | Kelebihan | Batas | Keputusan |
| --- | --- | --- | --- |
| Host otoritatif + snapshot penuh | Satu urutan aksi, pemulihan tersedia | Host tetap titik kegagalan | Dipertahankan |
| Konsensus peer atau service voting baru | Pemisahan tambahan | Otoritas ganda dan migrasi rumit | Ditolak |

## Keputusan Desain

- **Generalisasi:** Satu ballot tiga kursi mendukung empat tindakan yang dibatasi eligibility mode/fase; tidak membuat aturan mayoritas generik untuk jumlah pemain lain.
- **Bangun vs adopsi:** Gunakan transport/codec/mapper/koordinator yang ada; tambah hanya payload dan state suara game.
- **Penyederhanaan:** LocalVotingState kecil berada dalam file model yang ada. Mode berasal dari domain; tidak ada enum mode jaringan kedua, log kejadian, layanan voting terpisah atau persistence.
- **Batas:** Koordinator memiliki ballot/seat/authority; domain memiliki eligibility/transisi; mapper memvalidasi snapshot; UI mempresentasikan final choice/status. Perubahan file bersama bertahap setelah kontrak warna/ronde.
- **Skill:** kiro-spec-design light discovery/synthesis/review dan Ponytail full memandu pemakaian komponen yang ada. kiro-verify-completion membatasi klaim hasil pada bukti aktual.

## Risiko dan Mitigasi

- Suara reset setiap kontribusi: gunakan votingID yang tetap sepanjang keputusan, independen dari snapshotRevision/assignmentEpoch.
- Suara terlambat memicu Auto Redo ulang: tolak votingID lama dan pertahankan deduplikasi actionID sepanjang ronde.
- Snapshot tidak konsisten saat mayoritas: kosongkan/ganti ballot sebelum domain didChange; mapper menolak snapshot tertunda yang sudah mayoritas.
- Koneksi putus: records sah dipertahankan, input/suara baru ditolak, full snapshot terkirim sebelum resume.
- Izin/jaringan nyata: fake/simulator tidak membuktikan operasi tiga perangkat; pengujian fisik wajib sebelum GO.

## Gate Tinjauan

Semua 59 kriteria numerik tercakup dalam traceability. Pemeriksaan mekanis memastikan section/batas terisi, path Swift tersedia, tanpa placeholder dan requirements disetujui. Perbaikan lokal menyelaraskan lokasi FakePeerNetwork dan kontrak lintas spesifikasi. Tinjauan semantik memeriksa identitas ballot, dua suara final, continued input/latest bowl, atomic publish, penolakan versi dan recovery. Tidak ada implementasi atau tes runtime pada tahap desain ini.

## Referensi

Berkas produksi/pengujian dan core steering di atas menjadi sumber lokal. Desain color/round/UI menjelaskan batas terkait. Catatan historis berikut berasal dari pengembangan transport awal; pernyataan belum adanya jaringan di sana bukan keadaan kode saat ini.


---

## Catatan Riset Historis (cakupan baseline terdahulu)

# Riset dan Keputusan Desain: Permainan Lokal Tiga Perangkat

## Ringkasan

- **Fitur:** `local-three-device-play`
- **Jenis penelusuran:** Integrasi kompleks; penelusuran penuh pada kode yang ada dan dokumentasi resmi Apple.
- **Temuan utama:**
  - `GameViewModel` sekarang memegang seluruh transisi ronde, timer, dan input untuk satu perangkat. Satu host dapat mempertahankan aturan itu sebagai sumber keadaan bersama; klien cukup mengirim aksi dan menerima keadaan.
  - Apple mendepresiasi Multipeer Connectivity pada Xcode 27. Network framework menyediakan penemuan Bonjour, listener, dan koneksi TCP; API `NW*` lama tetap diperlukan agar target iOS 17 didukung.
  - Permintaan warna kustom hanya tersimpan lokal. Salinan keadaan ronde harus membawa teks serta warna target secara lengkap tanpa menulisnya ke penyimpanan klien.

## Catatan Penelusuran

### Alur dan batas kode saat ini

- **Konteks:** Fitur memperluas game tiga pemain pada satu perangkat.
- **Sumber:** `GameViewModel.swift`, `GameState.swift`, `GameModels.swift`, `ContentView.swift`, `Views/*`, `CustomRequestStore.swift`, dan pengujian terkait.
- **Temuan:** `ContentView` hanya merutekan empat fase game; belum ada pemilihan mode, lobi, identitas perangkat, atau jaringan. `GameViewModel` memilih target serta penugasan secara acak, menjalankan timer, mengunci campuran, menghitung hasil, dan mengatur Redo/Finish/New Round. `GameView` saat ini memberi akses ke enam input pada satu layar; keyboard macOS juga memetakan semua pemain. `Mix.units` berurutan dan dipakai untuk rincian hasil.
- **Dampak:** Rute mode dan lobi baru diperlukan. Mutasi game tetap berpusat di host; klien menerapkan snapshot tanpa menjalankan timer atau pengacakan sendiri. Input UI dan keyboard harus dibatasi sesuai peran lokal.

### Transport lokal dan kompatibilitas

- **Konteks:** Tiga perangkat pada Wi-Fi yang sama, tanpa akun/server internet, dengan target iOS 17 dan macOS 27.
- **Sumber:** [TN3213 Apple](https://developer.apple.com/documentation/technotes/tn3213-moving-from-multipeer-connectivity-to-network-framework), [NWListener](https://developer.apple.com/documentation/network/nwlistener), [NWBrowser](https://developer.apple.com/documentation/network/nwbrowser), [NWConnection](https://developer.apple.com/documentation/network/nwconnection).
- **Temuan:** Apple mendepresiasi Multipeer Connectivity di Xcode 27 dan menyarankan Network framework. API async `NetworkListener/NetworkBrowser/NetworkConnection` baru dimulai pada iOS 26; API `NWListener/NWBrowser/NWConnection` tetap dapat mencapai fungsi yang sama pada iOS 17. Listener dapat mengiklankan layanan Bonjour, browser menemukannya, dan klien menghubungi host. TCP adalah aliran byte andal, sehingga aplikasi perlu memberi batas pesan sendiri.
- **Dampak:** Satu host listener dan dua koneksi klien. Pesan game kecil memakai JSON `Codable` dengan awalan panjang; host menyebarkan snapshot ke kedua klien. Tidak ada dependensi pihak ketiga.

### Izin jaringan dan keamanan

- **Konteks:** Penemuan Bonjour pada perangkat nyata dan izin aplikasi macOS tersandbox.
- **Sumber:** [TN3179 Apple](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy), [NSBonjourServices](https://developer.apple.com/documentation/bundleresources/information-property-list/nsbonjourservices), [NSLocalNetworkUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nslocalnetworkusagedescription), [network server entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.network.server), [network client entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.network.client).
- **Temuan:** Aplikasi yang menjelajah/mendaftarkan layanan Bonjour perlu mendeklarasikan tipe layanan dan alasan akses jaringan lokal. Privasi jaringan lokal harus diuji pada perangkat nyata; simulator tidak cukup untuk memastikan dialog/penolakan izin. Host macOS tersandbox memerlukan izin koneksi masuk, dan peran klien memerlukan izin koneksi keluar. TCP saja tidak mengenkripsi data.
- **Dampak:** Tambahkan kunci Info.plist untuk kedua target serta entitlement masuk/keluar pada target macOS. Versi playtest dibatasi pada Wi-Fi tepercaya dan hanya mengirim data ronde tanpa identitas pribadi. Jika penggunaan pada jaringan tidak tepercaya atau internet kelak diminta, keamanan transport serta pemasangan perangkat harus dirancang ulang.

### Koneksi terputus dan keadaan bersama

- **Konteks:** Kebutuhan 3.3, 3.6, 4.4, dan 6.1–6.4 memerlukan hasil deterministik meskipun pesan terlambat atau koneksi putus.
- **Sumber:** `GameViewModel.swift`, `ColorData.swift`, [TN3213 Apple](https://developer.apple.com/documentation/technotes/tn3213-moving-from-multipeer-connectivity-to-network-framework).
- **Temuan:** Host harus mengurutkan mutasi. TCP tidak membuktikan bahwa aksi game yang dikirim tepat sebelum putus sudah diterapkan; reconnect membutuhkan snapshot penuh. Warna palet mempunyai ID tetap, sedangkan permintaan kustom harus dibawa lengkap. Timer sekarang lokal dan dapat dijeda tanpa mengubah sisa detik.
- **Dampak:** Setiap aksi membawa ID unik, ID ronde, revisi penugasan, dan ID warna yang terlihat. Host menolak duplikat serta aksi tak sah, lalu menerbitkan snapshot bernomor revisi. Klien tidak memperbarui campuran secara optimistis. Sesi menyimpan token peran sementara selama proses aplikasi hidup agar perangkat yang tersambung kembali memperoleh kursi yang sama.

## Evaluasi Pola Arsitektur

| Opsi | Kelebihan | Keterbatasan | Keputusan |
|---|---|---|---|
| Host otoritatif + dua klien | Satu aturan, timer, dan urutan aksi; selaras dengan `GameViewModel` | Host menjadi titik kegagalan tunggal | Dipilih |
| Tiga peer simetris | Tidak bergantung pada satu host | Konsensus keadaan, timer, dan konflik input jauh lebih rumit | Ditolak |
| Multipeer Connectivity | Penemuan dan pesan bawaan | Seluruh framework didepresiasi pada Xcode 27 | Ditolak |
| Server internet | Dapat melayani jaringan berbeda | Melebihi cakupan playtest lokal | Ditolak |

## Keputusan Desain dan Sintesis

### Satu aliran keadaan, dua cara mengirim input

- **Generalisasi:** Permainan solo dan lokal memakai aturan ronde yang sama. Perbedaannya hanya pada sumber aksi dan tujuan snapshot.
- **Pendekatan:** Pertahankan `GameViewModel` sebagai mesin aturan. Koordinator sesi meneruskan aksi lokal/klien ke host dan mengirim salinan keadaan setelah setiap mutasi penting. Klien hanya menampilkan snapshot.
- **Alasan:** Menghindari dua implementasi pencampuran, timer, dan skor.
- **Batas:** Tidak menambahkan abstraksi game generik untuk jumlah pemain atau mode daring yang belum diminta.

### Adopsi transport platform, protokol game kecil

- **Bangun vs adopsi:** Adopsi Bonjour/TCP dari Network framework; bangun hanya pesan aplikasi, framing, validasi, dan sinkronisasi khusus ColorGameTesting.
- **Penyederhanaan:** Snapshot keadaan penuh untuk hanya tiga perangkat. Campuran dikirim sebagai jumlah per warna dalam urutan kemunculan pertama karena tampilan dan skor memakai proporsi serta urutan warna pertama, bukan urutan seluruh tap. Tidak ada penyimpanan event, migrasi host, layanan cloud, atau sinkronisasi daftar permintaan kustom.

### Pemulihan kursi saat koneksi sementara putus

- **Pendekatan:** Host menyimpan ID sesi dan token kursi sementara; klien mengirimkannya saat reconnect selama aplikasi masih berjalan. Setelah ketiga kursi tersambung, host mengirim keadaan mutakhir dan melanjutkan fase yang dijeda.
- **Trade-off:** Sesi tidak dapat dipulihkan setelah aplikasi ditutup, sesuai 7.3. Token sementara bukan autentikasi untuk jaringan tidak tepercaya.

## Risiko dan Mitigasi

- **Izin jaringan ditolak atau Bonjour terhalang oleh konfigurasi Wi-Fi:** tampilkan kegagalan dan coba lagi; validasi pada tiga perangkat fisik dalam satu Wi-Fi.
- **Aksi terlambat berdekatan dengan pergantian warna:** validasi ID warna terhadap riwayat penugasan berdasarkan revisi, bukan terhadap warna terbaru saja.
- **Snapshot lama atau aksi ganda setelah reconnect:** revisi keadaan monoton dan ID aksi untuk deduplikasi.
- **Koneksi TCP mati tanpa notifikasi cepat:** heartbeat aplikasi dan batas waktu mendeteksi peer hilang; host menjeda timer serta masukan.
- **Jaringan lokal tidak terenkripsi:** batasi pada playtest Wi-Fi tepercaya dan jangan mengirim data pribadi; rancangan ulang diperlukan sebelum penggunaan pada jaringan tak tepercaya.

## Referensi

- [TN3213: Moving from Multipeer Connectivity to Network framework](https://developer.apple.com/documentation/technotes/tn3213-moving-from-multipeer-connectivity-to-network-framework)
- [TN3179: Understanding local network privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy)
- [NWListener](https://developer.apple.com/documentation/network/nwlistener), [NWBrowser](https://developer.apple.com/documentation/network/nwbrowser), [NWConnection](https://developer.apple.com/documentation/network/nwconnection)
