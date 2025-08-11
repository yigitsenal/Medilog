#!/bin/bash

# Logo ve Splash Screen Oluşturma Komutları
# Bu dosyayı çalıştırmadan önce icon.png ve splash.png dosyalarını assets/images/ klasörüne koyun

echo "🎨 Logo ve Splash Screen oluşturuluyor..."

# Önce paketleri güncelleyelim
echo "📦 Paketler güncelleniyor..."
flutter pub get

# Launcher iconları oluştur
echo "🚀 Uygulama ikonları oluşturuluyor..."
flutter pub run flutter_launcher_icons

# Splash screen oluştur  
echo "💫 Splash screen oluşturuluyor..."
flutter pub run flutter_native_splash:create

echo "✅ Logo ve splash screen başarıyla oluşturuldu!"
echo "🔄 Uygulamayı yeniden derleyin: flutter run"
