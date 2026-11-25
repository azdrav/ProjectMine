# ProjectMine — probna Web verzija

Paket: `dist/ProjectMine-web-trial.zip` (oko 13 MB). Isti paket koristi se na
Linuxu i Windowsu. Godot nije potreban za igranje; za priloženi lokalni server
potreban je Python 3.

## Pokretanje

Linux, iz glavnog foldera projekta:

```sh
python3 tools/web/serve.py
```

Ako je server već pokrenut, samo otvoriti `http://localhost:8060/` u običnom
Chromeu/Chromiumu ili Firefoxu. Ugrađeni pregled u aplikaciji nije zamena za test
u standardnom desktop browseru.

Windows:

1. Kopirati ZIP i raspakovati ceo sadržaj u jedan folder.
2. Instalirati Python 3 ako nije dostupan (`py -3 --version`).
3. Pokrenuti `play-windows.bat` i ostaviti prozor servera otvoren.
4. Otvoriti `http://localhost:8060/` u Chromeu, Edgeu ili Firefoxu.

Ne pokretati `index.html` dvoklikom preko `file://`. Server se zaustavlja sa
Ctrl+C. Paket ništa ne otprema na javni sajt i server sluša samo lokalni računar.

## Kontrole za browser

- Po učitavanju izabrati New Game, Continue ili Load Game, zatim Enter Cockpit.
  Fullscreen je dostupan u Options.
- **Z** spušta brod, Space podiže. Ctrl ostaje dostupan, ali Ctrl+W je browser
  prečica koja može zatvoriti tab; zato u web verziji koristiti Z.
- **J** snima, **K** učitava. F5/F9 su zadržani, ali J/K izbegavaju prečice browsera.
- Esc otvara pauzu; **M** je alternativna pauza ako browser presretne Esc.
  Resume Game ponovo traži hvatanje kursora.
- Ostalo: WASD, Q/E, Shift, levi/desni klik, V, F, C, P i L kao na desktopu.

Snimak pripada browser profilu i adresi/portu. Nije zajednički sa desktop
verzijom niti drugim browserom. Dozvoliti skladištenje podataka sajta, izbegavati
privatni režim i sačekati nekoliko sekundi posle snimanja pre zatvaranja taba.

Verzija 1.3 dodaje tri ručna slota i automatski checkpoint, menije za smrt i
završetak misije i četvorominutni Escape Protocol. U lokalnom ugrađenom browseru
provereni su New Game, pauza, snimanje/učitavanje i opstanak slota/checkpointa
posle osvežavanja; Continue se pravilno aktivira. Taj Chromium prijavljuje
UnknownError pri hvatanju miša. Pun prolaz, hvatanje miša, fullscreen i zvuk
još treba ručno proveriti u običnim Linux/Windows browserima. Detalji su u
[vodiču za 1.3](game_flow_13.md).

## Ponovni izvoz

```sh
python3 tools/web/build.py
```

Potreban je Godot i odgovarajući Web export templates za istu verziju. Za prvi
izvoz korišćen je Godot **4.7.2 stable**, sa zvaničnim `web_nothreads_release.zip`
i `web_nothreads_debug.zip` predlošcima. Skripta koristi profil **Web Trial** iz
`export_presets.cfg`, pravi `build/web/index.html`, dodaje lokalne server/launcher
datoteke i pakuje `dist/ProjectMine-web-trial.zip`. Testovi, dokumentacija, Blender
izvori i alati nisu sadržaj za igranje. `build/` i `dist/` su generisani izlazi.

Web koristi Compatibility/WebGL 2, jednu nit i audio režim Stream za postojeće
Godot audio efekte. `WebTrial` autoload dodaje samo web početni ekran i prečice;
desktop preskače taj kod. Let, AI, borbena podešavanja i napredovanje misije nisu
menjani. Server isporučuje odgovarajuće MIME tipove i isključuje razvojni HTTP
keš da osvežavanje ne meša stare i nove datoteke. Za javni sajt kasnije koristiti
HTTPS; ovo još nije javno objavljivanje.

## Provera 25. novembra 2026.

- Release Web export završen bez grešaka. ZIP CRC i prisustvo svih potrebnih
  datoteka provereni; WASM/PCK/JS/HTML uspešno posluženi odgovarajućim MIME tipom.
- Chromium pregled na Linuxu učitava stvarni nivo, kokpit i 10 neprijatelja.
  Provereni su početni ekran, let tastaturom uključujući Z, pucanje i potrošnja
  municije, J/K snimanje/učitavanje i preživljavanje snimka nakon ponovnog
  otvaranja: municija se vratila na 117, štit na 70.
- Sačuvan prikaz: `docs/previews/web_trial_linux.jpg`.
- Prošlo je pet desktop headless regresionih testova: prototype, camera_feedback,
  signal_lost, missile i environment_audio.
- **Ograničenje testa:** ugrađeni Chromium prijavio je `UnknownError` pri zahtevu
  za pointer lock; DOM nije potvrdio hvatanje miša ni fullscreen. To ostaje za
  ručnu proveru u standardnom Chromeu/Firefoxu. Nije potvrđeno da je problem
  ograničen samo na ugrađeni browser.
- Zvuk/reverberaciju i kašnjenje treba oceniti slušanjem. Učitavanje audio
  worklet datoteka je potvrđeno, ali to nije subjektivna audio provera.
- Windows nije dostupan za izvršavanje u ovom okruženju: priložen je identičan
  paket i lista provera, bez tvrdnje da je tamo već testiran.
- Potpuna misija, borba sa raketama, duži FPS test i ponašanje različitih browsera
  ostaju za ručni prolaz. HUD FPS tokom kratkog pregleda nije formalni benchmark.

Za obe platforme beležiti browser/verziju, GPU, rezoluciju, FPS i eventualne
poruke iz Console (F12), uz posebno testiranje hvatanja miša, 6DoF rotacije,
sonara, raketa, generatora/vrata i učitavanja posle osvežavanja stranice.

## Direktan pristup iz lokalne mreže

Server podrazumevano sluša samo `127.0.0.1`. Opcija `--host` omogućava LAN:

```sh
python3 tools/web/serve.py --host 0.0.0.0 --no-open
```

Na ovom računaru adresa pri proveri bila je `http://10.7.7.239:8060/`; adresa se
može promeniti posle promene mreže/DHCP dodele. Proveren je HTTP 200 preko LAN IP
adrese. Ovo omogućava isporuku datoteka, ali **ne uklanja browser ograničenja**:
izvezeni `index.js` proverava secure context i odbija pokretanje preko običnog
HTTP-a na udaljenoj IP adresi. Stream audio koristi AudioWorklet, takođe vezan za
secure context. Zato direktno igranje bez SSH zahteva HTTPS i sertifikat kome
klijentski browser veruje. Server ne menja browser bezbednosna podešavanja i ne
podešava firewall/ruter. Za tunel ostaje `ssh -N -L 8080:127.0.0.1:8060
aleksandar@10.7.7.239`, pa otvaranje `http://localhost:8080/` na drugom računaru.

## HTTPS sada aktivan na portu 8060

`ERR_SSL_PROTOCOL_ERROR` je nastajao kada je HTTPS zahtev stigao na raniji HTTP
server. Server je sada prebačen na stvarni TLS, na istoj adresi:

```text
https://10.7.7.239:8060/
```

Provereni su lanac sertifikata, poklapanje IP adrese, HTTP 200 i WASM datoteka
preko HTTPS-a, bez isključivanja TLS provere (`ssl.create_default_context` sa
javnim lokalnim CA sertifikatom). Browser na klijentu još mora da prihvati tog
lokalnog izdavača; nije automatski menjano nijedno skladište poverenja.

Javni sertifikat za drugi računar je `dist/ProjectMine-local-CA.crt`. Kopirati ga
na klijentski računar. Ovo daje poverenje lokalnom izdavaču **ProjectMine LAN
Test CA** za potrebe testa; ne uvoziti privatne ključeve.

- Windows, Chrome/Edge: otvoriti `.crt` → Install Certificate → Current User →
  Place all certificates in the following store → Trusted Root Certification
  Authorities. Završiti uvoz, zatvoriti i ponovo otvoriti browser.
- Firefox: Settings → Privacy & Security → Certificates → View Certificates →
  Authorities → Import; izabrati `.crt` i poverenje za identifikovanje sajtova.
  Posle testa izdavač može da se ukloni iz istog skladišta.

SHA-256 otisak trenutnog CA sertifikata:

```text
63:51:BC:9E:AC:9B:DE:26:3A:3A:58:F7:8E:E7:5F:D3:F8:B3:ED:79:D1:5D:97:60:BF:9C:D8:5D:44:F8:A0:7A
```

Ponovno pokretanje HTTPS servera:

```sh
python3 tools/web/serve.py --https --host 0.0.0.0 --no-open
```

Kreiranje/obnavljanje sertifikata (potreban OpenSSL):

```sh
python3 tools/web/create_lan_certificate.py --ip 10.7.7.239
```

Privatni ključevi su u `~/.local/share/projectmine-web/certs/` sa dozvolama 0600,
van web foldera, ZIP paketa i repozitorijuma. Postojeći CA se ponovo koristi;
serverski sertifikat traje 90 dana i sadrži SAN za navedeni IP, 127.0.0.1 i
localhost. Ako se LAN IP promeni, obnoviti serverski sertifikat novim `--ip`.
Opcije `--cert` i `--key` podržavaju i sopstveni PEM sertifikat/par ključeva.
Podrazumevano pokretanje bez `--https` i dalje koristi HTTP za localhost.
