# Logo ve Splash Screen Dosyaları

Bu klasöre aşağıdaki dosyaları eklemeniz gerekiyor:

## Logo (icon.png)

- **Boyut**: 1024x1024 piksel (minimum 512x512)
- **Format**: PNG (şeffaf arka plan)
- **İçerik**: Medilog uygulamasının logosu
- **Öneriler**:
  - Basit ve temiz tasarım
  - İlaç/sağlık temalı (haplar, artı işareti, kalp, vb.)
  - Mavi/yeşil ana renkler (sağlık/güven hissi)

## Splash Screen (splash.png)

- **Boyut**: 1152x1152 piksel (önerilen)
- **Format**: PNG
- **İçerik**: Uygulama açılırken gösterilecek görsel
- **Öneriler**:
  - Logo + "Medilog" yazısı
  - Minimal tasarım
  - Merkezi yerleşim

## Tasarım Önerileri

### Logo İçin:

🏥 Medikal artı işareti
💊 İlaç/kapsül şekli  
📱 Telefon + sağlık sembolü
❤️ Kalp + artı işareti
📋 Checklist + medikal sembol

### Renkler:

- Ana renk: #42a5f5 (Mavi)
- Koyu tema: #042a49 (Koyu mavi)
- Yardımcı: #4CAF50 (Yeşil)

## Logo Oluşturma Araçları:

- Canva (canva.com)
- Figma (figma.com)
- Adobe Illustrator
- Ücretsiz: GIMP, Inkscape
- Online: LogoMaker, Hatchful

## Dosya Yerleştirme:

1. `icon.png` - Uygulama ikonu
2. `splash.png` - Splash screen görüntüsü

Bu dosyaları ekledikten sonra:

```bash
flutter pub get
flutter pub run flutter_launcher_icons
flutter pub run flutter_native_splash:create
```
