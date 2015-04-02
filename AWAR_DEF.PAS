program awardeco_def;

uses
  spr2_ein;

begin
  sprachtabellenkopf(
                    +'EN'
                    +'DE'
                    +''
                    +'');

  sprach_eintrag04('hilfe',
                   'usage: AWARDECO <flash rom file> [ <traget directory> ]',
                   'Benutzung: AWARDECO <BIOS-Abbilddatei> [ <Zielverzeichnis> ]',
                   '',
                   '');

  sprach_eintrag04('datei_ist_zu_gross',
                   'The file ist to big !',
                   'Die Datei ist zu groá !',
                   '',
                   '');

  sprach_eintrag04('kopfzeile',
                   'Position packed   C     target    type               unpacked filename',
                   'Position gepackt  K.    Ziel      Typ                entpackt Dateiname',
                   '',
                   '');

  sprach_eintrag04('entpackfehler',
                   'Error during decompression !',
                   'Fehler beim Entpacken !',
                   '',
                   '');


{
  sprach_eintrag04('',
                   '',
                   '',
                   '',
                   '');}

  schreibe_sprach_datei('AWARDEC$.001','AWARDEC$.002','sprach_modul','sprach_start','^string');
end.

