// *****************************************************************************
// The retromachine unit for Raspberry Pi/Ultibo
// Ultibo v. 0.30 - 2018.04.23
// Piotr Kardasz
// pik33@o2.pl
// www.eksperymenty.edu.pl
// GPL 2.0 or higher
// uses combinedwaveforms.bin by Johannes Ahlebrand - MIT licensed
//******************************************************************************
//
// --- ALPHA, don't complain !!!
//
// Retromachine memory map @bytes FOR ULTIBO
//
// 0000_0000  -  heap_start (about 0190_0000) - Ultibo area
// Heap start -  2EFF_FFFF retromachine program area, about 720 MB
//
// BASE=$2FF0_0000 - this can change or become dynamic
//
// 2FF0_0000  -  2FF0_FFFF - 6502 area
//    2FF0_D400  -  2FF0_D418 SID
//    2FF0_D420  -  POKEY --- TODO
//
// 2FF1_0000  -  2FF5_FFFF - system data area
//    2FF1_0000  -  2FF4_FFFF pallette banks; 65536 entries
//    2FF5_0000  -  2FF5_1FFF font definition; 256 char @8x16 px
//    2FF5_2000  -  2FF5_9FFF static sprite defs 8x4k
//    2FF5_A000  -  2FF5_FFFF reserved for future OS/BASIC
//
// 2FF6_0000  -  2FF6_FFFF --- copper
//    2FF6_0000 - frame counter
//    2FF6_0004 - display start
//    2FF6_0008 - current graphics mode   ----TODO
//      2FF6_0009 - bytes per pixel
//    2FF6_000C - border color
//    2FF6_0010 - pallette bank           ----TODO
//    2FF6_0014 - horizontal pallette selector: bit 31 on, 30..20 add to $60010, 11:0 pixel num. ----TODO
//    2FF6_0018 - display list start addr  ----TODO
//                DL entry: 00xx_YYLLL_MM - display LLL lines in mode MM
//                            xx: 00 - do nothing
//                                01 - raster interrupt
//                                10 - set pallette bank YY
//                                11 - set horizontal scroll at YY
//                          10xx_AAAAAAA - set display address to xxAAAAAAA
//                          11xx_AAAAAAA - goto address xxAAAAAAA
//    2FF6_001C - horizontal scroll right register ----TODO
//    2FF6_0020 - x res
//    2FF6_0024 - y res
//    2FF6_0028 - KBD. 28 - ASCII 29 modifiers, 2A raw code 2B key released
//    2FF6_002C - mouse. 6002c,d x 6002e,f y
//    2FF6_0030 - mouse keys, 2FF6_0032 - mouse wheel; 127 up 129 down
//    2FF6_0034 - current dl position ----TODO
//    2FF6_0040 - 2FF6_007C sprite control long 0 31..16 y pos  15..0 x pos
//                                         long 1 30..16 y zoom 15..0 x zoom
//    2FF6_0080 - 2FF6_009C dynamic sprite data pointer
//    2FF6_00A0 - text cursor position
//    2FF6_00A4 - text color
//    2FF6_00A8 - background color
//    2FF6_00AC - text size and pitch
//    2FF6_00B0 - double buffer screen #1 address
//    2FF6_00B4 - double buffer screen #2 address
//    2FF6_00B8 - native x resolution
//    2FF6_00BC - native y resolution
//    2FF6_00C0 - initial DL area


//
//    2FF6_0100 - 2FF6_01FF - blitter
//    2FF6_0200 - 2FF6_02FF - paula
//    2FF6_0300 - 2FF6_0?FF - FM synth


//    2FF6_0F00 - system data area
//    2FF6_0F00 - CPU clock
//    2FF6_0F04 - CPU temperature
//    2FF6_0FF8 - kbd report

//    2FF7_0000  -  2FFF_FFFF - retromachine system area
//    3000_0000  -  30FF_FFFF - virtual framebuffer area
//    3100_0000  -  3AFF_FFFF - Ultibo system memory area
//    3B00_0000  -  3EFF_FFFF - GPU memory
//    3F00_0000  -  3FFF_FFFF - RPi real hardware registers


// TODO planned retromachine graphic modes:
// 00..15 Propeller retromachine compatible - TODO
// 16 - 1792x1120 @ 8bpp
// 17 - 896x560 @ 16 bpp
// 18 - 448x280 @ 32 bpp
// 19 - native borderless @ 8 bpp /xres, yres defined @ 60020,60024
// 20..23 - 16 bpp modes
// 24..27 - 32 bpp modes
// 28 ..31 text modes - ?
// bit 7 set = double buffered


// DL modes

//xxxxDDMM
// xxxx = 0001 for RPi Retromachine
// MM: 00: hi, 01 med 10 low 11 native borderless
// DD: 00 8bpp 01 16 bpp 10 32 bpp 11 border


// ----------------------------   This is still alpha quality code


unit retromalina;

{$mode objfpc}{$H+}

interface

uses sysutils,classes,Platform,Framebuffer,retrokeyboard,retromouse,
     threads,GlobalConst,globalconfig,ultibo,HeapManager,retro;

const base=          $80000000;     // retromachine system area base
      nocache=       $C0000000;     // cache off address addition
      mainscreen=    $a0000000;

const _pallette=        $10000;
      _systemfont=      $50000;
      _sprite0def=      $52000;
      _sprite1def=      $53000;
      _sprite2def=      $54000;
      _sprite3def=      $55000;
      _sprite4def=      $56000;
      _sprite5def=      $57000;
      _sprite6def=      $58000;
      _sprite7def=      $59000;
      _framecnt=        $60000;
      _displaystart=    $60004;
      _graphicmode=     $60008;
      _bpp=             $60009;
      _bordercolor=     $6000C;
      _pallettebank=    $60010;
      _palletteselector=$60014;
      _dlstart=         $60018;
      _hscroll=         $6001C;
      _xres=            $60020;
      _yres=            $60024;
      _keybd=           $60028;
      _mousexy=         $6002C;
      _mousekey=        $60030;
      _dlpos=           $60034;
      _reserved01=      $60038;
      _reserved02=      $6003C;
      _spritebase=      $60040;
      _sprite0xy=       $60040;
      _sprite0zoom=     $60044;
      _sprite1xy=       $60048;
      _sprite1zoom=     $6004C;
      _sprite2xy=       $60050;
      _sprite2zoom=     $60054;
      _sprite3xy=       $60058;
      _sprite3zoom=     $6005C;
      _sprite4xy=       $60060;
      _sprite4zoom=     $60064;
      _sprite5xy=       $60068;
      _sprite5zoom=     $6006C;
      _sprite6xy=       $60070;
      _sprite6zoom=     $60074;
      _sprite7xy=       $60078;
      _sprite7zoom=     $6007C;
      _sprite0ptr=      $60080;
      _sprite1ptr=      $60084;
      _sprite2ptr=      $60088;
      _sprite3ptr=      $6008C;
      _sprite4ptr=      $60090;
      _sprite5ptr=      $60094;
      _sprite6ptr=      $60098;
      _sprite7ptr=      $6009C;
      _textcursor=      $600A0;
      _tcx=             $600A0;
      _tcy=             $600A2;
      _textcolor=       $600A4;
      _bkcolor=         $600A8;
      _textsize=        $600AC;
      _audiodma=        $600C0;
      _dblbufscn1=      $60400;
      _dblbufscn2=      $60404;
      _nativex=         $60408;
      _nativey=         $6040C;
      _initialdl=       $60410;
      _kbd_report=      $60FF8;


type

     // Retromachine main thread

     TRetro = class(TThread)
     private
     protected
       procedure Execute; override;
     public
       Constructor Create(CreateSuspended : boolean);
     end;


     // mouse thread

     Tmouse= class(TThread)
     private
     protected
       procedure Execute; override;
     public
      Constructor Create(CreateSuspended : boolean);
     end;

     TKeyboard= class(TThread)
     private
     protected
       procedure Execute; override;
     public
      Constructor Create(CreateSuspended : boolean);
     end;


type wavehead=packed record
    riff:integer;
    size:cardinal;
    wave:integer;
    fmt:integer;
    fmtl:integer;
    pcm:smallint;
    channels:smallint;
    srate:integer;
    brate:integer;
    bytesps:smallint;
    bps:smallint;
    data:integer;
    datasize:cardinal;
  end;



var fh,filetype:integer;                // this needs cleaning...
    sfh:integer;                        // SID file handler
    play:word;
    p2:^integer;
    tim,t,t2,t3,ts,t6,time6502:int64;
    vblank1:byte;
    scope:array[0..1023] of integer;
    db:boolean=false;
    debug:integer;
    sidtime:int64=0;
    timer1:int64=-1;
    siddelay:int64=20000;
    songtime,songfreq:int64;
    skip:integer;
    scj:integer=0;
    thread:TRetro;

    i,j,k,l,fh2,lines:integer;
    p,p3:pointer;
    b:byte;
    scrfh:integer;
    running:integer=0;
    p4:^integer;
    fb:pframebufferdevice;
    FramebufferProperties:TFramebufferProperties;
    kbd:array[0..15] of TKeyboarddata;
    m:array[0..128] of Tmousedata;
    pause1:boolean=false;
    i1l,i2l,fbl,topl:integer;
    i1r,i2r,fbr,topr:integer;

    buf2:array[0..1919] of smallint;
    buf2f:array[0..959] of single absolute buf2;
    amouse:tmouse ;
    akeyboard:tkeyboard ;

    psystem,psystem2:pointer;

    vol123:integer=0;
    textcursoron:boolean=false;
    head:wavehead;
    nextsong:integer=0;

    oldsc:integer=0;
    sc:integer=0;



    mp3time:int64;

// system variables

    systempallette:array[0..255] of TPallette absolute base+_pallette;
    systemfont:TFont   absolute base+_systemfont;
    sprite0def:TSprite absolute base+_sprite0def;
    sprite1def:TSprite absolute base+_sprite1def;
    sprite2def:TSprite absolute base+_sprite2def;
    sprite3def:TSprite absolute base+_sprite3def;
    sprite4def:TSprite absolute base+_sprite4def;
    sprite5def:TSprite absolute base+_sprite5def;
    sprite6def:TSprite absolute base+_sprite6def;
    sprite7def:TSprite absolute base+_sprite7def;

    framecnt:        cardinal absolute base+_framecnt;
    displaystart:    cardinal absolute base+_displaystart;
    graphicmode:     cardinal absolute base+_graphicmode;
    bpp:             byte     absolute base+_bpp;
    bordercolor:     cardinal absolute base+_bordercolor;
    pallettebank:    cardinal absolute base+_pallettebank;
    palletteselector:cardinal absolute base+_palletteselector;
    dlstart:         cardinal absolute base+_dlstart;
    hscroll:         cardinal absolute base+_hscroll;
    xres:            integer  absolute base+_xres;
    yres:            integer  absolute base+_yres;
    key_charcode:    byte     absolute base+_keybd;
    key_modifiers:   byte     absolute base+_keybd+1;
    key_scancode:    byte     absolute base+_keybd+2;
    key_release :    byte     absolute base+_keybd+3;
    mousexy:         cardinal absolute base+_mousexy;
    mousex:          word     absolute base+_mousexy;
    mousey:          word     absolute base+_mousexy+2;
    mousek:          byte     absolute base+_mousekey;
    mouseclick:      byte     absolute base+_mousekey+1;
    mousewheel:      byte     absolute base+_mousekey+2;
    mousedblclick:   byte     absolute base+_mousekey+3;
    dlpos:           cardinal absolute base+_dlpos;
    sprite0xy:       cardinal absolute base+_sprite0xy;
    sprite0x:        smallint absolute base+_sprite0xy;
    sprite0y:        smallint absolute base+_sprite0xy+2;
    sprite0zoom:     cardinal absolute base+_sprite0zoom;
    sprite0zoomx:    word     absolute base+_sprite0zoom;
    sprite0zoomy:    word     absolute base+_sprite0zoom+2;
    sprite1xy:       cardinal absolute base+_sprite1xy;
    sprite1x:        smallint absolute base+_sprite1xy;
    sprite1y:        smallint absolute base+_sprite1xy+2;
    sprite1zoom:     cardinal absolute base+_sprite1zoom;
    sprite1zoomx:    word     absolute base+_sprite1zoom;
    sprite1zoomy:    word     absolute base+_sprite1zoom+2;
    sprite2xy:       cardinal absolute base+_sprite2xy;
    sprite2x:        smallint absolute base+_sprite2xy;
    sprite2y:        smallint absolute base+_sprite2xy+2;
    sprite2zoom:     cardinal absolute base+_sprite2zoom;
    sprite2zoomx:    word     absolute base+_sprite2zoom;
    sprite2zoomy:    word     absolute base+_sprite2zoom+2;
    sprite3xy:       cardinal absolute base+_sprite3xy;
    sprite3x:        smallint absolute base+_sprite3xy;
    sprite3y:        smallint absolute base+_sprite3xy+2;
    sprite3zoom:     cardinal absolute base+_sprite3zoom;
    sprite3zoomx:    word     absolute base+_sprite3zoom;
    sprite3zoomy:    word     absolute base+_sprite3zoom+2;
    sprite4xy:       cardinal absolute base+_sprite4xy;
    sprite4x:        smallint absolute base+_sprite4xy;
    sprite4y:        smallint absolute base+_sprite4xy+2;
    sprite4zoom:     cardinal absolute base+_sprite4zoom;
    sprite4zoomx:    word     absolute base+_sprite4zoom;
    sprite4zoomy:    word     absolute base+_sprite4zoom+2;
    sprite5xy:       cardinal absolute base+_sprite5xy;
    sprite5x:        smallint absolute base+_sprite5xy;
    sprite5y:        smallint absolute base+_sprite5xy+2;
    sprite5zoom:     cardinal absolute base+_sprite5zoom;
    sprite5zoomx:    word     absolute base+_sprite5zoom;
    sprite5zoomy:    word     absolute base+_sprite5zoom+2;
    sprite6xy:       cardinal absolute base+_sprite6xy;
    sprite6x:        smallint absolute base+_sprite6xy;
    sprite6y:        smallint absolute base+_sprite6xy+2;
    sprite6zoom:     cardinal absolute base+_sprite6zoom;
    sprite6zoomx:    word     absolute base+_sprite6zoom;
    sprite6zoomy:    word     absolute base+_sprite6zoom+2;
    sprite7xy:       cardinal absolute base+_sprite7xy;
    sprite7x:        smallint  absolute base+_sprite7xy;
    sprite7y:        smallint absolute base+_sprite7xy+2;
    sprite7zoom:     cardinal absolute base+_sprite7zoom;
    sprite7zoomx:    word     absolute base+_sprite7zoom;
    sprite7zoomy:    word     absolute base+_sprite7zoom+2;

    sprite0ptr:      cardinal absolute base+_sprite0ptr;
    sprite1ptr:      cardinal absolute base+_sprite1ptr;
    sprite2ptr:      cardinal absolute base+_sprite2ptr;
    sprite3ptr:      cardinal absolute base+_sprite3ptr;
    sprite4ptr:      cardinal absolute base+_sprite4ptr;
    sprite5ptr:      cardinal absolute base+_sprite5ptr;
    sprite6ptr:      cardinal absolute base+_sprite6ptr;
    sprite7ptr:      cardinal absolute base+_sprite7ptr;

    spritepointers:  array[0..7] of cardinal absolute base+_sprite0ptr;

    textcursor:      cardinal absolute base+_textcursor;
    tcx:             word     absolute base+_textcursor;
    tcy:             word     absolute base+_textcursor+2;
    textcolor:       cardinal absolute base+_textcolor;
    bkcolor:         cardinal absolute base+_bkcolor;
    textsizex:       byte     absolute base+_textsize;
    textsizey:       byte     absolute base+_textsize+1;
    textpitch:       byte     absolute base+_textsize+2;
    audiodma1:       array[0..7] of cardinal absolute base+_audiodma;
    audiodma2:       array[0..7] of cardinal absolute base+_audiodma+32;
    dblbufscn1:      cardinal absolute base+_dblbufscn1;
    dblbufscn2:      cardinal absolute base+_dblbufscn2;
    nativex:         cardinal absolute base+_nativex;
    nativey:         cardinal absolute base+_nativey;

    kbdreport:       array[0..7] of byte absolute base+_kbd_report;


    error:integer;
    mousereports:array[0..31] of TMouseReport;

    mp3bufidx:integer=0;
    outbufidx:integer=0;
    framesize:integer;
    backgroundaddr:cardinal=mainscreen;
    screenaddr:cardinal=mainscreen+$800000;
    redrawing:cardinal=mainscreen+$800000;
    windowsdone:boolean=false;
    drive:string;

    mp3frames:integer=0;
    debug1,debug2,debug3:cardinal;
    retropointer:pointer; // pointer to the original address of retromachine ram
    retroscreen:pointer;

// prototypes

procedure initmachine(mode:integer);
procedure stopmachine;

procedure graphics(mode:integer);
procedure setpallette(pallette:TPallette;bank:integer);
procedure cls(c:integer);
procedure putpixel(x,y,color:integer);
procedure putchar(x,y:integer;ch:char;col:integer);
procedure outtextxy(x,y:integer; t:string;c:integer);
procedure blit(from,x,y,too,x2,y2,length,lines,bpl1,bpl2:integer);
procedure box(x,y,l,h,c:integer);
procedure box2(x1,y1,x2,y2,color:integer);
procedure box32(x,y,l,h,c:integer);
procedure box322(x1,y1,x2,y2,color:integer);
function gettime:int64;
procedure poke(addr:cardinal;b:byte);
procedure dpoke(addr:cardinal;w:word);
procedure lpoke(addr:cardinal;c:cardinal);
procedure slpoke(addr:cardinal;i:integer);
function peek(addr:cardinal):byte;
function dpeek(addr:cardinal):word;
function lpeek(addr:cardinal):cardinal;
function slpeek(addr:cardinal):integer;
procedure sethidecolor(c,bank,mask:cardinal);
procedure fcircle(x0,y0,r,c:integer);
procedure circle(x0,y0,r,c:integer);
procedure line(x,y,dx,dy,c:integer);
procedure line2(x1,y1,x2,y2,c:integer);
procedure putcharz(x,y:integer;ch:char;col,xz,yz:integer);
procedure outtextxyz(x,y:integer; t:string;c,xz,yz:integer);
procedure outtextxys(x,y:integer; t:string;c,s:integer);
procedure outtextxyzs(x,y:integer; t:string;c,xz,yz,s:integer);
procedure scrollup;
function getpixel(x,y:integer):integer; inline;
function getkey:integer; inline;
function readkey:integer; inline;
function getreleasedkey:integer; inline;
function readreleasedkey:integer; inline;
function keypressed:boolean;
function click:boolean;
function dblclick:boolean;
procedure waitvbl;
procedure removeramlimits(addr:integer);
function remapram(from,too,size:cardinal):cardinal;
function readwheel: shortint; inline;
procedure unhidecolor(c,bank:cardinal);
procedure scrconvertnative(src,screen:pointer);
procedure print(line:string);
procedure println(line:string);

implementation

uses blitter, mwindows, sid;

var windows:Twindows;
procedure scrconvert(src,screen:pointer); forward;
procedure sprite(screen:pointer); forward;


// ---- TMouse thread methods --------------------------------------------------

operator =(a,b:tmousereport):boolean;

var i:integer;

begin
result:=true;
for i:=0 to 7 do if a[i]<>b[i] then result:=false;
end;
constructor TMouse.Create(CreateSuspended : boolean);

begin
FreeOnTerminate := True;
inherited Create(CreateSuspended);
end;

procedure TMouse.Execute;

label p101,p102;

var mb:tmousedata;
    i,j:integer;
    mi:cardinal;
    x,y,w:integer;
    m:TMouseReport;
    mousexy,buttons,offsetx,offsety,wheel:integer;
    const mousecount:integer=0;

begin
ThreadSetpriority(ThreadGetCurrent,5);
threadsleep(1);
mousetype:=0;
  repeat
    p102:
    repeat m:=getmousereport; threadsleep(2); until m[0]<>255;
    if (mousetype=1) and (m=mousereports[7]) and (m[0]=1) and (m[2]=0) and (m[3]=0) and (m[4]=0) and (m[5]=0) then goto p102; //ignore empty M1 records

    mousecount+=1;
    j:=0; for i:=0 to 7 do if m[i]<>0 then j+=1;
    if (j>1) or (mousecount<16) then
      begin
      for i:=0 to 7 do mouserecord[i]:=(m[i]);
      for i:=0 to 6 do mousereports[i]:=mousereports[i+1];
      mousereports[7]:=m;
      end;

    j:=0;
    for i:=0 to 6 do if mousereports[i,7]<>m[7]  then j+=1;
    for i:=0 to 6 do if mousereports[i,6]<>m[6]  then j+=1;
    for i:=0 to 6 do if mousereports[i,5]<>m[5]  then j+=1;
    for i:=0 to 6 do if mousereports[i,4]<>m[4]  then j+=1;
    if j=0 then begin mousetype:=0; goto p101; end;

    j:=0;
    for i:=0 to 6 do begin j+=mousereports[i,1]; j+=mousereports[i,7]; end;
    for i:=0 to 6 do if (mousereports[i,3]<>$FF) and (mousereports[i,3]<>0) then j+=1;
    if j=0 then begin mousetype:=3; goto p101; end;

    for i:=0 to 6 do if mousereports[i,7]<>m[7] then mousetype:=m[0]; // 1 or 2

p101:

    if mousetype=0 then  // most standard mouse type
       begin
       buttons:=m[0];
       offsetx:=shortint(m[1]);
       offsety:=shortint(m[2]);
       wheel:=shortint(m[3]);
       end
    else if mousetype=2 then  // the strange Logitech wireless 12-bit mouse
       begin
       buttons:=m[1];
       mousexy:=m[2]+256*(m[3] and 15);
       if mousexy>=2048 then mousexy:=mousexy-4096;
       if m[6]=0 then offsetx:=mousexy else offsetx:=0;
       mousexy:=m[4]*16 + m[3] div 16;
       if mousexy>=2048 then mousexy:=mousexy-4096;
       if m[6]=0 then offsety:=mousexy else offsety:=0;
       if ((m[7]=134) or (m[7]=198)) and (m[6]=0) and (m[1]=0) and (m[2]=0) and (m[3]=0) and (m[4]=0) then wheel:=shortint(m[5]) else wheel:=0;
       end
     else if mousetype=1 then
       begin
       buttons:=m[1];
       mousexy:=m[2]+256*(m[3] and 15);
       if mousexy>=2048 then mousexy:=mousexy-4096;
       offsetx:=mousexy;
       mousexy:=m[4]*16 + m[3] div 16;
       if mousexy>=2048 then mousexy:=mousexy-4096;
       offsety:=mousexy;
       wheel:=shortint(m[5]);
       end
    else if mousetype=3 then  // 16-bit mouse
       begin
       buttons:=shortint(m[0]);
       offsetx:=shortint(m[2]);
       offsety:=shortint(m[4]);
       wheel:=shortint(m[6]);
       end;
    x:=mousex+offsetx;
    if x<0 then x:=0;
    if x>(xres-1) then x:=xres-1;
    mousex:=x;
    y:=mousey+offsety;
    if y<0 then y:=0;
    if y>(yres-1) then y:=yres-1;
    mousey:=y;
    mousek:=Buttons and 255;
    if wheel<-1 then wheel:=-1;
    if wheel>1 then wheel:=1;
    w:=mousewheel+Wheel;
    if w<127 then w:=127;
    if w>129 then w:=129;
    mousewheel:=w;
  until terminated;
end;

// ---- TKeyboard thread methods --------------------------------------------------

constructor TKeyboard.Create(CreateSuspended : boolean);

begin
FreeOnTerminate := True;
inherited Create(CreateSuspended);
end;


procedure TKeyboard.Execute;

// At every vblank the thread tests if there is a report from the keyboard
// If yes, the kbd codes are poked to the system variables
// $60028 - translated code
// $60029 - modifiers
// $6002A - raw code
// This thread also tracks mouse clicks

const rptcnt:integer=0;
      activekey:integer=0;
      olactivekey:integer=0;
      oldactivekey:integer=0;
      lastactivekey:integer=0;
      m:integer=0;
      c:integer=0;
      dblclick:integer=0;
      dblcnt:integer=0;
      clickcnt:integer=0;
      click:integer=0;

var ch:TKeyboardReport;
    i:integer;
    keyrelease, found:integer;

begin
ThreadSetpriority(ThreadGetCurrent,5);
threadsleep(1);
for i:=0 to 7 do kbdreport[i]:=0;
repeat
  waitvbl;
  sprite7xy:=mousexy;//+$00280040;           //sprite coordinates are fullscreen
                                            //while mouse is on active screen only

  if mousedblclick=2 then begin dblclick:=0; dblcnt:=0; mousedblclick:=0; end;
  if (dblclick=0) and (mousek=1) then begin dblclick:=1; dblcnt:=0; end;
  if (dblclick=1) and (mousek=0) then begin dblclick:=2; dblcnt:=0; end;
  if (dblclick=2) and (mousek=1) then begin dblclick:=3; dblcnt:=0; end;
  if (dblclick=3) and (mousek=0) then begin dblclick:=4; dblcnt:=0; end;

  inc(dblcnt); if dblcnt>10 then begin dblcnt:=10; dblclick:=0; end;
  if dblclick=4 then mousedblclick:=1 {else mousedblclick:=0};

  if peek(base+$60031)=2 then begin click:=2; clickcnt:=10; end;
  if (mousek=1) and (click=0) then begin click:=1; clickcnt:=0; end;
  inc(clickcnt); if clickcnt>10 then  begin clickcnt:=10; click:=2; end;
  if (mousek=0) then click:=0;
  if click=1 then mouseclick:=1 else mouseclick:=0;

 ch:=getkeyboardreport;

 if ch[7]<>255 then
   begin
//   box(0,0,300,16,0); for i:=0 to 7 do outtextxy(i*32,0, inttostr(ch[i]),120);
//   generate a key release events, too...
   keyrelease:=0;
   for i:=2 to 7 do
      begin
      if kbdreport[i]>3 then
        begin
        found:=0;
        for j:=2 to 7 do
          begin
          if ch[j]=kbdreport[i] then found:=1;
          end;
        if found=0 then keyrelease:=kbdreport[i];
        end;
      end;

   if keyrelease<>0 then key_release:=keyrelease;

   for i:=0 to 7 do kbdreport[i]:=ch[i];
   olactivekey:=lastactivekey;
   oldactivekey:=activekey;
   lastactivekey:=0;
   activekey:=0;
   if ch[0]>0 then begin m:=ch[0]; key_modifiers:=m; end;
   for i:=2 to 7 do if (ch[i]>3) and (ch[i]<255) then lastactivekey:=i;
   if (lastactivekey>olactivekey) and (lastactivekey>0) then begin rptcnt:=0; activekey:=ch[lastactivekey];  end
   else if (lastactivekey<olactivekey) then begin rptcnt:=0; activekey:=0; end
   else if (lastactivekey=olactivekey) and (lastactivekey>0) and (oldactivekey<>ch[lastactivekey]) then begin rptcnt:=0; activekey:=ch[lastactivekey]; end;
   if lastactivekey<2 then begin rptcnt:=0; activekey:=0; m:=0; end;
   c:=byte(translatescantochar(activekey,0));
   if (m and $22)<>0 then c:=byte(translatescantochar(activekey,1));
   if (m and $42)=$40 then c:=byte(translatescantochar(activekey,2));
   if (m and $42)=$42 then c:=byte(translatescantochar(activekey,3));
   end;

 if (c>2) then inc(rptcnt);

 if rptcnt>26 then rptcnt:=24 ;
 if (rptcnt=1) or (rptcnt=24) then
   begin
   key_charcode:=byte(c);
   key_scancode:=activekey mod 256;
   end;
until terminated;
end;


// ---- TRetro thread methods --------------------------------------------------

// ----------------------------------------------------------------------
// constructor: create the thread for the retromachine
// ----------------------------------------------------------------------

constructor TRetro.Create(CreateSuspended : boolean);

begin
  FreeOnTerminate := True;
  inherited Create(CreateSuspended);
end;

// ----------------------------------------------------------------------
// THIS IS THE MAIN RETROMACHINE THREAD
// - convert retromachine screen to raspberry screen
// - display sprites
// ----------------------------------------------------------------------

procedure TRetro.Execute;

// --- rev 21070111

var id:integer;
    wh:TWindow;
    screen:integer;

begin
ThreadSetCPU(ThreadGetCurrent,CPU_ID_3);
ThreadSetAffinity(ThreadGetCurrent,CPU_AFFINITY_3);
ThreadSetPriority(ThreadGetCurrent,5);
threadsleep(1);

running:=1;
repeat
  begin
  vblank1:=0;
  t:=gettime;

//  scrconvertnative(pointer(mainscreen+$800000),p2);   //8
threadsleep(5);
  screenaddr:=mainscreen+$800000;
  poke(base+$71000,1);
  tim:=gettime-t;
  t:=gettime;
  sprite(p2);
  ts:=gettime-t;
  vblank1:=1;
  CleanDataCacheRange(integer(p2),(xres+64)*yres*4);
  framecnt+=1;

  FramebufferDeviceSetOffset(fb,0,0,True);
  FramebufferDeviceWaitSync(fb);

  vblank1:=0;
  t:=gettime;

 // scrconvertnative(pointer(mainscreen+$b00000),p2+(xres+64)*(yres{+32}));   //a
 threadsleep(5);
  screenaddr:=mainscreen+$b00000;
  poke(base+$71000,0);
  tim:=gettime-t;
  t:=gettime;
  sprite(p2+(xres+64)*(yres));
  ts:=gettime-t;
  vblank1:=1;
  CleanDataCacheRange(integer(p2)+(xres+64)*(yres{+32})*4,(xres)*yres*4);
  framecnt+=1;

  FramebufferDeviceSetOffset(fb,0,yres,True);
  FramebufferDeviceWaitSync(fb);

  end;
until terminated;
running:=0;
end;


// ---- Retromachine procedures ------------------------------------------------

// ----------------------------------------------------------------------
// initmachine: start the machine
// ----------------------------------------------------------------------

procedure initmachine(mode:integer);

// -- rev 20180423

var i:integer;
    mousedata:TSprite;
    c:cardinal;

begin

// clean all system area

// get 512 MB of RAM for the machine
retropointer:=getalignedmem($20000000,$100000);
retroscreen:=getalignedmem($1000000,$100000);
remapram(cardinal(retropointer),base,$20000000);
remapram(cardinal(retroscreen),mainscreen,$1000000);


for c:=base to base+$FFFFF do poke(c,0);

repeat fb:=FramebufferDevicegetdefault until fb<>nil;

// get native resolution
FramebufferDeviceGetProperties(fb,@FramebufferProperties);
nativex:=FramebufferProperties.PhysicalWidth;
nativey:=FramebufferProperties.PhysicalHeight;

FramebufferDeviceRelease(fb);

if (nativex>=1024) and (nativey>=720) then
  begin
  xres:=nativex;
  yres:=nativey;
  end
else
  begin
  xres:=round(2*nativex);
  yres:=round(2*nativey);
  end;

FramebufferProperties.Depth:=32;
FramebufferProperties.PhysicalWidth:=xres;
FramebufferProperties.PhysicalHeight:=yres;
FramebufferProperties.VirtualWidth:=xres+64;
FramebufferProperties.VirtualHeight:=yres*2;
FramebufferDeviceAllocate(fb,@FramebufferProperties);
threadsleep(300);

FramebufferDeviceGetProperties(fb,@FramebufferProperties);
p2:=Pointer(FramebufferProperties.Address);

bordercolor:=0;
displaystart:=mainscreen;                 // vitual framebuffer address
framecnt:=0;                              // frame counter

// init pallette, font and mouse cursor

systemfont:=st4font;
//systemfont:=st4font;
sprite7def:=mysz;
sprite7zoom:=$00010001;
setpallette(ataripallette,0);

// init sprite data pointers
for i:=0 to 7 do spritepointers[i]:=base+_sprite0def+4096*i;

// init sid variables



//reset6502;

//mad_stream_init(@test_mad_stream);
//mad_synth_init(@test_mad_synth);
//mad_frame_init(@test_mad_frame);

removeramlimits(integer(@sprite));

mousex:=xres div 2;
mousey:=yres div 2;
mousewheel:=128;


background:=TWindow.create(xres,yres,'');
background32:=TWindow32.create(xres,yres,'');
panel:=TPanel.create;
threadsleep(100);

// start frame refreshing thread
thread:=tretro.create(true);
thread.start;

// start windows --- TODO - remove this from here!!!
windows:=twindows.create(true);
windows.start;
mousedata:=mysz;
for i:=0 to 1023 do if mousedata[i]<>0 then mousedata[i]:=mousedata[i] or $FF000000;
amouse:=tmouse.create(true);
amouse.start;

akeyboard:=tkeyboard.create(true);
akeyboard.start;
end;


//  ---------------------------------------------------------------------
//   stopmachine: stop the retromachine
//   rev. 20170111
//  ---------------------------------------------------------------------

procedure stopmachine;

begin
thread.terminate;
repeat until running=0;
amouse.terminate;
akeyboard.terminate;
windows.terminate;
end;

// -----  Screen convert procedures

procedure scrconvert(src,screen:pointer);

// --- rev 21070111

var a,b,c:integer;
    e:integer;

label p1,p0,p002,p10,p11,p12,p999;

begin
a:=displaystart;
c:=integer(src);//$30800000;  // map start
e:=bordercolor;
b:=base+_pallette;

                asm

                stmfd r13!,{r0-r12,r14}   //Push registers
                ldr r1,c
                ldr r2,screen
                ldr r3,b
                mov r5,r2

                //upper border

                add r5,#307200
                ldr r4,e
                mov r6,r4
                mov r7,r4
                mov r8,r4
                mov r9,r4
                mov r10,r4
                mov r12,r4
                mov r14,r4


p10:            stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                cmp r2,r5
                blt p10

                mov r0,#1120

p11:            add r5,#256

                //left border

p0:             stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}


                                    //active screen
                add r5,#7168

p1:
                ldm r1!,{r4,r9}

                mov r6,r4,lsr #8
                mov r7,r4,lsr #16
                mov r8,r4,lsr #24
                mov r10,r9,lsr #8
                mov r12,r9,lsr #16
                mov r14,r9,lsr #24

                and r4,#0xFF
                and r6,#0xFF
                and r7,#0xFF
                and r9,#0xFF
                and r10,#0xFF
                and r12,#0xFF

                ldr r4,[r3,r4,lsl #2]
                ldr r6,[r3,r6,lsl #2]
                ldr r7,[r3,r7,lsl #2]
                ldr r8,[r3,r8,lsl #2]
                ldr r9,[r3,r9,lsl #2]
                ldr r10,[r3,r10,lsl #2]
                ldr r12,[r3,r12,lsl #2]
                ldr r14,[r3,r14,lsl #2]

                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}

                ldm r1!,{r4,r9}

                mov r6,r4,lsr #8
                mov r7,r4,lsr #16
                mov r8,r4,lsr #24
                mov r10,r9,lsr #8
                mov r12,r9,lsr #16
                mov r14,r9,lsr #24

                and r4,#0xFF
                and r6,#0xFF
                and r7,#0xFF
                and r9,#0xFF
                and r10,#0xFF
                and r12,#0xFF

                ldr r4,[r3,r4,lsl #2]
                ldr r6,[r3,r6,lsl #2]
                ldr r7,[r3,r7,lsl #2]
                ldr r8,[r3,r8,lsl #2]
                ldr r9,[r3,r9,lsl #2]
                ldr r10,[r3,r10,lsl #2]
                ldr r12,[r3,r12,lsl #2]
                ldr r14,[r3,r14,lsl #2]

                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}

                cmp r2,r5
                blt p1

                                  //right border
                add r5,#256
                ldr r4,e
                mov r6,r4
                mov r7,r4
                mov r8,r4
                mov r9,r4
                mov r10,r4
                mov r12,r4
                mov r14,r4


p002:           stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}

                subs r0,#1
                bne p11
                                  //lower border
                add r5,#307200

p12:            stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}

                cmp r2,r5
                blt p12
p999:           ldmfd r13!,{r0-r12,r14}
                end;


end;


procedure scrconvertnative(src,screen:pointer);

// --- rev 21070608

var a,b,c:integer;
    e:integer;
    nx,ny:cardinal;

label p1,p0,p002,p10,p11,p12,p999;

begin
a:=displaystart;
c:=integer(src);//$30800000;  // map start
e:=bordercolor;
b:=base+_pallette;
ny:=yres;//nativey;
nx:=xres*4;//nativex*4;

                asm

                stmfd r13!,{r0-r12,r14}   //Push registers
                ldr r1,c
                ldr r2,screen
                ldr r3,b
                mov r5,r2
                sub r2,#256
                sub r5,#256

                //upper border


                ldr r0,ny

p11:            ldr r4,nx                                   //active screen
                add r5,r4 //#7168
                    add r2,#256
                    add r5,#256

p1:
                ldm r1!,{r4,r9}

                mov r6,r4,lsr #8
                mov r7,r4,lsr #16
                mov r8,r4,lsr #24
                mov r10,r9,lsr #8
                mov r12,r9,lsr #16
                mov r14,r9,lsr #24

                and r4,#0xFF
                and r6,#0xFF
                and r7,#0xFF
                and r9,#0xFF
                and r10,#0xFF
                and r12,#0xFF

                ldr r4,[r3,r4,lsl #2]
                ldr r6,[r3,r6,lsl #2]
                ldr r7,[r3,r7,lsl #2]
                ldr r8,[r3,r8,lsl #2]
                ldr r9,[r3,r9,lsl #2]
                ldr r10,[r3,r10,lsl #2]
                ldr r12,[r3,r12,lsl #2]
                ldr r14,[r3,r14,lsl #2]

                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}

                ldm r1!,{r4,r9}

                mov r6,r4,lsr #8
                mov r7,r4,lsr #16
                mov r8,r4,lsr #24
                mov r10,r9,lsr #8
                mov r12,r9,lsr #16
                mov r14,r9,lsr #24

                and r4,#0xFF
                and r6,#0xFF
                and r7,#0xFF
                and r9,#0xFF
                and r10,#0xFF
                and r12,#0xFF

                ldr r4,[r3,r4,lsl #2]
                ldr r6,[r3,r6,lsl #2]
                ldr r7,[r3,r7,lsl #2]
                ldr r8,[r3,r8,lsl #2]
                ldr r9,[r3,r9,lsl #2]
                ldr r10,[r3,r10,lsl #2]
                ldr r12,[r3,r12,lsl #2]
                ldr r14,[r3,r14,lsl #2]

                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}

                cmp r2,r5
                blt p1

                subs r0,#1
                bne p11


p999:           ldmfd r13!,{r0-r12,r14}
                end;


end;

procedure scrconvertdl(screen:pointer);

// --- rev 21070111

var a,b:integer;
    e:integer;
    c,command, pixels, lines, dl:cardinal;

const scr:cardinal=mainscreen;

label p001;

begin
a:=displaystart;
e:=bordercolor;
c:=scr;
b:=base+_pallette;
dl:=lpeek(base+$60034);

 // rev 20170607

// DL graphic mode

//xxxxDDMM
// xxxx = 0001 for RPi Retromachine
// MM: 00: hi, 01 med 10 low 11 native borderless
// DD: 00 8bpp 01 16 bpp 10 32 bpp 11 border

//    2F06_0018 - display list start addr  ----TODO
//                DL entry: 00xx_YYLLL_MM - display LLL lines in mode MM
//                            xx: 00 - do nothing
//                                01 - raster interrupt
//                                10 - set pallette bank YY
//                                11 - set horizontal scroll at YY
//                          01xx_AAAAAAA - wait for vsync, then start DL @xxAAAAAA
//                          10xx_AAAAAAA - set display address to xxAAAAAAA
//                          11xx_AAAAAAA - goto address xxAAAAAAA

//    2F06_0034 - current dl position ----TODO

//    2F06_0008 - current graphics mode   ----TODO
//      2F06_0009 - bytes per pixel
//    2F06_000C - border color
//    2F06_0010 - pallette bank           ----TODO
//    2F06_0014 - horizontal pallette selector: bit 31 on, 30..20 add to $60010, 11:0 pixel num. ----TODO
//    2F06_0018 - display list start addr  ----TODO
//                DL entry: 00xx_YYLLL_MM - display LLL lines in mode MM
//                            xx: 00 - do nothing
//                                01 - raster interrupt
//                                10 - set pallette bank YY
//                                11 - set horizontal scroll at YY
//                          10xx_AAAAAAA - set display address to xxAAAAAAA
//                          11xx_AAAAAAA - goto address xxAAAAAAA
//    2F06_001C - horizontal scroll right register ----TODO
//    2F06_0020 - x res
//    2F06_0024 - y res


command:=lpeek(dl);
if (command and $C0000000) = 0 then // display
  begin
  if command and $FF=$1C then       // border
    begin
    lines:=(command and $000FFF00) shr 8;
    pixels:=lines*1920*4;    // border modes are always signalling 1920x1200
                asm
                push {r0-r9}
                ldr r1,e
                ldr r0,c
                mov r2,r1
                mov r3,r1
                mov r4,r1
                mov r5,r1
                mov r6,r1
                mov r7,r1
                mov r8,r1
                mov r8,r1
                ldr r9,pixels
                add r9,r0
p001:           stm r0!,{r1,r2,r3,r4,r5,r6,r7,r8}
                stm r0!,{r1,r2,r3,r4,r5,r6,r7,r8}
                stm r0!,{r1,r2,r3,r4,r5,r6,r7,r8}
                stm r0!,{r1,r2,r3,r4,r5,r6,r7,r8}
                stm r0!,{r1,r2,r3,r4,r5,r6,r7,r8}
                stm r0!,{r1,r2,r3,r4,r5,r6,r7,r8}
                stm r0!,{r1,r2,r3,r4,r5,r6,r7,r8}
                stm r0!,{r1,r2,r3,r4,r5,r6,r7,r8}
                cmp r0,r9
                blt p001
                pop {r0-r9}
                end;
    end
  else if command and $FF=$10 then       // hi res bordered 8bpp
    begin
    end
  else if command and $FF=$13 then       // native bordreless 8bpp
    begin
    end
  end;
{
                asm

                stmfd r13!,{r0-r12,r14}   //Push registers
                ldr r1,c
                ldr r2,screen
                ldr r3,b
                mov r5,r2

                //upper border

                add r5,#307200
                ldr r4,e
                mov r6,r4
                mov r7,r4
                mov r8,r4
                mov r9,r4
                mov r10,r4
                mov r12,r4
                mov r14,r4


p10:            stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                cmp r2,r5
                blt p10

                mov r0,#1120

p11:            add r5,#256

                //left border

p0:             stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}


                                    //active screen
                add r5,#7168

p1:
                ldm r1!,{r4,r9}

                mov r6,r4,lsr #8
                mov r7,r4,lsr #16
                mov r8,r4,lsr #24
                mov r10,r9,lsr #8
                mov r12,r9,lsr #16
                mov r14,r9,lsr #24

                and r4,#0xFF
                and r6,#0xFF
                and r7,#0xFF
                and r9,#0xFF
                and r10,#0xFF
                and r12,#0xFF

                ldr r4,[r3,r4,lsl #2]
                ldr r6,[r3,r6,lsl #2]
                ldr r7,[r3,r7,lsl #2]
                ldr r8,[r3,r8,lsl #2]
                ldr r9,[r3,r9,lsl #2]
                ldr r10,[r3,r10,lsl #2]
                ldr r12,[r3,r12,lsl #2]
                ldr r14,[r3,r14,lsl #2]

                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}

                ldm r1!,{r4,r9}

                mov r6,r4,lsr #8
                mov r7,r4,lsr #16
                mov r8,r4,lsr #24
                mov r10,r9,lsr #8
                mov r12,r9,lsr #16
                mov r14,r9,lsr #24

                and r4,#0xFF
                and r6,#0xFF
                and r7,#0xFF
                and r9,#0xFF
                and r10,#0xFF
                and r12,#0xFF

                ldr r4,[r3,r4,lsl #2]
                ldr r6,[r3,r6,lsl #2]
                ldr r7,[r3,r7,lsl #2]
                ldr r8,[r3,r8,lsl #2]
                ldr r9,[r3,r9,lsl #2]
                ldr r10,[r3,r10,lsl #2]
                ldr r12,[r3,r12,lsl #2]
                ldr r14,[r3,r14,lsl #2]

                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}

                cmp r2,r5
                blt p1

                                  //right border
                add r5,#256
                ldr r4,e
                mov r6,r4
                mov r7,r4
                mov r8,r4
                mov r9,r4
                mov r10,r4
                mov r12,r4
                mov r14,r4


p002:           stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}

                subs r0,#1
                bne p11
                                  //lower border
                add r5,#307200

p12:            stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}
                stm r2!,{r4,r6,r7,r8,r9,r10,r12,r14}

                cmp r2,r5
                blt p12
p999:           ldmfd r13!,{r0-r12,r14}
                end;
}
end;

procedure sprite(screen:pointer);

// A sprite procedure
// --- rev 21070111

label p101,p102,p103,p104,p105,p106,p107,p108,p109,p999,a7680,affff,affff0000,spritedata;
var spritebase:integer;
    nx:cardinal;
    yr:cardinal;
    scrl:cardinal;

begin
yr:=yres;
spritebase:=base+_spritebase;
nx:=xres*4+256;
scrl:=integer(screen)+(xres+64)*yres*4;

               asm
               stmfd r13!,{r0-r12,r14}     //Push registers
               ldr r12,nx
               str r12,a7680
               mov r12,#0
                                       //sprite
               ldr r0,spritebase
 p103:         ldr r1,[r0],#4
               mov r2,r1, lsl #16      // sprite 0 position
               mov r3,r1, asr #16
               asr r2,#14              // x pos*4

               ldr r14,yr
               cmp r3,r14
               bge p107

               cmp r2,#8192            // switch off the sprite if x>2048
               blt p104
p107:          add r12,#1
               add r0,#4
               cmp r12,#8
               bge p999
               b   p103

p104:          ldr r4,a7680
               mul r3,r3,r4
               add r3,r2              // sprite pos


               ldr r4,screen
               add r3,r4              // pointer to upper left sprite pixel in r3
               ldr r4,spritedata
               add r4,r4,r12,lsl #2
               ldr r4,[r4]

               ldr r1,[r0],#4
               mov r2,r1,lsl #16
               lsr r2,#16             // xzoom
               lsr r1,#16             // yzoom
               cmp r1,#8
               movgt r1,#8            // zoom control, maybe switch it off?
               cmp r2,#8
               movgt r2,#8
               cmp r1,#1
               movle r1,#1
               cmp r2,#1
               movle r2,#1
               mov r7,r2
               mov r8,r2,lsl #7        // xzoom * 128 (128=4*32)
               mov r9,r1,lsl #5        //y zoom * 32
               mov r10,r1              //y zoom counter
               mov r6,#32

               push {r0}

p101:
               ldr r14,screen
               cmp r3,r14
               bge p109
               add r3,r8
               b p106

p109:          ldr r5,[r4],#4
               cmp r5,#0
               bne p102
               add r3,r3,r8,lsr #5
               mov r7,r2
               subs r6,#1
               bne p101
               b p106

p102:          ldr r0,[r3]
               cmp r12,r0,lsr #28
               strge r5,[r3],#4
               addlt r3,#4
               subs r7,#1
               bne p102

p105:          mov r7,r2
               subs r6,#1
               bne p109

p106:          ldr r0,a7680
               add r3,r0
               sub r3,r8

               ldr r14,scrl
               cmp r3,r14
               bge p108

               subs r10,#1
               subne r4,#128
               addeq r10,r1
               mov r6,#32
               subs r9,#1
               bne p101

p108:          pop {r0}


               add r12,#1
               cmp r12,#8
               bne p103
               b p999

affff:         .long 0xFFFF
affff0000:     .long 0xFFFF0000
a7680:         .long 7680
spritedata:    .long base+0x60080

p999:          ldmfd r13!,{r0-r12,r14}
               end;
end;

// ------  Helper procedures

procedure removeramlimits(addr:integer);

var Entry:TPageTableEntry;

begin
Entry:=PageTableGetEntry(addr);
Entry.Flags:=$3b2;            //executable, shareable, rw, cacheable, writeback
PageTableSetEntry(Entry);
Entry:=PageTableGetEntry(addr+MEMORY_PAGE_SIZE);
Entry.Flags:=$3b2;            //executable, shareable, rw, cacheable, writeback
PageTableSetEntry(Entry);
end;

function remapram(from,too,size:cardinal):cardinal;

var Entry:TPageTableEntry;
    s,len:integer;

begin
s:=size;
repeat
  Entry:=PageTableGetEntry(from);
  len:=entry.Size;
  entry.virtualaddress:=too;
  Entry.Flags:=$3b2;
  PageTableSetEntry(Entry);
  too+=len;
  from+=len;
  s-=len;
until s<=0;
CleanDataCacheRange(from, size);
InvalidateDataCacheRange(too, size);
end;



function gettime:int64; inline;

begin
result:=PLongWord($3F003004)^;
end;


procedure waitvbl;

begin
repeat threadsleep(1) until vblank1=0;
repeat threadsleep(1) until vblank1=1;
end;

function waitscreen:integer;

begin
repeat threadsleep(1) until vblank1=1;
end;

//  ---------------------------------------------------------------------
//   BASIC type poke/peek procedures
//   works @ byte addresses
//   rev. 20161124
// ----------------------------------------------------------------------

procedure poke(addr:cardinal;b:byte); inline;

begin
PByte(addr)^:=b;
end;

procedure dpoke(addr:cardinal;w:word); inline;

begin
PWord(addr and $FFFFFFFE)^:=w;
end;

procedure lpoke(addr:cardinal;c:cardinal); inline;

begin
PCardinal(addr and $FFFFFFFC)^:=c;
end;

procedure slpoke(addr:cardinal;i:integer); inline;

begin
PInteger(addr and $FFFFFFFC)^:=i;
end;

function peek(addr:cardinal):byte; inline;

begin
peek:=Pbyte(addr)^;
end;

function dpeek(addr:cardinal):word; inline;

begin
dpeek:=PWord(addr and $FFFFFFFE)^;
end;

function lpeek(addr:cardinal):cardinal; inline;

begin
lpeek:=PCardinal(addr and $FFFFFFFC)^;
end;

function slpeek(addr:cardinal):integer;  inline;

begin
slpeek:=PInteger(addr and $FFFFFFFC)^;
end;

// ------- Keyboard and mouse procedures

function keypressed:boolean;

begin
if peek(base+$60028)<>0 then result:=true else result:=false;
end;

function readkey:integer; inline;

begin
result:=lpeek(base+$60028) and $FFFFFF;
poke(base+$60028,0);
poke(base+$60029,0);
poke(base+$6002a,0);
end;

function getkey:integer; inline;

begin
result:=lpeek(base+$60028) and $FFFFFF;
end;

function readreleasedkey:integer; inline;

begin
result:=peek(base+$6002B);
poke(base+$6002B,0);
end;

function getreleasedkey:integer; inline;

begin
result:=peek(base+$6002B);
end;

function click:boolean; inline;

begin
if mouseclick=1 then  result:=true else result:=false;
if mouseclick=1 then  mouseclick:=2;
end;


function dblclick:boolean; inline;

begin
if mousedblclick=1 then result:=true else result:=false;
if mousedblclick=1 then mousedblclick:=2;
end;

function readwheel: shortint; inline;

begin
result:=mousewheel-128;
mousewheel:=128
end;

//------------------------------------------------------------------------------
// ----- Graphics mode setting ------------
//------------------------------------------------------------------------------

procedure graphics(mode:integer);

// rev 20170607

// Graphics mode set:
// 16 - HiRes 8bpp
// 17 - MedRes 16 bpp
// 18 - LoRes 32 bpp
// 19 - native, borderless, 8 bpp

// DL graphic mode

//xxxxDDMM
// xxxx = 0001 for RPi Retromachine
// MM: 00: hi, 01 med 10 low 11 native borderless
// DD: 00 8bpp 01 16 bpp 10 32 bpp 11 border

//    2F06_0018 - display list start addr  ----TODO
//                DL entry: 00xx_YYLLL_MM - display LLL lines in mode MM
//                            xx: 00 - do nothing
//                                01 - raster interrupt
//                                10 - set pallette bank YY
//                                11 - set horizontal scroll at YY
//                          01xx_AAAAAAA - wait for vsync, then start DL @xxAAAAAA
//                          10xx_AAAAAAA - set display address to xxAAAAAAA
//                          11xx_AAAAAAA - goto address xxAAAAAAA

//    2F06_0034 - current dl position ----TODO

//    2F06_0008 - current graphics mode   ----TODO
//      2F06_0009 - bytes per pixel
//    2F06_000C - border color
//    2F06_0010 - pallette bank           ----TODO
//    2F06_0014 - horizontal pallette selector: bit 31 on, 30..20 add to $60010, 11:0 pixel num. ----TODO
//    2F06_0018 - display list start addr  ----TODO
//                DL entry: 00xx_YYLLL_MM - display LLL lines in mode MM
//                            xx: 00 - do nothing
//                                01 - raster interrupt
//                                10 - set pallette bank YY
//                                11 - set horizontal scroll at YY
//                          10xx_AAAAAAA - set display address to xxAAAAAAA
//                          11xx_AAAAAAA - goto address xxAAAAAAA
//    2F06_001C - horizontal scroll right register ----TODO
//    2F06_0020 - x res
//    2F06_0024 - y res
begin
if mode=16 then
  begin
  poke(base+$60008,16);
  poke(base+$60009,8);
  lpoke(base+$60010,0);
  lpoke(base+$60014,0);
  lpoke(base+$60020,1792);
  lpoke(base+$60024,1120);
  lpoke (base+$60018,base+$60410);
  lpoke (base+$60034,base+$60410);
  lpoke (base+$60410,$0000281C);  // upper border 40 lines
  lpoke (base+$60414,$00046000);  // main display 1120 lines @ hi/8bpp
  lpoke (base+$60418,$0000281C);  // lower border 40 lines
  lpoke (base+$6041C,base+$60410+$40000000);  // wait vsync and restart DL
  end
else if mode=17 then
  begin
  end
else if mode=18 then
  begin
  end
else if mode=19 then
  begin
  poke(base+$60008,16);
  poke(base+$60009,8);
  lpoke(base+$60010,0);
  lpoke(base+$60014,0);
  lpoke(base+$60020,nativex);
  lpoke(base+$60024,nativey);
  lpoke (base+$60018,base+$60410);
  lpoke (base+$60034,base+$60410);
  lpoke (base+$60414,(nativey shl 8)+3);      // main display nativey lines @ hi/8bpp
  lpoke (base+$6041C,base+$60410+$40000000);  // wait vsync and restart DL
  end
else if mode=144 then        // double buffered high 8 bit
  begin
  poke(base+$60008,144);
  poke(base+$60009,8);
  lpoke(base+$60010,0);
  lpoke(base+$60014,0);
  lpoke(base+$60020,1792);
  lpoke(base+$60024,1120);

  lpoke (base+$60018,base+$60410);
  lpoke (base+$60034,base+$60410);
  lpoke (base+$60410,$B0800000);  // display start @ 30800000
  lpoke (base+$60414,$0000281C);  // upper border 40 lines
  lpoke (base+$60418,$00046000);  // main display 1120 lines @ hi/8bpp
  lpoke (base+$6041c,$0000281C);  // lower border 40 lines
  lpoke (base+$60420,$B0b00000);  // display start @ 30b00000
  lpoke (base+$60424,base+$60428+$40000000);  // wait vsync and restart DL @ 60428
  lpoke (base+$60428,$0000281C);  // upper border
  lpoke (base+$6042c,$00046000);  // main display 1120 lines @ hi/8bpp
  lpoke (base+$60430,$0000281C);  // lower border 40 lines
  lpoke (base+$60434,$B0800000);  // display start @ 30800000
  lpoke (base+$60438,base+$60414+$40000000);  // wait vsync and restart DL @ 60414
  end
else if mode=147 then          // double buffered native 8bit
  begin
  poke(base+$60008,147);
  poke(base+$60009,8);
  lpoke(base+$60010,0);
  lpoke(base+$60014,0);
  lpoke(base+$60020,nativex);
  lpoke(base+$60024,nativey);
  lpoke (base+$60018,base+$60410);
  lpoke (base+$60034,base+$60410);
  lpoke (base+$60410,$B0800000);  // display start @ 30800000
  lpoke (base+$60414,(nativey shl 8)+3);  // display the screen
  lpoke (base+$60418,$B0b00000);  // display start @ 30a00000
  lpoke (base+$6041c,base+$60420+$40000000);  // wait vsync and restart DL @ 60420
  lpoke (base+$60420,(nativey shl 8)+3);
  lpoke (base+$60424,$B0800000);  // display start @ 30b00000
  lpoke (base+$60428,base+$60414+$40000000);  // wait vsync and restart DL @ 60414
  end
end;

procedure blit(from,x,y,too,x2,y2,length,lines,bpl1,bpl2:integer);

// --- TODO - write in asm, add advanced blitting modes
// --- rev 21070111

var i,j:integer;
    b1,b2:integer;

begin
//if lpeek(base+$60008)<16 then
  begin
  from:=from+x;
  too:=too+x2;
  for i:=0 to lines-1 do
    begin
    b2:=too+bpl2*(i+y2);
    b1:=from+bpl1*(i+y);
    for j:=0 to length-1 do
      poke(b2+j,peek(b1+j));
    end;
  end;
// TODO: use DMA; write for other color depths
end;


procedure setpallette(pallette:TPallette; bank:integer);

var fh:integer;

begin
systempallette[bank]:=pallette;
end;

procedure SetColorEx(c,bank,color:cardinal);

begin
systempallette[bank,c]:=color;
end;

procedure SetColor(c,color:cardinal);

var bank:integer;

begin
bank:=c div 256; c:= c mod 256;
systempallette[bank,c]:=color;
end;

procedure sethidecolor(c,bank,mask:cardinal);

begin
systempallette[bank,c]+=(mask shl 24);
end;

procedure unhidecolor(c,bank:cardinal);

begin
systempallette[bank,c]:=systempallette[bank,c] and $FFFFFF;
end;

procedure cls(c:integer);

// --- rev 20170111

var c2, i,l:integer;
    c3: cardinal;
    screenstart:integer;

begin
c:=c mod 256;
l:=(xres*yres) div 4 ;
c3:=c+(c shl 8) + (c shl 16) + (c shl 24);
for i:=0 to l do lpoke(displaystart+4*i,c3);
end;

//  ---------------------------------------------------------------------
//   putpixel (x,y,color)
//   put color pixel on screen at position (x,y)
//   rev. 20170111
//  ---------------------------------------------------------------------

procedure putpixel(x,y,color:integer); inline;

label p999;

var adr:integer;

begin
if (x<0) or (x>=xres) or (y<0) or (y>yres) then goto p999;
adr:=displaystart+x+xres*y;
poke(adr,color);
p999:
end;


//  ---------------------------------------------------------------------
//   getpixel (x,y)
//   asm procedure - get color pixel on screen at position (x,y)
//   rev. 20170111
//  ---------------------------------------------------------------------

function getpixel(x,y:integer):integer; inline;

var adr:integer;

begin
  if (x<0) or (x>=xres) or (y<0) or (y>yres) then result:=0
else
  begin
  adr:=displaystart+x+xres*y;
  result:=peek(adr);
  end;
end;


//  ---------------------------------------------------------------------
//   box(x,y,l,h,color)
//   asm procedure - draw a filled rectangle, upper left at position (x,y)
//   length l, height h
//   rev. 20170111
//  ---------------------------------------------------------------------


procedure box(x,y,l,h,c:integer);

label p101,p102,p999;

var screenptr:cardinal;
    xr:integer;

begin

screenptr:=displaystart;
xr:=xres;
if x<0 then begin l:=l+x; x:=0; if l<1 then goto p999; end;
if x>=xres then goto p999;
if y<0 then begin h:=h+y; y:=0; if h<1 then goto p999; end;
if y>=yres then goto p999;
if x+l>=xres then l:=xres-x;
if y+h>=yres then h:=yres-y;


             asm
             push {r0-r7}
             ldr r2,y
             ldr r7,xr
             mov r3,r7
             ldr r1,x
             mul r3,r3,r2
             ldr r4,l
             add r3,r1
             ldr r0,screenptr
             add r0,r3
             ldrb r3,c
             ldr r6,h

p102:        mov r5,r4
p101:        strb r3,[r0],#1  // inner loop
             subs r5,#1
             bne p101
             add r0,r7
             sub r0,r4
             subs r6,#1
             bne p102

             pop {r0-r7}
             end;

p999:
end;

procedure box32(x,y,l,h,c:integer);

label p101,p102,p999;

var screenptr:cardinal;

begin
 if c<256 then c:=ataripallette[c];
screenptr:=displaystart;
if x<0 then begin l:=l+x; x:=0; if l<1 then goto p999; end;
if x>=xres then goto p999;
if y<0 then begin h:=h+y; y:=0; if h<1 then goto p999; end;
if y>=yres then goto p999;
if x+l>=xres then l:=xres-x;
if y+h>=yres then h:=yres-y;


             asm
             push {r0-r6}
             ldr r2,y
             mov r3,#1792*4
             ldr r1,x
             mul r3,r3,r2
             lsl r1,#2
             ldr r4,l
             lsl r4,#2
             add r3,r1
             ldr r0,screenptr
             add r0,r3
             ldr r3,c
             ldr r6,h

p102:        mov r5,r4
p101:        str r3,[r0],#4  // inner loop
             subs r5,#4
             bne p101
             add r0,#1792*4
             sub r0,r4
             subs r6,#1
             bne p102

             pop {r0-r6}
             end;

p999:
end;


//  ---------------------------------------------------------------------
//   box2(x1,y1,x2,y2,color)
//   Draw a filled rectangle, upper left at position (x1,y1)
//   lower right at position (x2,y2)
//   wrapper for box procedure
//   rev. 2015.10.17
//  ---------------------------------------------------------------------

procedure box2(x1,y1,x2,y2,color:integer);

begin
if x1>x2 then begin i:=x2; x2:=x1; x1:=i; end;
if y1>y2 then begin i:=y2; y2:=y1; y1:=i; end;
if (x1<>x2) and (y1<>y2) then  box(x1,y1,x2-x1+1, y2-y1+1,color);
end;

procedure box322(x1,y1,x2,y2,color:integer);

begin
if x1>x2 then begin i:=x2; x2:=x1; x1:=i; end;
if y1>y2 then begin i:=y2; y2:=y1; y1:=i; end;
if (x1<>x2) and (y1<>y2) then  box32(x1,y1,x2-x1+1, y2-y1+1,color);
end;


procedure line2(x1,y1,x2,y2,c:integer);

var d,dx,dy,ai,bi,xi,yi,x,y:integer;

begin
x:=x1;
y:=y1;
if (x1<x2) then
  begin
  xi:=1;
  dx:=x2-x1;
  end
else
  begin
   xi:=-1;
   dx:=x1-x2;
  end;
if (y1<y2) then
  begin
  yi:=1;
  dy:=y2-y1;
  end
else
  begin
  yi:=-1;
  dy:=y1-y2;
  end;

putpixel(x,y,c);
if (dx>dy) then
  begin
  ai:=(dy-dx)*2;
  bi:=dy*2;
  d:= bi-dx;
  while (x<>x2) do
    begin
    if (d>=0) then
      begin
      x+=xi;
      y+=yi;
      d+=ai;
      end
    else
      begin
      d+=bi;
      x+=xi;
      end;
    putpixel(x,y,c);
    end;
  end
else
  begin
  ai:=(dx-dy)*2;
  bi:=dx*2;
  d:=bi-dy;
  while (y<>y2) do
    begin
    if (d>=0) then
      begin
      x+=xi;
      y+=yi;
      d+=ai;
      end
    else
      begin
      d+=bi;
      y+=yi;
      end;
    putpixel(x, y,c);
    end;
  end;
end;

procedure line(x,y,dx,dy,c:integer);

begin
line2(x,y,x+dx,y+dy,c);
end;

procedure circle(x0,y0,r,c:integer);

var d,x,y,da,db:integer;

begin
d:=5-4*r;
x:=0;
y:=r;
da:=(-2*r+5)*4;
db:=3*4;
while (x<=y) do
  begin
  putpixel(x0-x,y0-y,c);
  putpixel(x0-x,y0+y,c);
  putpixel(x0+x,y0-y,c);
  putpixel(x0+x,y0+y,c);
  putpixel(x0-y,y0-x,c);
  putpixel(x0-y,y0+x,c);
  putpixel(x0+y,y0-x,c);
  putpixel(x0+y,y0+x,c);
  if d>0 then
    begin
    d+=da;
    y-=1;
    x+=1;
    da+=4*4;
    db+=2*4;
    end
  else
    begin
    d+=db;
    x+=1;
    da+=2*4;
    db+=2*4;
    end;
  end;
end;


procedure fcircle(x0,y0,r,c:integer);

var d,x,y,da,db:integer;

begin
d:=5-4*r;
x:=0;
y:=r;
da:=(-2*r+5)*4;
db:=3*4;
while (x<=y) do
  begin
  line2(x0-x,y0-y,x0+x,y0-y,c);
  line2(x0-x,y0+y,x0+x,y0+y,c);
  line2(x0-y,y0-x,x0+y,y0-x,c);
  line2(x0-y,y0+x,x0+y,y0+x,c);
  if d>0 then
    begin
    d+=da;
    y-=1;
    x+=1;
    da+=4*4;
    db+=2*4;
    end
  else
    begin
    d+=db;
    x+=1;
    da+=2*4;
    db+=2*4;
    end;
  end;
end;


//  ---------------------------------------------------------------------
//   putchar(x,y,ch,color)
//   Draw a 8x16 character at position (x1,y1)
//   STUB, will be replaced by asm procedure
//   rev. 2015.10.14
//  ---------------------------------------------------------------------

procedure putchar(x,y:integer;ch:char;col:integer);

// --- TODO: translate to asm, use system variables
// --- rev 20170111
var i,j,start:integer;
  b:byte;

begin
for i:=0 to 15 do
  begin
  b:=systemfont[ord(ch),i];
  for j:=0 to 7 do
    begin
    if (b and (1 shl j))<>0 then
      putpixel(x+j,y+i,col);
    end;
  end;
end;

procedure putcharz(x,y:integer;ch:char;col,xz,yz:integer);

// --- TODO: translate to asm, use system variables

var i,j,k,l:integer;
  b:byte;

begin
for i:=0 to 15 do
  begin
  b:=systemfont[ord(ch),i];
  for j:=0 to 7 do
    begin
    if (b and (1 shl j))<>0 then
      for k:=0 to yz-1 do
        for l:=0 to xz-1 do
           putpixel(x+j*xz+l,y+i*yz+k,col);
    end;
  end;
end;

procedure outtextxy(x,y:integer; t:string;c:integer);

var i:integer;

begin
for i:=1 to length(t) do putchar(x+8*i-8,y,t[i],c);
end;

procedure outtextxyz(x,y:integer; t:string;c,xz,yz:integer);

var i:integer;

begin
for i:=0 to length(t)-1 do putcharz(x+8*xz*i,y,t[i+1],c,xz,yz);
end;

procedure outtextxys(x,y:integer; t:string;c,s:integer);

var i:integer;

begin
for i:=1 to length(t) do putchar(x+s*i-s,y,t[i],c);
end;

procedure outtextxyzs(x,y:integer; t:string;c,xz,yz,s:integer);

var i:integer;

begin
for i:=0 to length(t)-1 do putcharz(x+s*xz*i,y,t[i+1],c,xz,yz);
end;

procedure scrollup;

var i:integer;

begin
  blit(displaystart,0,32,displaystart,0,0,xres,yres-32,xres,xres);
  box(0,yres-32,xres,32,147);
end;

procedure print(line:string);

var i:integer;

begin
for i:=1 to length(line) do
  begin
  box(16*dpeek(base+$600a0),32*dpeek(base+$600a2),16,32,147);
  putcharz(16*dpeek(base+$600a0),32*dpeek(base+$600a2),line[i],156,2,2);
  dpoke(base+$600a0,dpeek(base+$600a0)+1);
  if dpeek(base+$600a0)>111 then
    begin
    dpoke(base+$600a0,0);
    dpoke(base+$600a2,dpeek(base+$600a2)+1);
    if dpeek(base+$600a2)>34 then
      begin
      scrollup;
      dpoke(base+$600a2,34);
      end;
    end;
  end;
end;

procedure println(line:string);

begin
print(line);
dpoke(base+$600a2,dpeek(base+$600a2)+1);
if dpeek(base+$600a2)>34 then
  begin
  scrollup;
  dpoke(base+$600a2,34);
  end;
end;






end.

