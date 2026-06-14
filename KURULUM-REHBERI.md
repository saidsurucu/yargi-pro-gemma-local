# Yargı Pro — Kurulum Rehberi (Adım Adım)

Bu rehber **avukatlar ve teknik olmayan kullanıcılar** içindir. Bilgisayar bilgisi gerektirmez; adımları sırayla takip etmeniz yeterlidir. Bir yerde takılırsanız en alttaki **"Takıldığınızda"** bölümüne bakabilirsiniz.

---

## Bu nedir?

Bilgisayarınıza, **kendi bilgisayarınızda çalışan** bir yapay zekâ hukuk asistanı kuruyoruz. Bu asistan Yargı Pro'nun hukuk veritabanına bağlanır; Yargıtay, Danıştay, Anayasa Mahkemesi kararlarını ve mevzuatı bulur, özetler ve sorularınızı yanıtlar.

Asistan sizin bilgisayarınızda çalıştığı için bir kez kurulduktan sonra her zaman hazırdır.

---

## Önce: Bilgisayarınız uygun mu?

**Windows kullanıyorsanız:**
- **"NVIDIA" marka ekran kartı** bulunmalıdır (çoğu oyun bilgisayarında vardır).
- En az **20 GB** boş disk alanı.

**Mac kullanıyorsanız:**
- **Apple M1 / M2 / M3 / M4** işlemcili bir Mac olmalıdır.
- En az **20 GB** boş alan.

> Emin değil misiniz? Sorun değil. Kurulum en başta otomatik kontrol eder; bilgisayarınız uygun değilse **anlaşılır bir mesajla durur** ve neyin gerektiğini söyler. Bir şeyi bozma ihtimaliniz yoktur.

---

## Kurulum — Windows

**1.** Klavyede **Windows tuşuna** basın. Açılan arama kutusuna **PowerShell** yazın ve çıkan **"Windows PowerShell"** uygulamasına tıklayın. Mavi (veya siyah) bir pencere açılır.

**2.** Aşağıdaki kutunun **sağ üst köşesindeki kopyala simgesine** tıklayın (yazının tamamı kopyalanır):

```
irm https://raw.githubusercontent.com/saidsurucu/yargi-pro-gemma-local/main/install.ps1 | iex
```

**3.** Açtığınız pencerenin içine **sağ tıklayın** (sağ tıklamak yapıştırır), ardından **Enter**'a basın.

**4.** "Bu uygulamanın cihazınızda değişiklik yapmasına izin veriyor musunuz?" penceresi çıkarsa **Evet**'e tıklayın.

**5. (En önemli adım) Bekleyin.** Ekranda bir sürü yazı akmaya başlar; bu tamamen **normaldir**, kurulum çalışıyordur. İnternetten büyük dosyalar indirildiği için bilgisayarınıza ve internet hızınıza göre **15 dakika ile 1 saat** sürebilir.
👉 Lütfen **pencereyi kapatmayın, bilgisayarı uyutmayın.**

**6.** İşlem bitince **"HER SEY HAZIR"** yazısını görürsünüz ve **masaüstünüzde "Yargı Pro"** adlı yeni bir simge belirir.

➡️ Şimdi aşağıdaki **"Programı açma ve kullanma"** bölümüne geçin.

---

## Kurulum — Mac

**1.** Sağ üstteki **büyüteç** simgesine (veya **Cmd + Boşluk**) tıklayın, **Terminal** yazın ve Enter'a basın. Bir pencere açılır.

**2.** Aşağıdaki yazıyı kopyalayın:

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/saidsurucu/yargi-pro-gemma-local/main/install.sh)"
```

**3.** Terminal penceresine **Cmd + V** ile yapıştırın ve **Enter**'a basın.

**4.** Şifre isterse Mac açılış şifrenizi yazın (yazarken ekranda **görünmez**, bu normaldir) ve Enter'a basın.

**5.** Yazılar akar — normaldir. **15 dakika ile 1 saat** sürebilir. Lütfen pencereyi kapatmayın.

**6.** İşlem bitince **Launchpad**'de (uygulamalar ekranı) **"Yargı Pro"** uygulaması çıkar.

➡️ Şimdi aşağıdaki **"Programı açma ve kullanma"** bölümüne geçin.

---

## Programı açma ve kullanma

Kurulum sonrası "Yargı Pro" küçük bir **kontrol panelidir** — asistanı başlatıp durdurmanızı sağlar.

**1.** **"Yargı Pro"** simgesine çift tıklayın (Windows'ta masaüstünde, Mac'te Launchpad'de). Ekranın köşesinde küçük bir ikon belirir (Windows'ta sağ alttaki görev çubuğunda, Mac'te sağ üstteki menü çubuğunda). İkon **kırmızı** ise asistan henüz kapalıdır.

**2.** Bu küçük ikona **tıklayın** → açılan menüden **"Başlat"**a tıklayın. Asistan hazırlanır; bu **30 saniye – 1 dakika** sürebilir. Hazır olunca ikon **yeşile** döner.

**3.** İkona tekrar tıklayın → **"opencode'u Aç"**. Yargı Pro programı açılır.

**4.** İlk kullanımda tarayıcı açılıp **Yargı Pro hesabınızla giriş** yapmanızı isteyebilir; her zamanki gibi giriş yapın.

**5.** Artık hukuki sorunuzu yazabilirsiniz. Örnek:
> *"Kira tespiti davasında güncel bir Yargıtay kararı bulup özetler misiniz?"*

**İşiniz bitince:** Köşedeki ikona tıklayıp **"Durdur"** (veya **"Çıkış"**) diyebilirsiniz.

**Sonraki günler:** Tekrar kurulum yoktur. Yalnızca "Yargı Pro"yu açıp **Başlat → opencode'u Aç** demeniz yeterlidir.

---

## Hız hakkında — önemli (yavaşlık arıza değildir)

Program, bilgisayarınızın gücüne göre **iki modelden birini otomatik seçer.** Güçlü bilgisayarlar büyük ve hızlı modeli; daha az güçlü olanlar küçük modeli alır.

- **Küçük modeli aldıysanız cevaplar daha yavaş gelir — bu tamamen normaldir, program arızalı değildir.**
- **İlk soru her zaman en yavaşıdır** — program ilk soruda "ısınır" ve cevap birkaç dakika sürebilir. **Sonraki sorular belirgin şekilde daha hızlı** gelir.
- Cevap yazılırken lütfen **bekleyin, pencereyi kapatmayın.** Ekranda yazı akmaya ya da "düşünüyor" görünmeye başladıysa program çalışıyordur.

Kısacası "çok yavaş, herhalde çalışmıyor" diye düşünmeyin — özellikle ilk soruda biraz **sabırlı olun**.

---

## Takıldığınızda

- **Bir hata görürseniz veya bir şey çalışmazsa:** **ekran görüntüsü alın** (Windows: `Win + Shift + S`, Mac: `Cmd + Shift + 4`) ve yetkiliye gönderin. Kurulum, olanları bir kayıt dosyasına yazar; gerekirse o dosyayı da isteyebiliriz.
- **Kurulumu yanlışlıkla kapattıysanız:** Aynı komutu (2. adımdaki yazıyı) tekrar çalıştırın — **kaldığı yerden devam eder**, baştan indirmez.
- **"Sürücünüzü güncelleyin" derse (Windows):** Ekran kartı sürücünüz eskidir. NVIDIA'nın güncelleme uygulamasını (GeForce Experience) açıp güncelleyin, sonra komutu tekrar çalıştırın.

---

Hepsi bu kadar. Teknik bilgiye gerek yoktur — takılırsanız **ekran görüntüsü alıp gönderin**, gerisini biz hallederiz.
