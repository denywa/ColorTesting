# Desain Teknis: Permainan Lokal Tiga Perangkat

## Overview

Fitur ini memungkinkan tiga pemain menjalankan satu ronde ColorGameTesting pada tiga perangkat dalam Wi-Fi lokal yang sama. Satu perangkat menjadi host otoritatif; dua perangkat lain mengirim input warna dan menampilkan keadaan ronde yang dikirim host. Mode satu perangkat tetap menggunakan alur yang ada.

Desain mempertahankan GameViewModel sebagai pemilik aturan ronde. Lapisan sesi baru menangani penemuan, peran perangkat, perintah, snapshot, jeda, dan pemulihan. Tidak ada server internet atau penyimpanan sesi.

### Goals

- Tiga perangkat memperoleh peran unik dan satu keadaan ronde yang konsisten.
- Host menjadi satu-satunya pengendali pengaturan, waktu, hasil, dan perpindahan fase.
- Koneksi sementara yang putus menjeda sesi dan dapat dipulihkan tanpa mengganti peran atau kehilangan kontribusi yang telah diterima host.
- Alur tiga pemain pada satu perangkat tetap berfungsi.

### Non-Goals

- Permainan melalui internet, akun, migrasi host, skor individu, riwayat sesi, dan pemulihan setelah aplikasi ditutup.
- Sinkronisasi katalog permintaan warna kustom antarperangkat.
- Protokol keamanan untuk jaringan publik; versi playtest ini digunakan pada Wi-Fi tepercaya.

## Boundary Commitments

### This Spec Owns

- Pemilihan mode, lobi lokal, pembagian tiga peran, serta izin tindakan sesuai peran.
- Kontrak pesan lokal, transport antartiga perangkat, identitas sementara, urutan input, dan snapshot keadaan.
- Jeda/pemulihan koneksi, termasuk tampilan status dan penolakan aksi selama jeda.
- Integrasi mode lokal dengan GameViewModel dan tampilan yang sudah ada.
- Prasyarat implementasi: memulihkan tiga tes macOS yang sudah gagal sebelum fitur ini dibuat. Hanya nilai target Lavender bawaan yang dikembalikan ke nilai asalnya; ekspektasi tes nama, diagram campuran, dan sudut RYB diselaraskan dengan perilaku saat ini.

### Out of Boundary

- Algoritma pencampuran dan skor, aturan palet, serta validasi/penyimpanan permintaan kustom tetap dimiliki komponen yang ada. Pengecualian prasyarat di atas tidak mengubah algoritma atau palet.
- Tidak ada perubahan aturan permainan solo selain pintu masuk pemilihan mode.
- Tidak ada layanan cloud, akun, riwayat, atau migrasi host.

### Allowed Dependencies

- Aturan ronde memakai GameViewModel, GameState, GameModels, ColorData, ColorMixer, dan ScoreCalculator; lapisan jaringan tidak menghitung warna atau skor.
- Transport memakai Apple Network framework dan Foundation; UI memakai SwiftUI/Observation. Tidak ada paket pihak ketiga.
- Aliran dependensi: model/aturan game → mapper; model pesan → codec → transport; GameViewModel, mapper, dan transport → koordinator sesi → UI. GameViewModel tidak mengimpor Network framework.
- CustomRequestStore hanya dibaca oleh host melalui alur yang sudah ada; snapshot permintaan kustom tidak menulis ke penyimpanan klien.

### Revalidation Triggers

- Perubahan bentuk Round, NamedColor, ColorRequest, fase, timer, atau semantik Redo/Mix memerlukan pemeriksaan ulang mapper dan snapshot.
- Perubahan ID palet atau format pesan memerlukan pemeriksaan kompatibilitas protokol antarbinaan aplikasi.
- Perubahan target minimum OS, izin jaringan, atau kebutuhan bermain di jaringan publik/internet memerlukan pemeriksaan ulang transport dan keamanan.
- Perubahan jumlah pemain atau aturan kepemilikan input memerlukan pemeriksaan ulang peran, lobi, dan pengujian lintas perangkat.

## Architecture

### Existing Architecture Analysis

ContentView saat ini membuat satu GameViewModel dan langsung memilih SettingsView, GameView, ResultView, atau ScoreView. GameViewModel memegang pilihan pengaturan, penugasan acak, timer, campuran, hasil, serta skor. Dalam mode lokal, hanya instans host menjalankan mutasi dan timer tersebut. Instans klien menerima snapshot untuk rendering dan meneruskan input lokal; klien tidak mengacak, mencampur, atau menghitung skor sendiri.

### Architecture Pattern & Boundary Map

Pola yang dipilih adalah host otoritatif dengan snapshot penuh. Perintah masuk diserialisasi pada MainActor host. Setelah mutasi, host menaikkan revisi dan mengirim snapshot ke dua klien. Snapshot lama diabaikan klien. Koneksi TCP memberi urutan byte per koneksi, sedangkan ID aksi dan revisi menjaga idempotensi serta pemulihan lintas koneksi.

~~~mermaid
flowchart LR
    GV[ModeSelectionView dan layar game] --> CO[LocalPlayCoordinator]
    CO --> VM[GameViewModel host atau cermin klien]
    CO --> MP[LocalGameSnapshotMapper]
    CO --> TR[LocalNetworkTransport]
    TR --> CD[LocalMessageCodec]
    TR <-->|Bonjour dan TCP lokal| RT[Transport perangkat lain]
    VM --> RULE[ColorData, ColorMixer, ScoreCalculator]
~~~

Host selalu menempati Player 1; dua klien yang pertama diterima menempati Player 2 dan Player 3. Kursi disimpan selama proses aplikasi host hidup, termasuk ketika koneksi sementara putus. Perangkat keempat atau klien tanpa token kursi yang mencoba masuk setelah penuh ditolak.

### Technology Stack

| Lapisan | Pilihan / versi | Peran | Catatan |
|---|---|---|---|
| UI | SwiftUI + Observation; iOS 17+, macOS 27 | Pemilihan mode, lobi, tampilan ronde/peran | Komponen tampilan lama digunakan kembali |
| Aturan | Swift 5, GameViewModel yang ada | Keadaan dan timer otoritatif host | Klien hanya menerapkan snapshot |
| Jaringan | Network framework NWListener, NWBrowser, NWConnection | Bonjour lokal dan dua koneksi TCP | API NW lama dipilih untuk iOS 17 |
| Pesan | Foundation Codable JSON + bingkai panjang 32-bit | Perintah dan snapshot bertipe | Batas ukuran bingkai dan versi protokol |
| Penyimpanan | UserDefaults yang ada | Hanya permintaan kustom lokal | Sesi/round/token tidak disimpan |

Network framework dipilih karena [Apple mendepresiasi Multipeer Connectivity pada Xcode 27](https://developer.apple.com/documentation/technotes/tn3213-moving-from-multipeer-connectivity-to-network-framework). Listener mengiklankan layanan Bonjour _colorgame._tcp, browser mencari tipe yang sama pada domain lokal, dan koneksi dibatasi ke jalur Wi-Fi tanpa fallback seluler. Host memakai satu listener; klien tidak membuka listener. Sesuai [aturan privasi jaringan lokal Apple](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy), kedua target mendeklarasikan NSLocalNetworkUsageDescription dan NSBonjourServices. Target macOS yang disandbox memberi entitlement network.server dan network.client. Detail sumber ada di research.md.

Kunci NSBonjourServices harus berupa array berisi _colorgame._tcp pada Info.plist hasil build, bukan string biasa. File entitlement macOS memuat app-sandbox = true bersama network.server dan network.client. Integrasi build memverifikasi bentuk plist hasil build sebelum uji perangkat.

## File Structure Plan

### Directory Structure

~~~text
ColorGameTesting/
├── LocalPlay/
│   ├── LocalPlayModels.swift          # Peran, keadaan sesi, DTO snapshot, dan pesan bertipe
│   ├── LocalMessageCodec.swift        # JSON, versi protokol, dan pembingkaian panjang TCP
│   ├── LocalNetworkTransport.swift    # Kontrak LocalPeerTransport, Bonjour, koneksi, heartbeat, callback
│   ├── LocalGameSnapshotMapper.swift  # Peta dan validasi GameViewModel ↔ snapshot
│   └── LocalPlayCoordinator.swift     # Kursi, otoritas host, aksi, revisi, jeda, dan pemulihan
├── Views/
│   ├── ModeSelectionView.swift        # Pilihan satu atau tiga perangkat
│   └── LocalLobbyView.swift           # Buat/cari/gabung sesi, peran, status, dan kegagalan
└── ColorGameTesting.entitlements       # Hak jaringan masuk/keluar target macOS

ColorGameTestingTests/
├── LocalMessageCodecTests.swift       # Bingkai dan validasi pesan
├── LocalGameSnapshotMapperTests.swift # Target kustom dan round-trip keadaan
└── LocalPlayCoordinatorTests.swift    # Tiga peer melalui transport palsu
~~~

### Modified Files

- ColorGameTesting/ContentView.swift — memilih mode, memiliki koordinator sesi, merutekan lobi atau layar game, serta menyediakan tindakan Akhiri Sesi untuk host/Keluar untuk klien pada setiap fase lokal; mode solo tetap memakai GameViewModel yang sama.
- ColorGameTesting/GameViewModel.swift — menambahkan hook perubahan keadaan untuk host, penerapan snapshot klien tanpa timer lokal, dan jalur input lokal yang bisa diteruskan; mutasi aturan tetap berada di sini.
- ColorGameTesting/Views/SettingsView.swift — host mengatur ronde lokal; tombol Start dibatasi tiga kursi terhubung; klien melihat status baca saja di lobi.
- ColorGameTesting/Views/GameView.swift — hanya dua input peran lokal aktif; hanya host melihat Mix; status jeda ditampilkan.
- ColorGameTesting/Views/ResultView.swift — Redo dan Finish dirutekan melalui koordinator, hanya untuk host dan tidak tersedia saat jeda.
- ColorGameTesting/Views/ScoreView.swift — New Round dirutekan melalui koordinator, hanya untuk host dan tidak tersedia saat jeda.
- ColorGameTesting2.xcodeproj/project.pbxproj — kunci Info.plist Bonjour/privasi pada target iOS dan macOS serta referensi entitlement macOS.
- ColorGameTesting/ColorData.swift — hanya mengembalikan nilai target Lavender bawaan ke C8B4F4 sebelum pekerjaan fitur dimulai.
- ColorGameTestingTests/ColorDataTests.swift, ColorMixerTests.swift, dan GameViewRenderingTests.swift — menyelaraskan regresi yang sudah gagal dengan perilaku yang ditetapkan dalam riwayat kode; tidak mengubah aturan pencampuran atau tampilan produksi.
- ColorGameTestingTests/ContentViewTests.swift dan pengujian rendering/flow terkait — menyesuaikan pintu masuk mode dan hak kontrol lokal tanpa mengurangi cakupan mode solo.

Setiap komponen baru mempunyai satu berkas utama. Selain pemulihan nilai Lavender di atas, tidak ada perubahan pada ColorMixer, ScoreCalculator, ColorData, atau CustomRequestStore.

Sesudah prasyarat baseline selesai, dependensi baca-saja tetap berada di ColorGameTesting/ColorData.swift, ColorGameTesting/ColorMixer.swift, ColorGameTesting/ScoreCalculator.swift, ColorGameTesting/CustomRequestStore.swift, dan ColorGameTesting/GameState.swift.

Lobi dan status jeda memakai label peran/keadaan yang terbaca pembaca layar; tombol warna mempertahankan nama warna yang dapat diakses. Menyembunyikan kontrol host pada klien juga menghapusnya dari urutan fokus.

## System Flows

~~~mermaid
sequenceDiagram
    participant H as Host
    participant C as Klien
    participant N as Transport lokal
    H->>N: Iklankan sesi Bonjour
    C->>N: Temukan dan hubungi host
    C->>H: Hello versi dan identitas sementara
    H->>C: Welcome kursi dan token pemulihan
    H->>C: Snapshot revisi awal
    H->>H: Mulai ronde jika 3 kursi aktif
    H->>C: Snapshot ronde dan penugasan
    C->>H: Input ID, ronde, slot, warna terlihat, epoch
    H->>H: Validasi, deduplikasi, tambah ke campuran
    H->>C: Snapshot revisi berikutnya
    N-->>H: Klien terputus
    H->>H: Jeda timer dan semua aksi
    H->>C: Snapshot jeda ke klien yang tersisa
    C->>H: Reconnect dengan token kursi
    H->>C: Snapshot penuh terbaru
    H->>H: Lanjutkan jika 3 kursi aktif
    H->>C: Snapshot lanjut
~~~

Urutan fase tetap settings → playing → result → score → settings. Jeda adalah status sesi yang dapat melapisi fase mana pun setelah ronde dimulai; fase dan sisa waktu tidak berubah ketika peer hilang. Saat perangkat masuk latar belakang dan koneksi tidak lagi aktif, perlakukan sebagai putus sementara; saat kembali ke depan, coba sambung ulang.

Di lobi, host melihat pengaturan ronde bersama dengan status tiga kursi; tamu hanya melihat status baca-saja. Saat host masuk latar belakang, koordinator menjeda ronde sebelum sistem menangguhkan aplikasi. Mode solo tidak memulai browser atau listener jaringan.

~~~mermaid
stateDiagram-v2
    [*] --> PilihMode
    PilihMode --> Lobi: pilih tiga perangkat
    PilihMode --> Solo: pilih satu perangkat
    Lobi --> Bermain: host mulai dengan tiga kursi
    Bermain --> Hasil: host Mix
    Hasil --> Bermain: host Redo
    Hasil --> Skor: host Finish
    Skor --> Lobi: host New Round
    Bermain --> Jeda: peer terputus
    Hasil --> Jeda: peer terputus
    Skor --> Jeda: peer terputus
    Jeda --> Bermain: pulih ke fase bermain
    Jeda --> Hasil: pulih ke fase hasil
    Jeda --> Skor: pulih ke fase skor
    Lobi --> PilihMode: keluar sesi
    Jeda --> PilihMode: keluar sesi
~~~

## Requirements Traceability

| Requirement | Ringkasan | Komponen | Kontrak / alur |
|---|---|---|---|
| 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8 | Pilih mode, temukan sesi, isi tiga kursi | ModeSelectionView, LocalLobbyView, LocalPlayCoordinator, LocalNetworkTransport | Bonjour, Hello/Welcome, status kursi |
| 2.1, 2.2, 2.3, 2.4, 2.5 | Pengaturan host dan target kustom | SettingsView, GameViewModel, LocalGameSnapshotMapper | Snapshot target lengkap |
| 3.1, 3.2, 3.3, 3.4, 3.5, 3.6 | Input milik peran dan campuran konsisten | GameView, GameViewModel, LocalPlayCoordinator | Input ID/epoch, snapshot revisi |
| 4.1, 4.2, 4.3, 4.4 | Timer dan penugasan bersama | GameViewModel, LocalPlayCoordinator, LocalGameSnapshotMapper | Snapshot detik/epoch, riwayat penugasan |
| 5.1, 5.2, 5.3, 5.4, 5.5, 5.6 | Mix, Redo, Finish, New Round | GameViewModel, LocalPlayCoordinator, GameView, ResultView, ScoreView | Perintah host, snapshot fase |
| 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7 | Jeda, reconnect, keluar | LocalNetworkTransport, LocalPlayCoordinator, LocalLobbyView | Heartbeat, token kursi, snapshot penuh, End |
| 7.1, 7.2, 7.3, 7.4 | Mode solo dan batas lokal | ContentView, LocalPlayCoordinator, LocalNetworkTransport | Pemilihan mode, siklus hidup proses, Wi-Fi |

## Components and Interfaces

| Komponen | Lapisan / maksud | Cakupan | Dependensi kunci | Kontrak |
|---|---|---|---|---|
| LocalPlayModels | Model pesan dan sesi bertipe | 1.3, 1.4, 3.3, 3.4, 4.1, 5.2, 6.3, 7.2 | Foundation | State, Event |
| LocalMessageCodec | Pembingkaian dan validasi dasar | 1.7, 3.6, 6.3 | LocalPlayModels | Service |
| LocalNetworkTransport | Penemuan dan koneksi lokal | 1.2, 1.6, 1.7, 1.8, 6.1, 6.3, 6.5, 6.6, 7.4 | Network framework, codec | Service, Event |
| LocalGameSnapshotMapper | Representasi keadaan lintas perangkat | 2.2, 2.3, 2.5, 3.1, 3.4, 4.1, 4.2, 5.2, 5.4, 6.3, 6.4 | GameViewModel, model, ColorData | Service |
| LocalPlayCoordinator | Otoritas sesi dan sinkronisasi | 1.3, 1.4, 1.5, 1.6, 2.1, 2.4, 3.2, 3.3, 3.5, 3.6, 4.4, 5.1, 5.5, 5.6, 6.1, 6.4, 6.6, 6.7, 7.2, 7.3 | Transport, mapper, GameViewModel | Service, State |
| GameViewModel | Aturan ronde yang sudah ada | 2.2, 2.3, 3.3, 4.1, 4.2, 4.3, 5.2, 5.3, 5.4, 5.5, 7.1 | Model/aturan warna | State, Service |
| ModeSelectionView / LocalLobbyView dan layar lama | Presentasi serta input sesuai peran | 1.1, 1.4, 1.7, 2.1, 2.4, 3.1, 3.2, 3.5, 5.1, 5.6, 6.2, 6.7, 7.1 | Koordinator, view model | State |

### Model dan transport

#### LocalPlayModels

- **Tanggung jawab:** Menetapkan PlayMode, SessionRole, SessionStatus, DiscoveredSession, PeerHandle, LocalGameAction, GameSnapshot, WireMessage, dan LocalPlayError sebagai tipe Swift eksplisit. LocalPlayError membedakan izin ditolak, Wi-Fi tidak tersedia, sesi penuh, versi berbeda, pesan tidak valid, dan koneksi putus. Tidak memuat aturan warna atau kode jaringan.
- **Invarian:** Tepat satu host dan maksimal dua klien; setiap kursi PlayerID unik. ID sesi, ID ronde, ID aksi, dan token kursi berupa UUID sementara. ProtocolVersion wajib cocok.
- **Dependensi:** Inbound dari codec/mapper/koordinator (P0); outbound ke Foundation (P0).
- **Kontrak:** State [x], Event [x].

#### LocalMessageCodec

- **Tanggung jawab:** Mengode/dekode WireMessage sebagai JSON Codable dan bingkai 32-bit panjang-jaringan. Parser menampung paket TCP parsial, memisahkan paket gabungan, dan menolak panjang yang melebihi batas 1 MiB atau payload tak valid.
- **Dependensi:** Inbound LocalNetworkTransport (P0); outbound LocalPlayModels/Foundation (P0).
- **Kontrak:** Service [x].
- **Antarmuka:** encode(WireMessage) throws -> Data; append(Data) throws -> [WireMessage]. Decoder per koneksi memiliki buffer sendiri; kesalahan framing menutup koneksi itu.

#### LocalNetworkTransport

- **Tanggung jawab:** Iklan/pencarian layanan, koneksi, kirim/terima bingkai, status peer, dan heartbeat. Tidak mengetahui Round, skor, atau peran pemain.
- **Dependensi:** Inbound LocalPlayCoordinator (P0); outbound Network framework (P0), LocalMessageCodec (P0).
- **Kontrak:** Service [x], Event [x].
- **Antarmuka:** LocalPeerTransport menetapkan host(serviceName) throws; browse(); connect(DiscoveredSession); send(WireMessage, to: PeerHandle) async throws; stop(). Implementasi LocalNetworkTransport memakai Network framework; pengujian memakai transport palsu. Event bertipe discovered, connected, disconnected, received, dan failure, semuanya dikirim ke MainActor koordinator. Kegagalan dipetakan ke LocalPlayError.
- **Prasyarat:** Izin jaringan lokal tersedia dan jalur Wi-Fi aktif. Browser menampilkan sesi Bonjour yang tersedia; listener host tidak menerima lebih dari dua klien aktif.
- **Pemulihan:** Heartbeat tiap 3 detik dengan batas 9 detik tanpa respons mendeteksi koneksi idle yang mati; konstanta waktu dapat diuji dengan jam injeksi. Koneksi gagal dibatalkan dan dibuat ulang melalui layanan yang ditemukan. Jika listener host gagal akibat hilangnya Wi-Fi, koordinator tetap menyimpan sesi dalam keadaan jeda dan transport membuat listener/iklan baru saat Wi-Fi pulih. Koneksi reconnect yang membawa token kursi sah menggantikan koneksi lama bila perlu; peer baru tetap ditolak saat dua kursi klien terisi. Kesalahan izin/layanan dipetakan ke pesan yang bisa dicoba lagi.

### Orkestrasi dan aturan

#### LocalGameSnapshotMapper

- **Tanggung jawab:** Membuat snapshot lengkap dari keadaan host dan menerapkannya ke view model klien; memvalidasi ID warna, rentang komponen, fase, serta target kustom.
- **Dependensi:** Inbound LocalPlayCoordinator (P0); outbound GameViewModel/GameState/ColorData (P0).
- **Kontrak:** Service [x].
- **Antarmuka:** makeSnapshot(from: GameViewModel, session: SessionState) throws -> GameSnapshot; apply(GameSnapshot, to: GameViewModel) throws. Klien tidak memanggil operasi aturan saat apply.
- **Invarian:** Snapshot ronde membawa target dengan ID, teks, dan sRGB; model/durasi/petunjuk; semua penugasan; jumlah unit tiap warna dalam urutan kemunculan pertamanya; lock; fase; hasil/skor; sisa detik; status jeda/kursi. Saat masih di pengaturan, target, ronde, dan penugasan boleh kosong. ID palet harus dikenal pada kedua perangkat dengan versi protokol sama. CustomRequestStore klien tidak ditulis.

#### LocalPlayCoordinator

- **Tanggung jawab:** Menghubungkan aksi UI dan jaringan ke satu GameViewModel host, mengelola kursi, validasi input, revisi keadaan, jeda, serta reconnect. Koordinator klien hanya mengirim input miliknya dan menerapkan snapshot.
- **Dependensi:** Inbound ContentView/layar (P0); outbound GameViewModel (P0), LocalGameSnapshotMapper (P0), LocalNetworkTransport (P0).
- **Kontrak:** Service [x], State [x], Event [x].
- **Antarmuka:** chooseMode(PlayMode); startHosting(); startBrowsing(); join(DiscoveredSession); perform(LocalGameAction); leaveSession(); handle(TransportEvent). LocalGameAction berisi startRound, addColor(slot, observedColorID, assignmentEpoch), mix, redo, finish, dan newRound. Keadaan observable: mode, role, seatStatus, connectionStatus, paused, error, discoveredSessions.
- **Aturan host:** Semua mutasi pada MainActor. Host hanya menerima pengaturan dan perpindahan fase dari dirinya sendiri. Input host lokal dan input peer melewati validasi yang sama; input peer dipetakan ke kursi menurut koneksinya, bukan peran yang diklaim payload. Perintah harus cocok dengan sesi/ronde, slot, warna yang ditampilkan pada assignmentEpoch, serta ID aksi yang belum diterima; riwayat penugasan disimpan selama ronde untuk aksi yang terlambat. Input saat paused, bukan playing, atau mix locked ditolak. Host menaikkan snapshotRevision setelah setiap mutasi termasuk tick, reassignment, dan jeda.
- **Aturan klien:** Klien tidak mengubah campuran secara optimistis, tidak menjalankan timer atau skor, dan membuang snapshot dengan sessionID salah atau revisi tidak lebih baru. Saat disconnected, seluruh input dinonaktifkan; rejoin memakai token kursi sementara lalu snapshot penuh.
- **Siklus ronde:** New Round mengosongkan GameState host sesuai aturan lama tetapi mempertahankan sesi, kursi, serta koneksi. End Session mengirim pesan End dan menutup transport.

#### GameViewModel

- **Perubahan kontrak:** Hook didChange memicu snapshot host setelah mutasi publik/tick; applyRemoteState memperbarui data render klien tanpa menyalakan timer, tetapi memasang/melepas monitor keyboard sesuai fase bermain; localInputHandler mengarahkan tombol/keyboard ke koordinator. Keyboard macOS hanya meneruskan tombol yang memetakan ke peran lokal pada mode tiga perangkat. Jalur solo tetap memakai mutasi lama.
- **Batas:** Tidak memiliki jenis pesan, identitas jaringan, atau retry. Host memanggil mutasi aturan yang ada; penambahan warna yang membawa assignmentEpoch memakai warna tervalidasi oleh koordinator, tanpa mengubah rumus campuran.

### Kontrak pesan dan keadaan

| Pesan | Pengirim → penerima | Muatan utama | Urutan dan idempotensi |
|---|---|---|---|
| Hello | Klien → host | protocolVersion, clientID sementara, sessionID/token jika reconnect | Satu per koneksi; token divalidasi host |
| Welcome / Reject | Host → klien | sessionID, kursi, token baru atau alasan penolakan | Welcome sebelum snapshot |
| Input | Klien → host | actionID, roundID, slot, observedColorID, assignmentEpoch | Host deduplikasi actionID; peer menentukan kursi |
| Snapshot | Host → klien | GameSnapshot lengkap + sessionID + snapshotRevision | Revisi monoton; klien membuang yang lama |
| Heartbeat | Dua arah | sessionID, nomor ping | Tidak mengubah game |
| End | Host → klien | sessionID, alasan akhir | Klien kembali ke pemilihan mode |

Snapshot adalah pengganti keadaan penuh, bukan delta. Host menyiarkannya setelah setiap input yang diterima, tick timer, pergantian warna, perpindahan fase, perubahan kursi, dan jeda/lanjut. Klien tidak menganggap input berhasil sebelum campuran host muncul dalam snapshot. Input yang tidak sampai ke host sebelum koneksi putus tidak masuk campuran pemulihan; tidak ada replay input setelah jeda. ID aksi tetap mencegah pemrosesan ganda bila pesan duplikat diterima.

## Data Models

### Domain Model

Satu SessionState memuat sessionID, host, tiga Seat, status koneksi, status paused, dan snapshotRevision. Seat mengikat PlayerID ke clientID/token sementara. Satu RoundState tetap dimiliki GameViewModel host. AssignmentEpoch bertambah tiap pengacakan dalam ronde; RoundID baru pada setiap Start Round. AcceptedActionIDs adalah himpunan per ronde untuk deduplikasi; AssignmentHistory memetakan epoch ke dua warna per pemain. Tidak ada data sesi yang dipersistenkan.

### Logical Data Model

GameSnapshot berisi phase, roundID opsional, selectedModel opsional, target lengkap yang opsional sebelum ronde, reassignmentDuration, showTargetColor, timerSecondsRemaining, assignmentEpoch opsional sebelum ronde, assignments untuk tiga pemain saat bermain, mixEntries berupa pasangan colorID/count dalam urutan kemunculan pertama, mixLocked, mixResult opsional, score opsional, paused, seatStatus, dan snapshotRevision. Warna target memakai tiga komponen Double eksplisit yang wajib finite. Mapper klien menyusun satu unit untuk tiap warna sesuai urutan mixEntries, kemudian menambah sisa unit menurut count; ini mempertahankan proporsi dan urutan tampilan tanpa mengirim seluruh daftar tap. Penugasan dan campuran direkonstruksi dari ColorData dengan ID warna stabil; decoder menolak ID asing, count negatif, atau komponen non-finite. Payload target lengkap memungkinkan permintaan kustom host ditampilkan tanpa menyalinnya ke daftar tersimpan klien.

### Data Contracts & Integration

- Versi protokol tetap pada setiap Hello dan snapshot; versi yang tidak cocok menghasilkan Reject dengan alasan pembaruan aplikasi.
- Semua UUID, enum, dan angka dikodekan secara eksplisit. Data dari jaringan divalidasi sebelum dipakai oleh GameViewModel.
- Batas 1 MiB per bingkai mencegah panjang tak masuk akal; ukuran campuran playtest dipantau. Revisi meningkat sepanjang sesi, tidak direset saat New Round.
- Endpoint Bonjour hanya menemukan dan menghubungkan perangkat lokal; tidak ada alamat internet tetap atau basis data.

## Error Handling

### Error Strategy

- Izin jaringan ditolak, Wi-Fi tidak tersedia, atau sesi tidak ditemukan: lobi menampilkan alasan dan tombol Coba Lagi; mode solo tetap dapat dipilih.
- Lobi penuh atau versi protokol berbeda: host mengirim Reject, klien tetap di daftar sesi; host tidak mengubah kursi.
- Pesan tak valid, peran salah, atau aksi duplikat: host tidak memutasi ronde; kesalahan protokol berat menutup koneksi, aksi game yang ditolak mendapat snapshot mutakhir.
- Koneksi hilang setelah ronde dimulai: host pauseTimer, menandai peer terputus, menolak input/perpindahan fase, menyiarkan status jeda; klien yang kehilangan host menunjukkan status menunggu dan tombol Keluar.
- Host memilih Akhiri Sesi: kirim End, tutup koneksi, semua perangkat kembali ke pemilihan mode. Penutupan aplikasi mendadak tidak memulihkan sesi; peer yang tersisa dapat memilih Keluar.

### Monitoring

Log lokal terstruktur untuk perubahan koneksi, alasan Reject, nomor revisi, dan aksi yang diabaikan; jangan mencatat token kursi atau seluruh payload target. Status lobi dan jeda menjadi indikator utama saat playtesting.

## Testing Strategy

### Unit Tests

- LocalMessageCodecTests: bingkai terpotong/bergabung, ukuran berlebih, payload rusak, dan versi tak cocok (1.7, 6.3).
- LocalGameSnapshotMapperTests: round-trip target kustom, penugasan, urutan Mix, hasil/skor, serta penolakan ID warna asing; katalog klien tetap lokal (2.2, 2.3, 2.4, 2.5, 3.4, 5.2, 5.3, 5.4).
- LocalPlayCoordinatorTests: kursi unik, batas tiga perangkat, start hanya saat lengkap, kendali host, dan pembatasan input peran (1.3, 1.4, 1.5, 1.6, 2.1, 3.2, 5.6).
- LocalPlayCoordinatorTests: dua input hampir serentak, kirim ulang ID yang sama, input epoch lama di batas pergantian, serta snapshot lama (3.3, 3.6, 4.2, 4.3, 4.4).
- LocalPlayCoordinatorTests: putus/jeda, reconnect token yang sama, snapshot penuh, sisa waktu, End, dan New Round yang mempertahankan kursi (5.5, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7).

### Integration Tests

- Transport palsu tiga peer menjalankan host → dua klien → Start → input → Mix → Redo → Finish → New Round; bandingkan snapshot/phase semua peer dengan host (1.3, 1.5, 2.2, 3.3, 3.4, 4.1, 5.2, 5.3, 5.4, 5.5).
- Simulasi putus salah satu klien dan host, input tertunda, sambung ulang, lalu pastikan tidak ada mutasi selama jeda dan satu campuran akhir (3.5, 3.6, 6.1, 6.2, 6.3, 6.4).
- Tes rendering mode/lobi/role, hanya dua input lokal dan kontrol host, status jeda, serta regresi mode satu perangkat (1.1, 3.1, 3.2, 5.1, 5.6, 7.1).

### Uji Perangkat Fisik

- Pada tiga perangkat Apple yang menjalankan aplikasi di satu Wi-Fi: izin jaringan lokal, penemuan, tiga kursi, target kustom host, timer/penugasan, kontribusi hampir bersamaan, hasil/Redo/skor/New Round, dan penolakan perangkat keempat (1.2, 1.3, 1.6, 2.3, 3.6, 4.2, 5.2, 5.3, 5.4, 5.5, 7.4).
- Matikan sementara Wi-Fi salah satu perangkat lalu hidupkan kembali; amati jeda, pemulihan peran dan sisa waktu, serta kemampuan keluar jika host tidak kembali (6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7).
- Jalankan skema uji macOS yang ada untuk aturan solo. Simulator tidak menggantikan uji izin Bonjour/perangkat fisik.

## Security Considerations

Versi awal hanya untuk Wi-Fi tepercaya. TCP tanpa TLS berarti perangkat lain pada jaringan yang sama berpotensi membaca atau mengirim pesan; jangan kirim akun atau data pribadi. Host membatasi kursi, memvalidasi pesan, serta memakai token acak sementara untuk pemulihan kursi, tetapi token ini bukan autentikasi terhadap penyadap jaringan. Kebutuhan jaringan publik, internet, atau data sensitif memicu desain ulang TLS, verifikasi peer, dan pemasangan perangkat sebelum implementasi tersebut.

## Performance & Scalability

Skala tetap tiga perangkat. Snapshot penuh pada tiap tick/input menyederhanakan konsistensi; mixEntries berisi maksimal lima warna palet sehingga ukuran pesan tetap kecil, dengan batas bingkai 1 MiB untuk menolak payload rusak. Tidak ada target latensi yang ditetapkan kebutuhan; uji fisik mencatat keterlambatan tampilan campuran/timer dan ukuran snapshot untuk menentukan apakah optimasi kelak diperlukan.
