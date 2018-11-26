program Project1;


{$mode objfpc}{$H+}

uses  //Ultibo units
  ProgramInit,
  GlobalConfig,
  GlobalConst,
  GlobalTypes,
  Platform,
  Threads,
  dos,
  Framebuffer,
  BCM2837,
  SysUtils,
  Classes,
  MMC,
  FileSystem,
  FATFS,
  ntfs,
  BCM2710,
  ds1307,
  rtc,
  Ultibo,
  retrokeyboard,
  retromouse,
  DWCOTG,
  retromalina,
  HeapManager,
  icons,
  mwindows,
  blitter;

const ver='Colors v. 0.30 --- 2018.04.30';

var
    hh,mm,ss:integer;

    workdir:string;

    drivetable:array['A'..'Z'] of boolean;
    c:char;
    f:textfile;
    key:integer;

    wheel:integer;
    t:int64;
    testicon, trash, calculator, console,player,status,mandel,textedit,raspbian,synth,cameratest,basictest:TIcon;
    oneicon:TIcon ;
    fh,i,j,k:integer;
    message:TWindow;
    scr:cardinal;
    testbutton:TButton;
    clock:string;
    testptr:pointer;
    ii:cardinal;
//------------------- The main program

begin




initmachine(144);     // 16+128=hi, double buffered TODO init @19
threadsleep(1);



while not DirectoryExists('C:\') do
  begin
  Sleep(100);
  end;

if fileexists('C:\kernel7.img') then begin workdir:='C:\colors\'; drive:='C:\'; end
else if fileexists('D:\kernel7.img') then begin workdir:='D:\colors\' ; drive:='D:\'; end
else if fileexists('E:\kernel7.img') then begin workdir:='E:\colors\' ; drive:='E:\'; end
else if fileexists('F:\kernel7.img') then begin workdir:='F:\colors\' ; drive:='F:\'; end
else
  begin
  outtextxyz(440,1060,'Error. No Ultibo folder found. Press Enter to reboot',157,2,2);
  repeat until readkey=$141;
  systemrestart(0);
  end;

t:=SysRTCGetTime;
// box(0,0,100,100,0); outtextxy(0,0,inttostr(t),15); sleep(100000);
if t=0 then
  if fileexists(drive+'now.txt') then
    begin
    assignfile(f,drive+'now.txt');
    reset(f);
    read(f,hh); read(f,mm); read(f,ss);
    closefile(f);
    settime(hh,mm,ss,0);
    end;

//scr:=mainscreen+$300000;
//fh:=fileopen(drive+'Colors\Wallpapers\rpi-logo.rbm',$40);
//fileread(fh,pointer(scr)^,235*300);
//for i:=0 to 299 do
//  for j:=0 to 234 do
//    if (peek(scr+j+i*235)>15) or (peek(scr+j+i*235)<5) then poke (mainscreen+xres*(i+(yres div 2)-150)+j+(xres div 2) - 117,peek(scr+j+i*235));
for c:='C' to 'F' do drivetable[c]:=directoryexists(c+':\');



songtime:=0;
siddelay:=20000;
ThreadSetCPU(ThreadGetCurrent,CPU_ID_0);
threadsleep(1);
startreportbuffer;
startmousereportbuffer;
//testicon:=TIcon.create('Drive C',background);
//testicon.icon48:=i48_hdd;
//testicon.x:=0; testicon.y:=192; testicon.size:=48; testicon.l:=128; testicon.h:=96; testicon.draw;
//trash:=testicon.append('Trash');
//trash.icon48:=i48_trash;
//trash.x:=0; trash.y:=960; trash.size:=48; trash.l:=128; trash.h:=96; trash.draw;
//calculator:=Testicon.append('Calculator');
//calculator.icon48:=i48_calculator;
//calculator.x:=256; calculator.y:=0; calculator.size:=48; calculator.l:=128; calculator.h:=96; calculator.draw;
//console:=Testicon.append('Console');
//console.icon48:=i48_terminal;
//console.x:=384; console.y:=0; console.size:=48; console.l:=128; console.h:=96; console.draw;
//player:=Testicon.append('RetAMP Player');
///player.icon48:=i48_player;
//player.x:=512; player.y:=0; player.size:=48; player.l:=128; player.h:=96; player.draw;
//status:=Testicon.append('System status');
//status.icon48:=i48_sysinfo;
//status.x:=640; status.y:=0; status.size:=48; status.l:=128; status.h:=96; status.draw;
//mandel:=Testicon.append('Mandelbrot');
//mandel.icon48:=i48_mandelbrot;
//mandel.x:=768; mandel.y:=0; mandel.size:=48; mandel.l:=128; mandel.h:=96; mandel.draw;
//textedit:=Testicon.append('Text editor');
//textedit.icon48:=i48_textedit;
//textedit.x:=896; textedit.y:=0; textedit.size:=48; textedit.l:=128; textedit.h:=96; textedit.draw;
//raspbian:=Testicon.append('Raspbian');
//raspbian.icon48:=i48_raspi;
//raspbian.x:=256; raspbian.y:=96; raspbian.size:=48; raspbian.l:=128; raspbian.h:=96; raspbian.draw;
//synth:=Testicon.append('FM Synthesizer');
//synth.icon48:=i48_note;
//synth.x:=384; synth.y:=96; synth.size:=48; synth.l:=128; synth.h:=96; synth.draw;
//cameratest:=Testicon.append('Camera test');
//cameratest.icon48:=i48_camera;
//cameratest.x:=512; cameratest.y:=96; cameratest.size:=48; cameratest.l:=128; cameratest.h:=96; cameratest.draw;
//basictest:=Testicon.append('BASIC');
//basictest.icon48:=i48_basic;
//basictest.x:=640; basictest.y:=96; basictest.size:=48; basictest.l:=128; basictest.h:=96; basictest.draw;

filetype:=-1;
//testbutton:=Tbutton.create(2,2,100,22,8,15,'Start',panel);

//outtextxyz(500,500,inttostr(cardinal(retropointer)),42,4,4);
//------------------- The main loop




// todo:
// icons from ini file
// thread assigned to icon
//key:=0;

// remapping test

testptr:=getalignedmem  (1000000,MEMORY_PAGE_SIZE);
t:=gettime;
//tt:=remapram(cardinal(testptr),$80000000,1000000);
//t:=gettime-t;
//poke($80001234,123);
//if peek($80001234)=123 then
//  begin box(0,0,100,100,0);
//  outtextxy(0,0,'remap test ok',15);
//  outtextxy(0,20,'1 MB remapped in '+inttostr(t)+' us',15);
//  outtextxy(0,40,inttostr(tt),15);
//remapram(cardinal(testptr),cardinal(testptr),1000000);
//freemem(testptr);

//end;

repeat


//  background.icons.checkall;

//  if testicon.dblclicked then
//    begin
//    testicon.dblclicked:=false;
//    end;



  if {(raspbian.dblclicked) or} (key=ord('r')) then
    begin
//    raspbian.dblclicked:=false;
    if fileexists(drive+'\ultibo\Raspbian.u') then
      begin
 //     pauseaudio(1);
//      message:=twindow.create(500,112,'');
//      message.cls(0);
//      message.outtextxyz(16,16,'Preparing reboot to Raspbian',250,2,2);
//      message.outtextxyz(16,64,'Please wait...',250,2,2);
//      message.move(xres div 2 - 250, yres div 2 - 56, 600,200,0,0);
//      message.select;
      if not fileexists(drive+'kernel7_c.img') then RenameFile(drive+'kernel7.img',drive+'kernel7_c.img') else deletefile(pchar(drive+'kernel7.img'));
      RenameFile(drive+'kernel7_l.img',drive+'kernel7.img');
      systemrestart(0);
      end;
    end;

  waitvbl;
//  panel.box(panel.l-68,4,64,16,11);
//  clock:=timetostr(now);
//  panel.outtextxy(panel.l-68,4,clock,0);
  key:=getkey and $FF;

// if key=ord('s') then   // script test
//  begin
//  script1;
//  readkey;
//  end;


  until key=key_escape;
//pauseaudio(1);
if sfh>0 then fileclose(sfh);
stopmachine;
systemrestart(0);
end.

