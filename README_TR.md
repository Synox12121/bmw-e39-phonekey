# BMW E39 Phone Key — iPhone Test Uygulamasi

Bu prototip sadece ESP32'nin Nordic UART Service (NUS) ile iletisim kurar.
**Arac kilidine, roleye, GM III modülüne baglamayin.**
Guvenli kimlik dogrulama veya relay-attack korunmasi henuz bulunmuyor.

## Windows + GitHub Actions ile IPA olusturma

1. GitHub hesabi ac/giris yap. Yeni PUBLIC repository olustur (ornegin `bmw-e39-phonekey`). Bu prototip kodunda gizli anahtar bulunmuyor.
2. Bu ZIP'in icerigindeki `project.yml`, `Sources` klasoru ve `.github/workflows/build-ipa.yml` dosyasini repository'nin kokune yukle. GitHub web arayuzuyle dosya/folder yukleyebilirsin, gizli `.github` klasorunu atlama.
3. GitHub'da **Actions** sekmesi > **Build BMW Phone Key IPA** > **Run workflow**.
4. Is tamamlaninca calisma sayfasinin **Artifacts** bolumunden `BMW_E39_PhoneKey_Test_IPA` ZIP dosyasini indir, icindeki IPA dosyasini cikar.
5. IPA dosyasini iPhone'a AirDrop yerine iCloud Drive veya Dosyalar uygulamasi araciligiyla aktar; AltStore Classic > My Apps > + menusuyle IPA'yi sec. AltServer'in erisilebilir oldugundan emin ol.
6. Uygulamada Bluetooth izni ver. ESP32'nin onceki `BMW_E39_PHONE_KEY` BLE test kodu yuklu olmali.
7. `PING` gonderdiginde ESP32'nin `PONG` yaniti uygulamada gorunmeli.

NOT: Bu GitHub Actions yontemi macOS uzerinde **imzasiz IPA** derler. AltStore Classic cihazda kendi hesabinla yeniden imzalamayi dener; belirli iOS/hesap kosullarinda kurulum basarisiz olabilir. Burada dogrudan derleme veya iPhone'a kurulum testi yapilmamistir.

AltStore Classic ucretsiz Apple hesabi ile kurulan uygulamalar 7 gunde bir yenilenmelidir.

## Otomatik yeniden baglanma

CoreBluetooth `bluetooth-central` arka plan modunu ve state restoration kullaniyoruz. Bilinen ESP32 icin kalici bekleyen baglanti istegi olusturulur. iOS garanti vermez; uygulamayi zorla kapatmak yeniden baslatma davranisini etkileyebilir. Bu test **guvenli yaklasinca kilit acma** ozelligi degildir.
