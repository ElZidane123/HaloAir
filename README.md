# HaloAir — Aplikasi PDAM (Flutter)

Aplikasi manajemen PDAM berbasis Flutter yang melayani dua peran pengguna: **Admin** dan **Customer**. Aplikasi ini mencakup manajemen tagihan, pembayaran, layanan, pelanggan, serta notifikasi real-time.

---

## Daftar Isi

1. [Struktur Proyek](#1-struktur-proyek)
2. [Teknologi & Dependencies](#2-teknologi--dependencies)
3. [Alur Navigasi Aplikasi](#3-alur-navigasi-aplikasi)
4. [Model Data](#4-model-data)
5. [Layanan (Services)](#5-layanan-services)
6. [Fitur Admin](#6-fitur-admin)
7. [Fitur Customer](#7-fitur-customer)
8. [Sistem Notifikasi](#8-sistem-notifikasi)
9. [Alur Pembayaran & Deteksi Penolakan](#9-alur-pembayaran--deteksi-penolakan)
10. [API Endpoints](#10-api-endpoints)

---

## 1. Struktur Proyek

```
lib/
├── main.dart                     # Entry point, routing, inisialisasi
├── controllers/
│   └── userController.dart       # Placeholder (belum diimplementasikan)
├── models/
│   ├── adminService.dart         # Model layanan/tarif air
│   ├── bill.dart                 # Model tagihan & pembayaran
│   ├── customer.dart             # Model pelanggan
│   ├── customerRegister.dart     # Model data registrasi customer (persisted)
│   ├── responseDataList.dart     # Generic response wrapper (List)
│   ├── responseDataMap.dart      # Generic response wrapper (Map)
│   ├── showme.dart               # Model profil user
│   └── userRegister.dart         # Model data registrasi admin (persisted)
├── services/
│   ├── url.dart                  # Base URL API
│   ├── user.dart                 # Auth & profil (login, register, showme, update)
│   ├── dashboardService.dart     # Statistik dashboard admin
│   ├── customerDashboardService.dart  # Tagihan customer
│   ├── kelolaBill.dart           # CRUD tagihan (admin)
│   ├── kelolaCust.dart           # CRUD pelanggan (admin)
│   ├── kelolaServis.dart         # CRUD layanan (admin)
│   ├── layananCustService.dart   # Layanan customer
│   ├── paymentService.dart       # Pembayaran (upload bukti)
│   ├── invoicePdf.dart           # Generate PDF invoice
│   ├── notificationService.dart  # Notifikasi push lokal
│   ├── notificationStore.dart    # Penyimpanan riwayat notifikasi
│   ├── realtimeBillService.dart  # Polling tagihan real-time (customer)
│   └── adminPaymentPollingService.dart  # Polling pembayaran real-time (admin)
├── views/
│   ├── splashScreen.dart         # Splash screen animasi
│   ├── selectRole.dart           # Pilih peran (Customer/Admin)
│   ├── login.dart                # Halaman login
│   ├── register.dart             # Registrasi admin
│   ├── registerCustomer.dart     # Registrasi customer
│   ├── profile.dart              # Halaman profil
│   ├── showMe.dart               # Sukses registrasi
│   ├── informasiAkun.dart        # Detail & edit akun
│   ├── admins/
│   │   ├── adminDashboard.dart   # Dashboard admin
│   │   ├── kelolaBill.dart       # Kelola tagihan
│   │   ├── kelolaCust.dart       # Kelola pelanggan
│   │   ├── layananAdmin.dart     # Kelola layanan
│   │   └── notifikasiAdmin.dart  # Riwayat notifikasi admin
│   └── customers/
│       ├── homescreen.dart       # Dashboard customer
│       ├── bill.dart             # Pembayaran tagihan
│       ├── layananCust.dart      # Info layanan customer
│       └── notifikasiCustomer.dart  # Riwayat notifikasi customer
└── widgets/
    ├── bottomnavbar.dart         # Navigasi bawah (role-based)
    └── alertMassage.dart         # Overlay notifikasi animasi
```

---

## 2. Teknologi & Dependencies

| Package | Kegunaan |
|---|---|
| `google_fonts` | Font Poppins untuk tema |
| `shared_preferences` | Penyimpanan lokal (token, role, draft, riwayat notif) |
| `http` / `dio` | HTTP client untuk REST API |
| `image_picker` | Pilih bukti bayar dari galeri/kamera |
| `flutter_local_notifications` | Notifikasi push lokal (heads-up, lock screen) |
| `permission_handler` | Izin notifikasi & alarm (Android 13+) |
| `app_badge_plus` | Badge icon aplikasi |
| `pdf` | Generate PDF invoice |
| `share_plus` | Bagikan/download PDF invoice |
| `path_provider` | Direktori temporary untuk PDF |

**Base URL API:** `https://learn.smktelkom-mlg.sch.id/pdam`

---

## 3. Alur Navigasi Aplikasi

### Diagram Navigasi

```
Splashscreen (/)
  │
  ├─ Token ada (ROLE = ADMIN) ──────────► AdminDashboard
  │
  ├─ Token ada (ROLE = CUSTOMER) ───────► Bottomnavbar (Customer)
  │
  └─ Token tidak ada
       │
       ├─ Pilih "Customer"
       │    └─ register-customer
       │         └─ showme (CUSTOMER)
       │              └─ Bottomnavbar (Customer)
       │
       ├─ Pilih "Admin"
       │    └─ register
       │         └─ showme (ADMIN)
       │              └─ Bottomnavbar (Admin)
       │
       └─ "Sudah punya akun?"
            └─ login
                 └─ Bottomnavbar (role-based)
```

### Penjelasan Setiap Layar

#### 3.1 Splashscreen (`/`)
Animasi logo masuk (scale + fade) → curtain biru naik → periksa token di SharedPreferences:
- Token + role `ADMIN` → langsung ke `/admin-dashboard`
- Token + role `CUSTOMER` → langsung ke `/customer-dashboard` (Bottomnavbar)
- Tanpa token → `/select-role`

#### 3.2 SelectRole (`/select-role`)
Dua kartu pilihan peran:
- **Customer** → `/register-customer`
- **Admin** → `/register`
- Link "Sudah punya akun?" → `/login`

#### 3.3 Login (`/login`)
Form username + password → panggil `UserServices.loginUser()`:
- Simpan token, role, username ke SharedPreferences
- Sukses → navigasi ke `Bottomnavbar(role)` dengan `pushAndRemoveUntil`
- Gagal → alert error

#### 3.4 Register Admin (`/register`)
Form: nama, username, telepon, password (dengan strength indicator) → `UserServices.registerUser()` → sukses → `Showme(role: 'ADMIN')`

#### 3.5 Register Customer (`/register-customer`)
Form: nama, username, password, nomor customer, alamat, telepon → `UserServices.registerCustomer()` (dengan `service_id: 1249`) → sukses → `Showme(role: 'CUSTOMER')`

#### 3.6 ShowMe (`/showme`)
Halaman sukses registrasi dengan animasi centang hijau:
- Tampilkan info user (nama, telepon, tanggal daftar)
- Tombol "Lanjut ke Dashboard" → `Bottomnavbar(role)`

#### 3.7 Bottomnavbar (Navigasi Bawah)
Navigasi utama setelah login. Role-based:

**Admin (5 tab):**
1. **Beranda** — Dashboard admin
2. **Layanan** — Kelola tarif layanan
3. **Customer** — Kelola pelanggan
4. **Bill** — Kelola tagihan
5. **Profil** — Profil & pengaturan

**Customer (4 tab):**
1. **Dashboard** — Beranda tagihan
2. **Pembayaran** — Bayar tagihan
3. **Layanan** — Info tarif
4. **Profil** — Profil & pengaturan

Terdapat badge notifikasi pada tab Beranda yang diperbarui secara real-time.

---

## 4. Model Data

### 4.1 Bill (Tagihan)
Model inti aplikasi. Mewakili tagihan air bulanan:
- `id`, `customerId`, `adminId`, `month`, `year`
- `measurementNumber` — angka meteran
- `usageValue` — pemakaian (m³)
- `price` — harga per m³
- `serviceId` — ID layanan
- `paid` — status lunas (boolean)
- `ownerToken`
- **Computed:** `amount` (usageValue × price), `invoiceNumber`, `period`
- **Relasi:** `service` (BillService), `admin` (BillAdmin), `customer` (BillCustomer), `payments` (List\<Payment\>)

### 4.2 Payment (Pembayaran)
Menyatu dalam model Bill:
- `id`, `billId`, `paymentDate`, `verified` (bool)
- `status` — pending / verified / rejected
- `totalAmount`, `paymentProof` (filename gambar)

### 4.3 Customer
- `id`, `userId`, `customerNumber`, `name`, `phone`, `address`, `serviceId`, `ownerToken`
- Nested: mengakses `user.username` dan `service.name`

### 4.4 AdminService (Layanan/Tarif)
- `id`, `name`, `minUsage`, `maxUsage`, `price`, `ownerToken`

### 4.5 Response Wrappers
- `ResponseDataList` — `{success, message, List? data}`
- `ResponseDataMap` — `{success, message, Map? data}`

### 4.6 Model Registrasi (Draft)
- `CustomerRegister` — menyimpan data registrasi customer ke SharedPreferences sebagai cadangan
- `UserRegister` — menyimpan data registrasi admin ke SharedPreferences

---

## 5. Layanan (Services)

### 5.1 UserServices (`services/user.dart`)
- `loginUser(username, password)` — POST `/auth` → simpan token + role + username
- `registerUser(Map data)` — POST `/admins`
- `registerCustomer(Map data)` — POST `/customers`
- `showmeAdmin()` — GET `/admins/me`
- `showmeCustomer()` — GET `/customers/me`
- `updateAdmin(id, data)` — PATCH `/admins/:id`
- `updateCustomer(id, data)` — PATCH `/customers/:id`

### 5.2 DashboardService (`services/dashboardService.dart`)
Untuk admin:
- `getCustomersCount()` — GET `/customers`
- `getServicesCount()` — GET `/services`
- `getPaymentStats()` — unverifiedCount + totalRevenue dari GET `/payments`
- `getLatestUnverifiedPayments(limit)` — daftar pembayaran belum diverifikasi

### 5.3 CustomerDashboardService
- `getCustomerBills()` — GET `/bills/me` → List\<Bill\>

### 5.4 KelolaBillService (CRUD Tagihan)
- `getBills()`, `createBill(...)`, `updateBill(...)`, `deleteBill(id)` — semua via `/bills`

### 5.5 KelolaCustService (CRUD Pelanggan)
- `getCustomers()`, `createCustomer(...)`, `updateCustomer(...)`, `deleteCustomer(id)` — via `/customers`

### 5.6 KelolaServisService (CRUD Layanan)
- `getServices()`, `getServiceById(id)`, `createService(...)`, `updateService(...)` — via `/services`

### 5.7 PaymentService (Pembayaran)
- `createPayment(billId, imageFile, paymentDate, paymentAmount)` — POST `/payments` (multipart)
- `getMyPayments()` — GET `/bills/me`
- `getPaymentProofUrl(fileName)` — konstruksi URL bukti bayar

### 5.8 InvoicePdfService
Generate PDF invoice dari model Bill:
- Header (logo + "INVOICE")
- Info customer & status payment
- Tabel pemakaian & total
- Footer (tenggat, tanda tangan admin)
- Simpan ke temp → share via `share_plus`

### 5.9 RealtimeBillService (Customer)
Polling `/bills/me` setiap 5 detik:
- Deteksi tagihan baru (berdasarkan ID)
- Deteksi tagihan berubah (status paid/verifiedPayment)
- Callback: `onNewBill`, `onBillUpdate`

### 5.10 AdminPaymentPollingService (Admin)
Singleton, polling `/payments` setiap 10 detik:
- Deteksi kenaikan jumlah unverified payments
- Lacak ID yang sudah dinotifikasi (persisted) untuk hindari duplikasi
- Trigger: notifikasi sistem + store + floating UI

### 5.11 NotificationService
Singleton untuk notifikasi push lokal:
- `initialize()` — setup FlutterLocalNotificationsPlugin (Android channel max importance, heads-up, lock screen)
- `requestPermission()` — izin notifikasi + alarm + battery
- `showPaymentNotification()` — notifikasi masuk dengan group summary
- `showDetailedPaymentNotification()` — notifikasi detail customer + amount
- `updateAppBadge(count)` — badge icon aplikasi

### 5.12 NotificationStore
Singleton + ChangeNotifier, riwayat notifikasi:
- Persisted di SharedPreferences (JSON, max 100 item)
- `add()`, `markAllRead()`, `markAsRead()`, `removeAt()`, `clearAll()`
- `NotificationItem`: title, body, time, timestamp, isRead

---

## 6. Fitur Admin

### 6.1 Dashboard Admin (`admins/adminDashboard.dart`)
- **Header:** Logo + "ADMIN Panel" badge + ikon bell dengan badge animasi
- **Banner Biru:** Sapaan + username admin
- **Kartu Statistik (4):** Total Customer, Services, Unverified Payments (pulse animation), Total Revenue
- **Pembayaran Terbaru:** Daftar kartu pembayaran yang belum diverifikasi
- **Real-time:** Polling tiap 10s → notifikasi floating (slide-down, auto-dismiss 5s) + update badge + simpan ke NotificationStore

### 6.2 Kelola Tagihan (`admins/kelolaBill.dart`)
- **2 Tab:** Unverified Bills / All Bills
- **Search:** Filter real-time
- **Filter Sheet:** Range tanggal + status (verified/unverified/pending/rejected)
- **Kartu Tagihan:** No. invoice, periode, amount, status badge, nama customer
- **Download PDF** via InvoicePdfService + share
- **Pull-to-refresh**

### 6.3 Kelola Pelanggan (`admins/kelolaCust.dart`)
- Daftar customer dengan search + sort (nama A-Z/Z-A, no. customer)
- **Bottom sheet CRUD:** Add/edit customer (username, password, nama, telepon, alamat, dropdown layanan)
- Hapus dengan konfirmasi
- Pull-to-refresh

### 6.4 Kelola Layanan (`admins/layananAdmin.dart`)
- Daftar layanan dengan search + sort (nama, harga tinggi/rendah)
- Warna/ikon deterministik berdasarkan ID (25 icon × 20 palet warna)
- **Bottom sheet CRUD:** Add/edit layanan (nama, min/max usage, harga)
- Hapus dengan konfirmasi

### 6.5 Notifikasi Admin (`admins/notifikasiAdmin.dart`)
- Riwayat notifikasi dari NotificationStore
- Swipe-to-dismiss, long-press delete, "Hapus Semua"
- Indikator unread (titik biru)
- Tandai semua read saat masuk halaman

---

## 7. Fitur Customer

### 7.1 Dashboard Customer (`customers/homescreen.dart`)
- Sapaan dengan username
- **Ringkasan tagihan aktif:** total tagihan belum dibayar + jumlah
- **Daftar kartu tagihan** per bulan dengan status badge
- **Polling real-time (5s):**
  - Tagihan baru → animasi shake + notifikasi floating + dialog
  - Pembayaran terverifikasi → notifikasi floating
- Ikon bell → navigasi ke notifikasi
- Dapat memicu `SwitchTabNotification` untuk pindah ke tab Pembayaran

### 7.2 Pembayaran Tagihan (`customers/bill.dart`)
- **2 Tab:** "Belum Dibayar" / "Riwayat"
- **Tab Belum Dibayar:** Kartu tagihan (no. invoice, periode, amount, status)
- **Upload bukti bayar:** image_picker → multipart POST `/payments`
- **Deteksi Penolakan:** Bandingkan ID tagihan yang sudah diupload dengan response API → jika hilang, tandai ditolak → notifikasi
- Auto-refresh timer (5s)
- Footer total tagihan belum dibayar
- Download PDF + share

### 7.3 Info Layanan (`customers/layananCust.dart`)
- Fetch service ID dari `/customers/me`
- Cocokkan dengan semua service dari `/services`
- Tampilkan: ikon, nama layanan, min/max usage, harga per unit
- Auto-refresh saat app resume

### 7.4 Notifikasi Customer (`customers/notifikasiCustomer.dart`)
- Sama pola dengan notifikasi admin
- Ikon + warna berdasarkan judul notifikasi (bill = amber, verified = hijau, payment = biru)
- Empty state dengan teks deskriptif

---

## 8. Sistem Notifikasi

### Arsitektur
```
AdminPaymentPollingService (polling 10s)
       │
       ├─► NotificationService (push lokal)
       │       └─► show heads-up notification + group summary
       │
       ├─► NotificationStore (ChangeNotifier)
       │       ├─► SharedPreferences (persist)
       │       └─► UI badge updates via Listeners
       │
       └─► Floating UI overlay (slide-down, auto-dismiss 5s)

RealtimeBillService (polling 5s, customer)
       │
       ├─► NotificationService
       ├─► NotificationStore
       └─► Floating UI + dialog (tagihan baru)
```

### Alur Notifikasi Pembayaran Baru (Admin)
1. `AdminPaymentPollingService` polling `/payments` tiap 10 detik
2. Deteksi jumlah unverified payments meningkat
3. Jika ada payment ID baru (belum pernah dinotifikasi):
   a. Simpan ID ke SharedPreferences
   b. Trigger `onNewPayment` callback
   c. Dashboard menampilkan floating notification
   d. `NotificationService` menampilkan heads-up notification sistem
   e. `NotificationStore.add()` menyimpan ke riwayat
   f. Badge icon aplikasi diperbarui

### Alur Notifikasi Tagihan Baru (Customer)
1. `RealtimeBillService` polling `/bills/me` tiap 5 detik
2. Bandingkan daftar ID tagihan dengan snapshot sebelumnya
3. Tagihan baru → notifikasi floating + shake animation + dialog konfirmasi
4. Status berubah (verified) → notifikasi floating

---

## 9. Alur Pembayaran & Deteksi Penolakan

### Alur Pembayaran Normal

```
Customer                          Server                        Admin
   │                                │                             │
   │   Upload bukti bayar           │                             │
   │   (image + amount)             │                             │
   │──────────────────────────────► │                             │
   │   POST /payments (multipart)   │                             │
   │                                │                             │
   │                                │   Polling setiap 10s        │
   │                                │◄────────────────────────────│
   │                                │   GET /payments             │
   │                                │                             │
   │                                │  [Notifikasi pembayaran baru]
   │                                │────────────────────────────►│
   │                                │                             │
   │                                │          Verifikasi         │
   │                                │◄────────────────────────────│
   │                                │                             │
   │   Polling setiap 5s            │                             │
   │◄──────────────────────────────│                             │
   │   GET /bills/me → paid=true    │                             │
   │                                │                             │
   │ [Notifikasi terverifikasi]     │                             │
```

### Deteksi Penolakan Pembayaran (Client-Side)

1. Customer upload bukti bayar untuk bill ID tertentu
2. ID bill disimpan ke SharedPreferences (`uploadedBillIds`)
3. Setiap refresh, `BillService.getMyPayments()` dipanggil
4. Untuk setiap bill ID yang ada di `uploadedBillIds`:
   - Cek apakah bill tersebut masih memiliki payment di response API
   - Jika **tidak memiliki payment** → dianggap **ditolak**
   - Hapus ID dari `uploadedBillIds`
   - Simpan ke `rejectedBillIds`
   - Tambahkan notifikasi ke NotificationStore
   - Kartu tagihan kembali ke daftar "Belum Dibayar"
5. Pada halaman notifikasi, penolakan ditampilkan dengan ikon/ warna khusus

### PDF Invoice
- Admin dapat mendownload PDF invoice dari halaman kelola tagihan
- Customer dapat mendownload PDF invoice dari halaman pembayaran
- Format: Header logo PDAM + "INVOICE" → Info customer & status → Tabel pemakaian (+ total) → Footer

---

## 10. API Endpoints

| Endpoint | Method | Service | Deskripsi |
|---|---|---|---|
| `/auth` | POST | `UserServices` | Login (return token + role) |
| `/admins` | POST | `UserServices` | Register admin |
| `/admins/:id` | PATCH | `UserServices` | Update admin |
| `/admins/me` | GET | `UserServices` | Profil admin |
| `/customers` | GET | `DashboardService`, `KelolaCustService` | List semua customer |
| `/customers` | POST | `KelolaCustService` | Create customer |
| `/customers/:id` | PATCH | `KelolaCustService`, `UserServices` | Update customer |
| `/customers/:id` | DELETE | `KelolaCustService` | Delete customer |
| `/customers/me` | GET | `UserServices`, `LayananCustService` | Profil customer + service ID |
| `/bills` | GET | `KelolaBillService` | List semua tagihan (admin) |
| `/bills` | POST | `KelolaBillService` | Create tagihan |
| `/bills/:id` | PUT | `KelolaBillService` | Update tagihan |
| `/bills/:id` | DELETE | `KelolaBillService` | Delete tagihan |
| `/bills/me` | GET | `CustomerDashboardService`, `PaymentService` | Tagihan customer saat ini |
| `/services` | GET | `DashboardService`, `KelolaServisService` | List semua layanan |
| `/services` | POST | `KelolaServisService` | Create layanan |
| `/services/:id` | GET | `KelolaServisService` | Detail layanan |
| `/services/:id` | PATCH | `KelolaServisService` | Update layanan |
| `/payments` | POST | `PaymentService` | Upload pembayaran (multipart) |
| `/payments` | GET | `DashboardService` | List semua pembayaran |

**Autentikasi:** Semua request (kecuali login/register) menyertakan header `APP-KEY` dan `Authorization: Bearer <token>`.
Token, role, dan username disimpan di SharedPreferences. Jika response 401, token dihapus dan user diarahkan ke login.

---

## Arsitektur & Pola Kunci

1. **Singleton Services** — `NotificationService`, `NotificationStore`, `AdminPaymentPollingService` menggunakan factory constructor dengan named constructor `_internal`
2. **Polling over WebSocket** — Update real-time menggunakan HTTP polling (5s customer, 10s admin) sebagai pengganti WebSocket
3. **SharedPreferences sebagai local DB** — Token, role, username, draft registrasi, ID bill terupload, ID bill ditolak, riwayat notifikasi
4. **Role-based UI** — `Bottomnavbar` tunggal menampilkan tab berbeda berdasarkan role dari SharedPreferences
5. **Overlay Alerts** — `Alertmassage` menggunakan `OverlayEntry` untuk notifikasi sukses/error non-blocking
6. **Payment Rejection Detection** — Mekanisme client-side untuk mendeteksi pembayaran ditolak tanpa endpoint khusus
