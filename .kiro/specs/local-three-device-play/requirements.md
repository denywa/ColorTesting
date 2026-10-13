# Dokumen Kebutuhan: Permainan Lokal Tiga Perangkat

## Pendahuluan

Tiga orang dapat memainkan satu ronde ColorGameTesting secara bersamaan pada tiga perangkat yang terhubung ke jaringan Wi-Fi lokal yang sama. Satu pemain menjadi host dan dua pemain lain bergabung. Playtesting Part II memakai RYB saja, menyediakan Manual Mix dan Auto Mix, serta menjalankan Mix, Finish/Apply, atau Redo setelah dua pemain memilih tindakan yang sama. Setiap pemain mengendalikan dua warna yang ditugaskan kepadanya, sementara target, campuran, waktu, hasil, dan skor berlaku untuk seluruh sesi.

## Konteks Batasan

- **Termasuk:** pembuatan dan penggabungan sesi lokal untuk tepat tiga perangkat, pembagian satu peran pemain per perangkat, pengaturan bersama oleh host, pemungutan suara mayoritas untuk Mix, Finish/Apply, dan Redo, sinkronisasi ronde, serta jeda dan pemulihan saat koneksi terputus.
- **Di luar cakupan:** bermain melalui internet, akun pemain, skor per pemain, riwayat atau pemulihan sesi setelah aplikasi ditutup, dan sinkronisasi daftar permintaan warna kustom antarperangkat.
- **Keterkaitan:** aturan RYB, dua warna berbeda per pemain, Manual/Auto Mix, dan penilaian mengikuti ronde bersama. Mode satu perangkat tetap menjalankan tindakan secara langsung tanpa pemungutan suara.

## Kebutuhan

### Requirement 1: Memulai dan bergabung ke sesi lokal

**Tujuan:** Sebagai kelompok tiga pemain, kami ingin bergabung ke satu sesi lokal agar dapat memainkan ronde yang sama dari perangkat masing-masing.

#### Kriteria Penerimaan

1. When pemain memilih mode tiga perangkat, the ColorGameTesting app shall menampilkan pilihan untuk membuat sesi sebagai host atau bergabung ke sesi sebagai pemain lain.
2. When host membuat sesi, the ColorGameTesting app shall menampilkan sesi tersebut kepada perangkat lain yang menjalankan aplikasi pada jaringan Wi-Fi lokal yang sama.
3. When host membuat sesi atau perangkat lain bergabung, the ColorGameTesting app shall menetapkan satu peran pemain yang unik kepada setiap perangkat dan menampilkan peran itu pada perangkat terkait.
4. When jumlah perangkat dalam sesi berubah, the ColorGameTesting app shall menampilkan status keterhubungan dan peran ketiga pemain kepada seluruh perangkat yang terhubung.
5. While kurang dari tiga perangkat terhubung, the ColorGameTesting app shall mencegah host memulai ronde bersama.
6. If ketiga peran pemain sudah terisi, the ColorGameTesting app shall menolak perangkat tambahan untuk bergabung ke sesi tersebut.
7. If perangkat tidak dapat menemukan atau bergabung ke sesi, the ColorGameTesting app shall menampilkan pesan bahwa sesi tidak tersedia atau sambungan gagal, beserta pilihan untuk mencoba lagi.
8. The ColorGameTesting app shall memungkinkan sesi lokal dimulai tanpa akun pemain atau koneksi internet.

### Requirement 2: Pengaturan ronde bersama

**Tujuan:** Sebagai host, saya ingin memilih pengaturan sekali agar semua pemain menjalani ronde yang sama.

#### Kriteria Penerimaan

1. While sesi tiga perangkat aktif, the ColorGameTesting app shall membatasi pemilihan mode Manual Mix atau Auto Mix, permintaan target, durasi pergantian warna, dan petunjuk warna target kepada host.
2. When host memulai ronde setelah tiga perangkat terhubung dan pengaturan wajib terpenuhi, the ColorGameTesting app shall menerapkan RYB, mode campur, permintaan target, durasi pergantian, dan pilihan petunjuk yang sama pada semua perangkat.
3. When host memilih permintaan warna kustom yang tersedia pada perangkatnya, the ColorGameTesting app shall menggunakan teks dan warna target permintaan tersebut untuk ronde bersama pada semua perangkat.
4. While pemain lain berada dalam sesi host, the ColorGameTesting app shall mencegah mereka mengubah pengaturan ronde bersama.
5. When pemain lain bergabung ke sesi, the ColorGameTesting app shall mempertahankan daftar permintaan warna kustom tersimpan pada perangkatnya tanpa menambahkan permintaan milik host.
6. While host menyiapkan ronde tiga perangkat, the ColorGameTesting app shall menyediakan RYB sebagai satu-satunya palet warna.
7. While pengaturan ronde baru ditampilkan kepada host, the ColorGameTesting app shall memilih Manual Mix secara bawaan.

### Requirement 3: Kontribusi pemain ke satu campuran

**Tujuan:** Sebagai pemain, saya ingin mengendalikan warna yang ditugaskan kepada saya dan melihat campuran kelompok berkembang.

#### Kriteria Penerimaan

1. When ronde dimulai, the ColorGameTesting app shall menampilkan peran pemain, dua warna berbeda yang saat itu ditugaskan kepadanya, permintaan target, waktu tersisa, dan campuran bersama pada setiap perangkat.
2. While ronde berlangsung, the ColorGameTesting app shall menerima masukan warna pada suatu perangkat hanya untuk dua slot milik peran pemain perangkat tersebut.
3. When pemain mengaktifkan salah satu input warna yang ditugaskan kepadanya, the ColorGameTesting app shall menambahkan tepat satu unit warna yang terlihat pada slot saat input dilakukan ke satu campuran bersama.
4. When kontribusi pemain diterima dalam Manual Mix, the ColorGameTesting app shall menampilkan jumlah dan proporsi campuran yang sama pada ketiga perangkat.
5. If masukan dilakukan di luar fase bermain, saat sesi dijeda, atau setelah campuran dikunci, the ColorGameTesting app shall mengabaikan masukan tersebut tanpa mengubah campuran.
6. When dua atau lebih pemain menekan warna hampir bersamaan, the ColorGameTesting app shall mempertahankan setiap kontribusi yang diterima tepat satu kali dalam campuran bersama.
7. When kontribusi warna diterima dalam Auto Mix, the ColorGameTesting app shall memperbarui warna campuran yang terlihat pada ketiga perangkat tanpa menunggu tindakan Mix.

### Requirement 4: Waktu dan pergantian warna bersama

**Tujuan:** Sebagai pemain, saya ingin melihat pergantian warna pada waktu yang sama agar aturan ronde tetap adil.

#### Kriteria Penerimaan

1. While ronde berlangsung, the ColorGameTesting app shall menampilkan satu hitung mundur bersama pada semua perangkat.
2. When hitung mundur mencapai nol, the ColorGameTesting app shall memperbarui dua warna berbeda yang ditugaskan kepada setiap pemain dan memulai ulang hitung mundur untuk seluruh sesi.
3. When warna pemain berganti, the ColorGameTesting app shall mempertahankan seluruh unit warna yang sudah masuk ke campuran.
4. When masukan warna diterima berdekatan dengan pergantian warna, the ColorGameTesting app shall menghitung warna yang terlihat pada slot pemain saat masukan dilakukan, tanpa menggantinya diam-diam dengan warna baru.

### Requirement 5: Hasil, penilaian, dan ronde berikutnya

**Tujuan:** Sebagai kelompok, kami ingin meninjau satu hasil dan satu skor untuk campuran yang kami buat bersama.

#### Kriteria Penerimaan

1. While Manual Mix berlangsung dan campuran berisi sedikitnya satu unit warna, the ColorGameTesting app shall menawarkan suara Mix kepada ketiga pemain.
2. When suara Mix mencapai mayoritas dalam Manual Mix, the ColorGameTesting app shall menghentikan hitung mundur, menutup masukan warna, dan menampilkan hasil campuran serta rincian kontribusi yang sama pada semua perangkat.
3. While hasil Manual Mix ditampilkan, the ColorGameTesting app shall menawarkan suara Redo dan Finish kepada ketiga pemain.
4. When suara Redo mencapai mayoritas dari hasil Manual Mix, the ColorGameTesting app shall mengosongkan campuran dan hasil pada semua perangkat, mempertahankan target serta penugasan warna terakhir, lalu melanjutkan ronde dengan sisa waktu yang sama.
5. When suara Finish mencapai mayoritas dari hasil Manual Mix, the ColorGameTesting app shall menampilkan satu skor kecocokan kelompok yang sama pada semua perangkat.
6. While Auto Mix berlangsung dan campuran berisi sedikitnya satu unit warna, the ColorGameTesting app shall menawarkan suara Apply dan Redo kepada ketiga pemain pada fase bermain yang sama.
7. When suara Apply mencapai mayoritas dalam Auto Mix, the ColorGameTesting app shall menampilkan warna campuran terakhir, warna target, dan satu skor kecocokan kelompok yang sama pada semua perangkat.
8. When suara Redo mencapai mayoritas dalam Auto Mix, the ColorGameTesting app shall mengosongkan campuran pada semua perangkat dan tetap berada dalam fase bermain dengan target, penugasan, dan sisa waktu yang sama.
9. When host memilih New Round dari skor, the ColorGameTesting app shall mengembalikan semua perangkat ke pengaturan ronde dalam sesi yang sama, dengan peran pemain tetap terisi.
10. While sesi tiga perangkat aktif, the ColorGameTesting app shall membatasi tindakan New Round kepada host.
11. When suara Apply mencapai mayoritas dalam Auto Mix, the ColorGameTesting app shall menghentikan hitung mundur dan kontribusi warna pada semua perangkat.

### Requirement 6: Koneksi terputus dan pemulihan

**Tujuan:** Sebagai pemain, saya ingin ronde berhenti saat salah satu perangkat terputus dan dapat dilanjutkan tanpa kehilangan hasil kerja kelompok.

#### Kriteria Penerimaan

1. If salah satu dari tiga perangkat terputus setelah ronde dimulai, the ColorGameTesting app shall menjeda hitung mundur jika sedang berjalan dan menolak kontribusi warna serta tindakan perpindahan fase pada perangkat yang masih terhubung.
2. When sesi dijeda karena perangkat terputus, the ColorGameTesting app shall menampilkan pemain yang terputus dan status menunggu sambungan kembali pada perangkat yang masih terhubung.
3. When perangkat yang terputus tersambung kembali ke sesi yang sama, the ColorGameTesting app shall mengembalikan peran pemain dan keadaan ronde terakhir yang sama pada perangkat tersebut.
4. When ketiga perangkat kembali terhubung, the ColorGameTesting app shall melanjutkan fase yang terjeda dari campuran, penugasan warna, hasil, skor, dan sisa waktu yang sudah diterima sebelum jeda.
5. If perangkat terputus sebelum ronde dimulai, the ColorGameTesting app shall memperbarui status keterhubungan dan tetap mencegah ronde dimulai sampai tiga perangkat terhubung.
6. When host mengakhiri sesi bersama, the ColorGameTesting app shall memberi tahu pemain lain bahwa sesi berakhir dan mengembalikan mereka ke pilihan mode permainan.
7. When pemain memilih keluar dari sesi yang sedang menunggu sambungan kembali, the ColorGameTesting app shall mengembalikan perangkat tersebut ke pilihan mode permainan.
8. When ketiga perangkat kembali terhubung setelah pemungutan suara tertunda, the ColorGameTesting app shall memulihkan suara yang sudah diterima sebelum jeda tanpa menjalankan tindakan sebelum mayoritas tercapai.
9. While sesi dijeda karena koneksi terputus, the ColorGameTesting app shall menolak suara baru sampai seluruh perangkat kembali terhubung.

### Requirement 7: Mode satu perangkat dan batas sesi

**Tujuan:** Sebagai fasilitator playtesting, saya ingin tetap dapat memilih cara bermain yang sesuai tanpa mengubah aturan inti permainan.

#### Kriteria Penerimaan

1. When pemain memilih mode satu perangkat, the ColorGameTesting app shall menjalankan Mix, Finish/Apply, dan Redo secara langsung untuk tiga pemain pada satu perangkat tanpa pemungutan suara.
2. When pemain memilih mode tiga perangkat, the ColorGameTesting app shall memakai satu campuran dan satu skor kelompok, tanpa membuat skor terpisah untuk tiap pemain.
3. When aplikasi dibuka kembali setelah ditutup, the ColorGameTesting app shall memulai dari pilihan mode permainan tanpa memulihkan sesi tiga perangkat atau ronde sebelumnya.
4. The ColorGameTesting app shall membatasi sesi tiga perangkat pada perangkat yang menjalankan aplikasi dalam jaringan Wi-Fi lokal yang sama.

### Requirement 8: Suara final dan keputusan mayoritas

**Tujuan:** Sebagai pemain, saya ingin suara saya tercatat dan keputusan kelompok segera berlaku setelah dua pemain memilih tindakan yang sama.

#### Kriteria Penerimaan

1. When pemain memilih tindakan Mix, Finish/Apply, atau Redo yang tersedia pada perangkatnya, the ColorGameTesting app shall mencatat satu suara final untuk peran pemain tersebut dalam pemungutan suara saat ini.
2. While seorang pemain sudah memberikan suara dalam pemungutan suara saat ini, the ColorGameTesting app shall menolak suara pengganti atau suara kedua dari peran yang sama.
3. While belum ada dua suara untuk tindakan yang sama, the ColorGameTesting app shall menampilkan tindakan dan peran yang sudah memilih sebagai keputusan tertunda pada semua perangkat tanpa menjalankan tindakan.
4. When dua pemain telah memilih tindakan yang sama, the ColorGameTesting app shall menjalankan tindakan tersebut tepat satu kali tanpa menunggu suara pemain ketiga.
5. If dua suara pertama memilih tindakan berbeda, the ColorGameTesting app shall menunggu suara pemain ketiga untuk menentukan tindakan yang memperoleh dua suara.
6. While keputusan masih tertunda pada fase bermain, the ColorGameTesting app shall tetap menerima kontribusi warna yang sah dan memperbarui campuran tanpa menghapus suara yang sudah tercatat.
7. When tindakan hasil mayoritas dijalankan, the ColorGameTesting app shall menerapkan tindakan tersebut pada campuran terbaru yang sudah diterima.
8. If suatu tindakan tidak tersedia pada fase atau keadaan campuran saat ini, the ColorGameTesting app shall menolak suara untuk tindakan tersebut tanpa mengubah suara yang sudah sah.
9. When tindakan hasil mayoritas dijalankan, the ColorGameTesting app shall menghapus suara tertunda untuk pemungutan suara berikutnya.
