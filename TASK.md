# Solidity Intro zadatak (Strong hands)

Kripto tokeni znaju da budu jako volatilni i ljudi u panici prodaju svoje dragocene Ethere, iako bi za njih bilo bolje da ih cuvaju na duze staze. Vas zadatak jeste da napravite smart contract koji ce da postice ljude da cuvaju svoje Ethere na duzi vremenski period. Vremenski period odredjuje deployer contracta na pocetku i posle nije promenjiv.

- Korisnici ce slati Ethere na contract koji ce ih “zakljucati” na odredjeni vremeni period
- Korisnici mogu da izvuku svoje pare pre vremenskog perioda ali ce imati odredjenu kaznu zbog toga. Ako izvuku neposredno posle ubacivanja izgubice 50% svog novca i to ce vremenom da se snizava do 0% na kraju tog vremenskog perioda
- Korisnici moraju da prilikom izvlacenja izvuku ceo iznos, nije moguce samo delimicno da izvlace “zakljucan ether”
- Korisnici mogu da depozituju novac vise puta ali im se onda resetuje taj vremenski period (odnosno sledeci put kad deposituju, krene odbrojavanje od pocetka)
- Korisnici koji izvuku pre vremena i plate kaznu (odnosno izvuku manje pare nego sto su ubacili) tu kaznu zapravo daju ostalim clanovima koji nisu izasli. Tako da svaki put kad neko izadje, ostali clanovi dobiju proporcionalno taj deo kazne. Proporcionalno u odnosu koliko imaju Ethera depositovano na contractu. Samo ucesnici koji su trenutno u sistemu dobiju te nagrade, ako neko dodje kasnije ne dobija prethodne nagrade nego samo od trenutka od kad je on u sistemu.
- Ether koji se nalazi na contractu se prilikom ubacivanja na contract pretvara u aEth. Odnosno Ether se deposituje u AaveV3 market koji ce davati pasivnu zaradu na taj Ether koji je depozitovan u contract.
- Profit koji se ostvari od depozitovanja Ethera u AaveV3 market (znaci tu pasivnu kamatu koju je zaradio). Taj novac moze vlasnik contracta da povuce sebi u bilo kom trenutku.

Zadatak treba da bude uradjen i pushovan kao repozitorijum na githubu. Nije potreban frontend za smart contract i ocekuje se da contract bude deployovan na nekoj test mrezi kao sto je Görli (bonus da taj contract bude i verifikovan). Ako vam bude bila potrebna pomoc, obratite mi se u mejlu. Na vama je potpuno arhitektura koda, ja sam rekao jedan smart contract ali to moze biti i vise, tako da slobodno organizujte resenje onako kako vi smatrate da treba. Pokusajte da hendlujete sve edge case-ve i da je kod dobro dokumentovan i da nema sigurnosnih propusta.

Contract treba da bude gas optimiziovan i da se gas cost ne podize sa brojem ucesnika u sistemu.

**Korisni linkovi:**

Solidity dokumentacija - https://docs.soliditylang.org/en/v0.8.12/

Aave V3 dokumentacija - https://docs.aave.com/developers/getting-started/readme

Görli faucet - https://goerlifaucet.com/

Lib za contract deployment i testing: https://hardhat.org/getting-started/

Online solidity IDE: https://remix.ethereum.org/

Koristan artikl - https://weka.medium.com/dividend-bearing-tokens-on-ethereum-42d01c710657

Weth (AaveV3 koristi wrappovan Ether) - https://weth.io/
