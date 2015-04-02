(*$I+*)
program award_bios_entpacker;

(* 2000.10.07 Veit Kannegieser *)
(* 2002.06.30 6A69MV39.BIN: -lh0- *)
(* 2003.12.21 extract plain Intel P6+ microcode blocks (6A69MV39.a) *)

uses
  awar_spr,
  Dos,
  mkdir2,
  lzh5x,
  Objects,
  Strings,
  VpUtils;

const
  datum                 ='2000.10.07..2003.12.21';

type
  anfang                =
    packed record
      case integer of
        0:(b0           :byte;);
        1:(ibm_kennung  :smallword;
           bloecke512   :byte;);
        2:(kopflaenge   :byte;
           pruefsumme   :byte;
           kompression  :array[2..6] of char;
           eingepackt   :longint;
           ausgepackt   :longint;
           ziel_o       :smallword;
           ziel_s       :smallword;
           attr         :byte;
           u14          :byte;
           dname        :string;);
        3:(acfg_laenge  :smallword;
           acfg_kennung :array[2..5] of char;);
        4:(update_header_version_number,
           revision_number_of_this_microcode_update,
           update_creation_date,
           family_model_stepping_of_processor_to_which_update_applied,
           checksum,
           revision_number_of_loader_needed_to_install_update,
           product:longint;
           reserved_for_future_expansion:array[$1c..$2f] of byte;
           encrypted_microcode_data:array[$30..$30+2000-1] of byte;);
    end;

var
  d1                    :file;
  rom                   :array[0..1024*1024-1] of byte;
  dateilaenge,
  logischer_anfang,
  arbeit                :longint;
  dateiname             :string;
  zielverzeichnis       :string;
  laenge                :longint;
  z                     :longint;
  ziel                  :pointer;

procedure speichere(var e;const l:longint);
  var
    d2                  :file;
  begin
    Write(Int2Hex(l,8),' ',dateiname,' ');
    Assign(d2,zielverzeichnis+dateiname);
    FileMode:=$41;
    Rewrite(d2,1);
    Blockwrite(d2,e,l);
    Close(d2);
    WriteLn;
  end;

function modul_typ(const s:word):string;
  var
    award_ziel_segment_name:string;
  begin
    case s of
      $0800:award_ziel_segment_name:=' NCR ROM';
      $1000:award_ziel_segment_name:=' AHA/BusLogic ROM';
      $4000:award_ziel_segment_name:=' LOGO BitMap';
      $4001:award_ziel_segment_name:=' CPU micro code';
      $4002:award_ziel_segment_name:=' EPA pattern';
      $4003:award_ziel_segment_name:=' ACPI table';
      $4004:award_ziel_segment_name:=' VSA driver';
      $4005:award_ziel_segment_name:=' HPM ROM';
      $4006:award_ziel_segment_name:=' HPC ROM';
      $4007:award_ziel_segment_name:=' Virus ROM'; (* ? ChipAvayVirus';  GDLS1011 *)
      $4008..$400d:
            award_ziel_segment_name:=' FNT'+Chr(Ord('0')+s-$4008)+' ROM';
      $400e:award_ziel_segment_name:=' YGROUP ROM';
      $400f:award_ziel_segment_name:=' MIB ROM';
      $4010:award_ziel_segment_name:=' EPA1 ROM';
      $4011:award_ziel_segment_name:=' LOGO1 ROM';

      $4012..$4019:
            award_ziel_segment_name:=' OEM'+Chr(Ord('0')+s-$4012)+' CODE';
      $401a..$401f:
            award_ziel_segment_name:=' EPA'+Chr(Ord('0')+s-$401a+2)+' ROM';
      $4020..$4025:
            award_ziel_segment_name:=' LOGO'+Chr(Ord('0')+s-$4020+2)+' ROM';
      $4026:award_ziel_segment_name:=' Flash ROM';
      $407f:award_ziel_segment_name:=' XGROUP CODE';
      $4080..$4085:
            award_ziel_segment_name:=' VGA ROM '+Chr(Ord('0')+s-$4080+1);
      $4086..$409f:
            award_ziel_segment_name:=' PCI driver '+Chr(Ord('A')+s-$4086);
   (* $4086:award_ziel_segment_name:=' ? ncr 307';         SDA14A.BIN *)
      $40a0..$40a3:
            award_ziel_segment_name:=' PCI driver '+Chr(Ord('A')+s-$40a0);
      $40a4..$40a6:
            award_ziel_segment_name:=' PCI driver '+Chr(Ord('1')+s-$40a4);
      $4100:award_ziel_segment_name:=' EXT System BIOS';
      $5000:award_ziel_segment_name:=' System BIOS';
      $7000:award_ziel_segment_name:=' VGA ROM';
    else
            award_ziel_segment_name:='';
    end;

    while Length(award_ziel_segment_name)<16+1 do award_ziel_segment_name:=award_ziel_segment_name+' ';

    modul_typ:=award_ziel_segment_name;
  end;

function checksum_ok(p:pLongArray):boolean;
  var
    s:longint;
    i:word;
  begin
    s:=0;
    for i:=0 to (2048 div 4)-1 do
      Inc(s,p^[i]);
    checksum_ok:=(s=0);
  end;

function Int2HexM(const l:longint;n:Byte):string;
  begin
    while (n<8) and ((l shr (4*n))<>0) do Inc(n);
    Int2HexM:=Int2Hex(l,n);
  end;


begin
  WriteLn(^m'AWARDECO * V.K. * ',datum);

  if not (ParamCount in [1,2]) then
    begin
      WriteLn(textz_hilfe^);
      Halt(1);
    end;

  dateiname:=ParamStr(1);
  //dateiname:='I:\daten.awa\2avw0414.bin';
  //dateiname:='I:\daten.awa\8000.lzh';
  //dateiname:='I:\daten.awa\p2ns0528.bin';
  //dateiname:='I:\daten.awa\r02a0.bin';
  //dateiname:='I:\daten.awa\sa-05-24.bin';
  //dateiname:='I:\daten.awa\109cd12.awd';
  //dateiname:='I:\daten.awa\klaue.awd';
  //dateiname:='M:\6A69MV39.a';
  Assign(d1,dateiname);
  FileMode:=$40;
  Reset(d1,1);

  dateilaenge:=FileSize(d1);
  logischer_anfang:=SizeOf(rom)-dateilaenge;

  if logischer_anfang<0 then
    begin
      WriteLn(textz_datei_ist_zu_gross^);
      Halt(1);
    end;

  BlockRead(d1,rom[logischer_anfang],dateilaenge);
  Close(d1);

  arbeit:=logischer_anfang;


  if ParamCount>=2 then
    begin
      zielverzeichnis:=FExpand(Paramstr(2));
      if not (zielverzeichnis[Length(zielverzeichnis)] in ['\','/']) then
        zielverzeichnis:=zielverzeichnis+'\';
      mkdir_verschachtelt(zielverzeichnis);
    end
  else
    zielverzeichnis:='';


  WriteLn(textz_kopfzeile^);
  WriteLn('-------- -------- ----- --------- --------------- -- -------- ------------');
  repeat

    with anfang(rom[arbeit]) do

      (*************************************************************)
      if StrLComp(@kompression,'-lh0-',Length('-lh0-'))=0 then
        begin
          Write(Int2Hex(arbeit,8),' ',Int2Hex(eingepackt,8),' -lh0- ',
                Int2Hex(ziel_s,4),':',Int2Hex(ziel_o,4),modul_typ(ziel_s));

          dateiname:=dname;
          while Pos(#0,dateiname)>0 do
            Dec(dateiname[0]);
          while Pos('\',dateiname)>0 do
            Delete(dateiname,1,1);
          while Pos('/',dateiname)>0 do
            Delete(dateiname,1,1);
          for z:=1 to Length(dateiname) do
            if not (dateiname[z] in ['0'..'9','A'..'Z','a'..'z']) then
              if (z<>Length(dateiname)-3) or (dateiname[z]<>'.') then
                dateiname[z]:='_';
          Write('-> ');
          Inc(arbeit,2+kopflaenge);
          speichere(rom[arbeit],ausgepackt);
          Inc(arbeit,eingepackt);
        end (* -lh0- *)
      else if StrLComp(@kompression,'-lh5-',Length('-lh5-'))=0 then
        begin
          Write(Int2Hex(arbeit,8),' ',Int2Hex(eingepackt,8),' -lh5- ',
                Int2Hex(ziel_s,4),':',Int2Hex(ziel_o,4),modul_typ(ziel_s));

          dateiname:=dname;
          while Pos(#0,dateiname)>0 do
            Dec(dateiname[0]);
          while Pos('\',dateiname)>0 do
            Delete(dateiname,1,1);
          while Pos('/',dateiname)>0 do
            Delete(dateiname,1,1);
          for z:=1 to Length(dateiname) do
            if not (dateiname[z] in ['0'..'9','A'..'Z','a'..'z']) then
              if (z<>Length(dateiname)-3) or (dateiname[z]<>'.') then
                dateiname[z]:='_';
          GetMem(ziel,ausgepackt);
          FillChar(ziel^,ausgepackt,$cc);

          if entpacke_lzh5(rom[arbeit+2+kopflaenge],ziel^,ausgepackt,eingepackt+4) then
            begin
              Write('-> ');
              speichere(ziel^,ausgepackt);
            end
          else
            WriteLn(textz_entpackfehler^);

          FreeMem(ziel);
          Inc(arbeit,2+kopflaenge+eingepackt);
        end (* -lh5- *)
      (*************************************************************)
      else if (b0 in [0,$ff])
           or (StrLComp(@kompression[3],'-lh0-',Length('-lh0-'))=0)
           or (StrLComp(@kompression[3],'-lh5-',Length('-lh5-'))=0)
       then
        begin
          Inc(arbeit);
        end
      (*************************************************************)
      else if (ibm_kennung=$aa55) and (bloecke512<=$80) and ((arbeit and $f)=0) then
        begin
          laenge:=bloecke512*512;
          Write(Int2Hex(arbeit,8),' ',Int2Hex(laenge,8),' 55 AA ',
                Int2Hex(arbeit shr 4,4),':0000',' ':17);
          dateiname:=Int2Hex(arbeit,8)+'.dec';
          dateiname[1]:='r';
          Write('=> ');
          speichere(rom[arbeit],laenge);
          Inc(arbeit,laenge);
        end
      (*************************************************************)
      else if ((arbeit and $1fff)=0)
           and (StrLComp(@b0,'= Award Decompression',Length('= Award Decompression'))=0) then
        begin
          laenge:=$1000;
          Write(Int2Hex(arbeit,8),' ',Int2Hex(laenge,8),' Deco  ',
                Int2Hex(arbeit shr 4,4),':0000',' ':17);
          dateiname:=Int2Hex(arbeit,8)+'.dec';
          dateiname[1]:='r';
          Write('=> ');
          speichere(rom[arbeit],laenge);
          Inc(arbeit,laenge);
        end
      (*************************************************************)
      else if  ((arbeit and $1fff)=0)
           and (StrLComp(@b0,'Award BootBlock',Length('Award BootBlock'))=0) then
        begin
          laenge:=SizeOf(rom)-arbeit;
          Write(Int2Hex(arbeit,8),' ',Int2Hex(laenge,8),' Boot  ',
                Int2Hex(arbeit shr 4,4),':0000',' ':17);
          dateiname:=Int2Hex(arbeit,8)+'.dec';
          dateiname[1]:='r';
          Write('=> ');
          speichere(rom[arbeit],laenge);
          Inc(arbeit,laenge);
        end
      (*************************************************************)
      else if StrLComp(@acfg_kennung,'ACFG',Length('ACFG'))=0 then
        begin
          laenge:=acfg_laenge;
          Write(Int2Hex(arbeit,8),' ',Int2Hex(laenge,8),' ACFG  ',
                Int2Hex(arbeit shr 4,4),':0000',' ':17);
          dateiname:=Int2Hex(arbeit,8)+'.dec';
          dateiname[1]:='r';
          Write('=> ');
          speichere(rom[arbeit],laenge);
          Inc(arbeit,laenge);
        end
      (*************************************************************)
      else if  (update_header_version_number=1)
           and (revision_number_of_loader_needed_to_install_update=1)
           and checksum_ok(@rom[arbeit]) then
        begin
          laenge:=2048;
          Write(Int2Hex(arbeit,8),' ',Int2Hex(laenge,8),' CPU   ',
                Int2Hex(arbeit shr 4,4),':0000',' ':17);
          dateiname:=Int2HexM(family_model_stepping_of_processor_to_which_update_applied,3)+'_'
                    +Int2HexM(revision_number_of_this_microcode_update,2)
                    +Int2HexM(product,2)+'.cpu';
          Write('=> ');
          speichere(rom[arbeit],laenge);
          Inc(arbeit,laenge);
        end
      (*************************************************************)
      else
        begin
          arbeit:=(arbeit and -$1000)+$1000;
        end;

  until arbeit>=High(rom);

end.

