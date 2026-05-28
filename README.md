# 💊 Yatime (ยาไทม์) - Medication Reminder App for the Elderly
**Yatime** เป็นแอปพลิเคชันแจ้งเตือนการใช้ยาบนสมาร์ตโฟนที่ออกแบบมาเพื่อผู้สูงอายุโดยเฉพาะ มุ่งเน้นการแก้ปัญหาการลืมรับประทานยาและการไปพบแพทย์ไม่ตรงตามนัดหมาย ด้วยการออกแบบ UX/UI ที่เรียบง่าย อ่านง่าย พร้อมระบบเสียงอ่าน (TTS) และสถาปัตยกรรมแบบ **Offline-First** ที่ทำงานร่วมกับ API ของโรงพยาบาลได้อย่างไร้รอยต่อ

---

## ✨ ฟีเจอร์หลัก (Key Features)

* **🔐 Easy Login:** เข้าสู่ระบบอย่างรวดเร็วและปลอดภัยด้วยบัญชี Google ผ่าน Firebase Authentication
* **📱 Offline-First Support:** ใช้งานแอปและรับการแจ้งเตือนได้อย่างแม่นยำแม้ไม่มีการเชื่อมต่ออินเทอร์เน็ต (จัดเก็บข้อมูลลง SQLite)
* **☁️ Cloud Synchronization:** ซิงโครไนซ์ข้อมูลขึ้น Firebase Cloud Firestore โดยอัตโนมัติเมื่อกลับมาออนไลน์ ด้วยกลไกแก้ปัญหาความขัดแย้งแบบ LWW (Last-Write-Wins)
* **⏰ Smart Medication Reminder:**
  * แจ้งเตือนแบบเต็มหน้าจอ (Full-screen Notification) คล้ายนาฬิกาปลุก
  * ระบบอ่านออกเสียง (Text-to-Speech) บอกชื่อยาและวิธีทาน
  * ระบบเลื่อนแจ้งเตือน (Snooze 5 นาที) และแจ้งเตือนซ้ำ
* **🏥 Appointment Reminder:** ระบบแจ้งเตือนวันนัดหมายแพทย์ 3 ระยะ (ล่วงหน้า 1 วัน, ล่วงหน้า 3 ชั่วโมง, และแจ้งเตือนติดตามผลช่วงเย็น)
* **🔗 Hospital API Integration:** รองรับการดึงข้อมูลใบสั่งยาและตารางนัดหมายจากระบบของสถานพยาบาลโดยตรง

---

## 🛠️ เครื่องมือและเทคโนโลยี (Tech Stack)

### Client (Mobile Application)
* **Framework:** Flutter (Dart)
* **Local Database:** SQLite

### Backend & Cloud Services
* **Database (Cloud):** Firebase Cloud Firestore
* **Authentication:** Firebase Authentication
* **Hospital API:** Go (Golang) + Gin Framework
* **API Testing:** Postman

---

## 📂 โครงสร้างระบบ (System Architecture)

แอปพลิเคชันถูกพัฒนาด้วยสถาปัตยกรรมแบบ **3-Tier Architecture**:
1. **Client Tier:** ส่วนติดต่อผู้ใช้งาน พัฒนาด้วย Flutter รองรับการแสดงผลที่เหมาะสมกับผู้สูงอายุ
2. **Application Tier:** ระบบจัดการ Logic การทำงาน ยืนยันตัวตน และเชื่อมต่อกับ Hospital API ที่พัฒนาด้วย Go
3. **Database Tier:** ทำงานร่วมกันระหว่าง Local Database (SQLite) สำหรับการใช้งานออฟไลน์ และ Cloud Database (Firestore) สำหรับจัดเก็บข้อมูลส่วนกลาง

---

## 🚀 วิธีการติดตั้งและรันโปรเจกต์ (Getting Started)

### ข้อกำหนดเบื้องต้น (Prerequisites)
* ติดตั้ง Flutter SDK
* ติดตั้ง Go (สำหรับรันเซิร์ฟเวอร์ API จำลอง)
* *หมายเหตุ: โปรเจกต์นี้ได้แนบไฟล์ตั้งค่า `.env` และ Firebase Config (`google-services.json` / `GoogleService-Info.plist`) ไว้ให้เรียบร้อยแล้ว เพื่อความสะดวกในการรันทดสอบของคณะกรรมการ*

### วิธีรันแอปพลิเคชัน (Mobile App)
1. ทำการแตกไฟล์ Zip โปรเจกต์ และเปิดโฟลเดอร์โปรเจกต์ด้วยโปรแกรม IDE (เช่น Visual Studio Code หรือ Android Studio)
2. เปิด Terminal ในโฟลเดอร์โปรเจกต์ และติดตั้งแพ็กเกจที่จำเป็น:
```bash
cd Yatime application
flutter pub get
รันแอปพลิเคชัน:
```bash
flutter run

3. วิธีรัน Hospital API (Backend)
เข้าไปยังโฟลเดอร์ Hospital API:
```bash
cd Hospital API

4. โหลดโมดูล Go:
```bash
go mod tidy

5.รันเซิร์ฟเวอร์:
```bash
go run cmd/main.go
