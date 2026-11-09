# BMW E39 Phone Key – Tam proje (Bluetooth doğrulama test sürümü)

Bu depo, **1997 BMW E39 için planlanan Phone Key projesinin masaüstü test yazılımıdır**. Kapıları açmaz; kilit veya röle çıkışı bulunmaz. iPhone uygulaması HMAC-SHA256 challenge-response ile ESP32 üzerinde kayıtlı gizli anahtarı doğrular. RSSI sinyali filtrelenir. **RSSI gerçek uzaklığın güvenli kanıtı değildir** ve Bluetooth relay saldırıları bu prototipte çözümlenmemiştir.

## Dosya yapısı

- `Sources/BMWPhoneKeyApp.swift`: iOS uygulaması başlangıcı
- `Sources/BLEManager.swift`: BLE bağlantısı ve kimlik doğrulama
- `Sources/ContentView.swift`: iPhone arayüzü
- `project.yml`: XcodeGen yapılandırması (Bluetooth izni dahil)
- `.github/workflows/build-ipa.yml`: GitHub Actions derleme iş akışı
- `ESP32/BMW_E39_Auth_Test.ino`: Arduino IDE/ESP32 kaynak kodu

## Windows'tan GitHub'a yükleme

1. ZIP'i **ayıklayın**. ZIP/RAR'ın kendisini GitHub'a yüklemeyin.
2. Deponuzun `Code` sayfasında `Add file -> Upload files` ile **bu klasörün içeriğini** yükleyin.
3. `.github/workflows/build-ipa.yml` yolunun aynen korunması önemlidir. GitHub web arayüzünde gizli `.github` klasörü yüklenmiyorsa `Add file -> Create new file` ile bu yolu girip ilgili dosya içeriğini oluşturun.
4. `Commit changes` yapın.
5. `Actions -> Build BMW Phone Key IPA -> Run workflow` çalıştırın. Başarılıysa `Artifacts` içindeki IPA arşivini indirin.
6. ZIP arşivini açıp imzasız `.ipa` dosyasını AltStore ile yüklemeyi deneyin. AltStore ile yükleme Apple imzalama ve cihaz koşullarına bağlıdır; başarı garanti edilmez. AltStore Classic ücretsiz Apple hesabında uygulamalar 7 günde bir yenilenir.

## ESP32 kurulumu

1. Arduino IDE'de `ESP32 Dev Module` kartını ve bilgisayarın COM portunu seçin.
2. `ESP32/BMW_E39_Auth_Test.ino` dosyasını açıp yükleyin.
3. Seri Monitör'ü **115200 baud** açın.
4. ESP32 ilk kullanımda 32 bayt rastgele anahtarı NVS belleğine yazar, 64 hex karakter halinde USB Seri Monitör'e basar. **Bu anahtarı GitHub'a, sohbetlere veya ekran görüntülerine asla göndermeyin.**
5. iPhone'daki uygulamaya bu 64 hex karakteri girip anahtarı kaydedin.
6. Bluetooth üzerinden otomatik bağlandığında Seri Monitör'de `[AUTH] TELEFON DOGRULANDI` yazması beklenir. Ardından filtreli RSSI çıktıları görünür.

Anahtar doğru değilse doğrulama başarısız olur. ESP32'de `Erase All Flash` yapılırsa yeni gizli anahtar oluşabilir; telefon uygulamasında da anahtarı güncellemek gerekir.

## Güvenlik uyarısı

Bu, **güvenlik denetiminden geçmemiş bir prototiptir**. BLE bağlantısı veya RSSI tek başına araç kilidini açmak için güvenli değildir. Bu paketi aracın GM III, alarm, röle, kilit motoru veya başka araç elektrik tesisatına bağlamayın. Gizli anahtar cihazın NVS belleğinde korunmasız olabilir. Uygulamayı herkese açık GitHub deposuna yükleyebilirsiniz ama kişisel gizli anahtarı hiçbir kaynak dosyasına yazmayın.
