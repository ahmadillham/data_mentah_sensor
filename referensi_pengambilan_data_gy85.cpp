/**
 * ============================================================================
 *  FILE REFERENSI - TIDAK DIGUNAKAN DI MANAPUN
 *  Hanya untuk keperluan presentasi / dokumentasi
 * ============================================================================
 * 
 *  Menjelaskan proses pengambilan data mentah dari sensor GY-85
 *  melalui protokol I2C pada mikrokontroler ESP32.
 * 
 *  Modul GY-85 terdiri dari 3 chip sensor:
 *    - ADXL345  (Accelerometer)  → Mengukur kemiringan (AX, AY, AZ)
 *    - ITG3200  (Gyroscope)      → Mengukur rotasi (GX, GY, GZ)
 *    - HMC5883L (Magnetometer)   → Mengukur arah kompas (MX, MY, MZ)
 */


// ============================================================================
// PROSES 1: Mendefinisikan Alamat I2C Masing-Masing Chip
// ============================================================================
// Setiap chip memiliki "nomor rumah" (alamat) unik di jalur I2C.
// ESP32 menggunakan alamat ini untuk mengetahui chip mana yang ingin diajak
// berkomunikasi.

#define ADXL345_ADDR   0x53   // Alamat Accelerometer
#define ITG3200_ADDR   0x68   // Alamat Gyroscope
#define HMC5883L_ADDR  0x1E   // Alamat Magnetometer


// ============================================================================
// PROSES 2: Fungsi untuk Membaca Data dari Register Chip
// ============================================================================
// Fungsi ini yang secara fisik "menarik kabel" I2C.
// Parameter:
//   addr = alamat chip tujuan (contoh: 0x53 untuk ADXL345)
//   reg  = nomor register (laci) yang ingin dibaca
//   buf  = tempat menyimpan data yang diterima
//   len  = berapa byte yang diminta

static bool readRegisters(uint8_t addr, uint8_t reg, uint8_t *buf, uint8_t len) {
    Wire.beginTransmission(addr);   // Ketuk pintu chip di alamat tersebut
    Wire.write(reg);                // Bilang: "Saya mau baca laci nomor sekian"
    Wire.endTransmission(false);    // Jangan putus koneksi dulu, masih mau baca

    Wire.requestFrom(addr, len);    // Minta chip mengirimkan datanya
    for (uint8_t i = 0; i < len; i++) {
        buf[i] = Wire.read();       // Tampung setiap byte yang diterima ke buffer
    }
    return true;
}


// ============================================================================
// PROSES 3: Membaca 6 Byte Data Mentah dari Masing-Masing Chip
// ============================================================================
// Setiap chip menyimpan data pengukuran di register tertentu.
// Data selalu berisi 6 byte (3 sumbu × 2 byte per sumbu).

bool baca_semua_sensor(IMURawData &data) {
    uint8_t buf[6];  // Buffer penampung sementara (6 kotak)

    // --- Baca Accelerometer (ADXL345) ---
    // Register data dimulai dari alamat 0x32
    // Berisi: [X_low, X_high, Y_low, Y_high, Z_low, Z_high]
    readRegisters(ADXL345_ADDR, 0x32, buf, 6);

    // --- Baca Gyroscope (ITG3200) ---
    // Register data dimulai dari alamat 0x1D
    // Berisi: [X_high, X_low, Y_high, Y_low, Z_high, Z_low]
    readRegisters(ITG3200_ADDR, 0x1D, buf, 6);

    // --- Baca Magnetometer (HMC5883L) ---
    // Register data dimulai dari alamat 0x03
    // Berisi: [X_high, X_low, Z_high, Z_low, Y_high, Y_low]  ← Perhatikan: Z sebelum Y!
    readRegisters(HMC5883L_ADDR, 0x03, buf, 6);
}


// ============================================================================
// PROSES 4: Menggabungkan 2 Byte Menjadi 1 Angka Bulat (int16)
// ============================================================================
// 1 byte hanya bisa menyimpan angka 0-255.
// Sensor menghasilkan angka yang lebih besar (misalnya -257 atau +1023),
// sehingga data disimpan dalam 2 byte yang harus digabungkan.
//
// Ada 2 cara urutan penyimpanan:
//   Little-Endian: Byte kecil (low) disimpan duluan  → ADXL345
//   Big-Endian:    Byte besar (high) disimpan duluan  → ITG3200 & HMC5883L

void contoh_penggabungan_byte() {
    uint8_t buf[6];

    // --- Accelerometer (Little-Endian: byte kecil di depan) ---
    // buf[0] = byte rendah (low),  buf[1] = byte tinggi (high)
    // Cara gabung: geser byte tinggi ke kiri 8 bit, lalu gabungkan dengan byte rendah
    int16_t ax = (int16_t)(buf[1] << 8 | buf[0]);   // Contoh: buf[1]=0x01, buf[0]=0x0A → 0x010A = 266
    int16_t ay = (int16_t)(buf[3] << 8 | buf[2]);
    int16_t az = (int16_t)(buf[5] << 8 | buf[4]);

    // --- Gyroscope (Big-Endian: byte besar di depan) ---
    // buf[0] = byte tinggi (high),  buf[1] = byte rendah (low)
    int16_t gx = (int16_t)(buf[0] << 8 | buf[1]);
    int16_t gy = (int16_t)(buf[2] << 8 | buf[3]);
    int16_t gz = (int16_t)(buf[4] << 8 | buf[5]);

    // --- Magnetometer (Big-Endian, tapi urutan sumbu: X, Z, Y) ---
    int16_t mx = (int16_t)(buf[0] << 8 | buf[1]);   // Sumbu X
    int16_t mz = (int16_t)(buf[2] << 8 | buf[3]);   // Sumbu Z (bukan Y!)
    int16_t my = (int16_t)(buf[4] << 8 | buf[5]);   // Sumbu Y (terakhir)
}


// ============================================================================
// PROSES 5: Membungkus Data dan Mengirim via Bluetooth (BLE)
// ============================================================================
// Semua 9 nilai (AX, AY, AZ, GX, GY, GZ, MX, MY, MZ) dikemas ke dalam
// satu paket byte array, lalu dipancarkan lewat BLE Notify.

void contoh_kirim_via_ble() {
    uint8_t buf[20];  // Paket 20 byte

    // Salin setiap nilai (2 byte per nilai) ke dalam paket
    memcpy(&buf[0],  &data.ax, 2);   // Byte 0-1:   Accelerometer X
    memcpy(&buf[2],  &data.ay, 2);   // Byte 2-3:   Accelerometer Y
    memcpy(&buf[4],  &data.az, 2);   // Byte 4-5:   Accelerometer Z
    memcpy(&buf[6],  &data.gx, 2);   // Byte 6-7:   Gyroscope X
    memcpy(&buf[8],  &data.gy, 2);   // Byte 8-9:   Gyroscope Y
    memcpy(&buf[10], &data.gz, 2);   // Byte 10-11: Gyroscope Z
    memcpy(&buf[12], &data.mx, 2);   // Byte 12-13: Magnetometer X
    memcpy(&buf[14], &data.my, 2);   // Byte 14-15: Magnetometer Y
    memcpy(&buf[16], &data.mz, 2);   // Byte 16-17: Magnetometer Z

    // Kirim paket melalui BLE Characteristic dengan mode Notify
    // Web Dashboard akan otomatis menerima data ini
    pCharacteristic->setValue(buf, 20);
    pCharacteristic->notify();
}


// ============================================================================
// PROSES 6 (Sisi Web): Menerima dan Membongkar Paket di Browser
// ============================================================================
// Kode JavaScript di web_dashboard/app.js yang menerima paket BLE
// dan mengubahnya kembali menjadi angka-angka yang bisa ditampilkan.
//
//   function handleRawData(event) {
//       const view = event.target.value;         // Terima paket byte dari BLE
//
//       const ax = view.getInt16(0, true);       // Bongkar byte 0-1  → AX
//       const ay = view.getInt16(2, true);       // Bongkar byte 2-3  → AY
//       const az = view.getInt16(4, true);       // Bongkar byte 4-5  → AZ
//       const gx = view.getInt16(6, true);       // Bongkar byte 6-7  → GX
//       const gy = view.getInt16(8, true);       // Bongkar byte 8-9  → GY
//       const gz = view.getInt16(10, true);      // Bongkar byte 10-11 → GZ
//       const mx = view.getInt16(12, true);      // Bongkar byte 12-13 → MX
//       const my = view.getInt16(14, true);      // Bongkar byte 14-15 → MY
//       const mz = view.getInt16(16, true);      // Bongkar byte 16-17 → MZ
//
//       // Tampilkan di terminal Raw Data pada dashboard
//       appendLog(imuLog, `AX:${ax} AY:${ay} AZ:${az} | GX:${gx} ...`);
//   }
