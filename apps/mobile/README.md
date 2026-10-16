# apps/mobile: aplikasi KRING (Flutter)

Satu aplikasi untuk orang-orang di sekitar lansia, dengan lima peran: **HP Mbah** (simulator telepon biasa, hanya untuk
demo; di lapangan Mbah cukup mengangkat HP), **Keluarga**, **Sahabat Kring**, **Puskesmas** (Daftar Kring Hari Ini), dan
**IGD** (Board Pre-alert). Bawaan memakai **mode luring**: logika API di-port ke `lib/core/local/`, jadi APK berjalan tanpa
server. Server FastAPI bisa dipilih lewat ⚙ atau `--dart-define=TILIK_API=http://IP:8080`.

```bash
flutter pub get
flutter build web --release      # build/web (mode luring)
flutter build apk --release      # build/app/outputs/flutter-apk/app-release.apk
flutter test
```

Sistem desain: [DESIGN.md](DESIGN.md). Cara menjalankan bersama API dan server suara: [README akar repo](../../README.md).
