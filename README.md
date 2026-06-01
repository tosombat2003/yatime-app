# 💊 Yatime (ยาไทม์) - Medication Reminder App for the Elderly
>A medication reminder mobile application designed for elderly users, built as a senior project and submitted to the 14th Asia Undergraduate Conference on Computing (AUCC2026) — rated **Good**.

<p align="center">
  <img src="https://github.com/user-attachments/assets/a0290dbe-516d-40ca-ac6c-95eeadf4e409" width="150"><br>
  <em>Yatime Application Logo</em>
</p>

## 📖 About 

**Yatime** is a smartphone medication reminder application specifically designed for the elderly. It focuses on solving the issues of missed medications and medical appointments through a simple, highly readable UX/UI design. The app features a Text-to-Speech (TTS) system and an Offline-First architecture that seamlessly integrates with hospital APIs, while also allowing users to manually add medications obtained from other sources.

---

## ✨ Features

* **🔐 Easy Login:** Fast and secure sign-in using Google accounts via Firebase Authentication.
* **📱 Offline-First Support:** Fully functional app usage and reliable notifications even without an internet connection (local data storage via SQLite).
* **☁️ Cloud Synchronization:** Automatically synchronizes data to Firebase Cloud Firestore when back online, utilizing a Last-Write-Wins (LWW) conflict resolution mechanism.
* **⏰ Smart Medication Reminder:**
  * Full-screen notifications similar to an alarm clock.
  * Text-to-Speech (TTS) system announcing medication names and dosage instructions.
  * 5-minute snooze and repeat notification features.
  * have medication stock tracking.
* **🏥 Appointment Reminder:** Three-stage medical appointment notifications (1 day prior, 3 hours prior, and an evening follow-up reminder).
* **🔗 Hospital API Integration:** Direct retrieval of prescription data and appointment schedules from healthcare facility systems.

---
## 📱 Application Screenshots

| Home Screen | Add Medication | Appointment | Reminder |
|------------|------------|------------|------------|
| <img height="500" alt="3" src="https://github.com/user-attachments/assets/43850ffb-e661-46a4-817d-6d16c2fc8e44" /> |  <img height="500" alt="Screenshot 2026-03-07 232607" src="https://github.com/user-attachments/assets/e57ff5f5-5f3e-41ed-8fc3-3c031688ed79" />| <img height="500" alt="8" src="https://github.com/user-attachments/assets/2777bffe-76a7-49c2-86e9-86f57eaa5919" /> | <img height="500" alt="ปลุก" src="https://github.com/user-attachments/assets/0265f7f2-a5ed-41e8-80aa-1aa99763b448" /> |

---

## 🛠️ Tech Stack

### Client (Mobile Application)
* **Framework:** Flutter (Dart)
* **Local Database:** SQLite

### Backend & Cloud Services
* **Database (Cloud):** Firebase Cloud Firestore
* **Authentication:** Firebase Authentication (Google)
* **Hospital API:** Go (Golang) + Gin Framework
* **API Testing:** Postman

---

## 📂 System Architecture

The application is developed using a **3-Tier Architecture**:

1. **Client Tier:** The user interface is developed with Flutter, featuring an optimized display tailored specifically for the elderly.
2. **Application Tier:** Handles the core business logic, user authentication, and Hospital API integration, built with Go.
3. **Database Tier:** Utilizes a hybrid approach combining a Local Database (SQLite) for offline capabilities and a Cloud Database (Firestore) for centralized data storage.

---

## 🚀 Getting Started
**Prerequisites**
* Flutter SDK installed
* Go installed (for running the mock API server)
*  add your `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) to the appropriate directory

### How to Run the Mobile App

1.Clone the repository
   ```bash
	git clone https://github.com/YOUR_USERNAME/yatime.git
   ```

2.Open a terminal, navigate to the mobile app directory, and install the required packages:
   ```bash 
	cd yatime-app
   	flutter pub get
   ```

3.Run the application:
   ```bash 
	flutter run
   ```	

### How to Run the Hospital API (Backend)

1.Open a new terminal and navigate to the Hospital API directory:
   ```bash  
	cd yatime-api
   ```

2.Download the required Go modules:
   ```bash  
	go mod tidy 
   ```

3.Run the server:
   ```bash  
	go run cmd/main.go 
   ```

---

## 🔮Future Improvements

- Add AI-powered medication interaction checking.
- Support caregiver accounts for family members.
- Integrate with wearable devices.
- Support multiple languages.

---

> Presented at the **14th Asia Undergraduate Conference on Computing (AUCC2026)**
> Rated: **Good** | February 2026 | Rajabhat Rambhai Barni University

