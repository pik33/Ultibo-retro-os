unit sid;

//-----------------------------------------------------------------------------
//
//  SID chip emulator
//
//-----------------------------------------------------------------------------

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type TSample=array[0..1] of smallint;
     TSample32=array[0..1] of integer;

var
i:integer;

times6502:array[0..15] of integer;
attacktable:array[0..15] of double=(5.208e-4,1.302e-4,6.51e-5,4.34e-5,2.74e-5,1.86e-5,1.53e-5,1.3e-5,1.04e-5,4.17e-6,2.08e-6,1.302e-6,1.04e-6,3.47e-7,2.08e-7,1.3e-7);
attacktablei:array[0..15] of int64;
srtablei:array[0..15] of int64;
sidcount:integer=1;
sampleclock:integer=0;
sidclock:integer=0;
siddata:array[0..1151] of integer;

channel1on:byte=1;
channel2on:byte=1;
channel3on:byte=1;

function sid(mode:integer):tsample;

implementation

uses retromalina, retro;





  function sid(mode:integer):tsample;

  //  SID frequency 985248 Hz

  label p101,p102,p103,p104,p105,p106,p107;
  label p111,p112,p113,p114,p115,p116,p117;
  label p121,p122,p123,p124,p125,p126,p127;
  label p201,p202,p203,p204,p205,p206,p207,p208,p209;
  label p211,p212,p213,p214,p215,p216,p217,p218,p219;
  label p221,p222,p223,p224,p225,p226,p227,p228,p229,p297,p298,p299;
  const
        waveform1:word=0;
        f1:boolean=false;
        waveform2:word=0;
        f2:boolean=false;
        waveform3:word=0;
        f3:boolean=false;
        ff:integer=0;
        filter_resonance2i:integer=0;
        filter_freqi:integer=0;
        volume:integer=0;
        c3off:integer=0;
        fl:integer=0;

  // siddata table:

  // 00..0f chn 1
  // 10..1f chn 2
  // 20..2f chn3
  // 0 - freq; 1 - gate; 2 - ring; 3 - test;
  // 4 - sync; 5 - decay 6 - attack; 7 - release
  // 8 - PA; 9 - noise PA; a - output value; b - ADSR state
  // c - ADSR volume; d - susstain value; e - noise generator f - noise trigger

  // 30..3f release table
  // 40..4f attack table

  // 60..70 filters and mixer:

  // 60 filter1 BP, 61 filter1 LP
  // 62 filter2 BP  63 filter2 LP
  // 64 filter3 BP  65 filter3 LP
  // 66..67 antialias left BP, LP
  // 68..69 antialias right BP, LP
  // 6A - inner loop counter
  // 6B..6C - SID outputs
  // 6D - filter outputs selector
  // 6E - filter frequency
  // 6F - filter resonance
  // 70 - volume
  // 50,51,52: waveforms
  // 53,54,55: pulse width
  // 56,57,58: channel on/off
  // 59,5a,5b: filter select
  // 5c,5d,5e: channel value for filter
  // 71,72,73 orig channel value for filter
  // 53..5F free
  // 74..7F free


  var i,sid1,sid1l,ind:integer;
      ttt:int64;
      pp1,pp2,pp3:byte;
      wv1ii,wv2ii,wv3ii:int64;
      wv1iii,wv2iii,wv3iii:integer;
      fii,fi2i,fi3i:integer;
      fri,ffi:integer;
      pa1i:integer;
      pa2i:integer;
      pa3i:integer;
      vol, fll:integer;
      sidptr:pointer;


  begin
  sidptr:=@siddata;
  if mode=1 then  // get regs

    begin
    siddata[$56]:=channel1on;
    siddata[$57]:=channel2on;
    siddata[$58]:=channel3on;
    siddata[0]:=round(1.0246*(16*peek(base+$D400)+4096*peek(base+$d401))); //freq1
    siddata[$10]:=round(1.0246*(16*peek(base+$d407)+4096*peek(base+$d408)));
    siddata[$20]:=round(1.0246*(16*peek(base+$d40e)+4096*peek(base+$d40f)));
    siddata[1]:=peek(base+$d404) and 1;  // gate1
    siddata[2]:=peek(base+$d404) and 4;  // ring1
    siddata[3]:=peek(base+$d404) and 8;  // test1
    siddata[4]:=((peek(base+$d404) and 2) shr 1)-1; //sync1

    siddata[5]:=peek(base+$d405) and $F;   //sd1,
    siddata[6]:=peek(base+$d405) shr 4;    //sa1,
    siddata[7]:=peek(base+$d406) and $F;    //sr1
    siddata[$0d]:=(peek(base+$d406) and $F0) shl 22;      //0d,sussvol1
    siddata[$53]:=((peek(base+$d402)+256*peek(base+$d403)) and $FFF);

    siddata[$11]:=peek(base+$d40b) and 1;
    siddata[$12]:=peek(base+$d40b) and 4;
    siddata[$13]:=peek(base+$d40b) and 8;
    siddata[$14]:=((peek(base+$d40b) and 2) shr 1)-1;
    siddata[$15]:=peek(base+$d40c) and  $F;
    siddata[$16]:=peek(base+$d40c) shr 4;
    siddata[$17]:=peek(base+$d40d)and $F;
    siddata[$1d]:=(peek(base+$d40d) and $F0) shl 22;
    siddata[$54]:=((peek(base+$d409)+256*peek(base+$d40a)) and $FFF);

    siddata[$21]:=peek(base+$d412) and 1;
    siddata[$22]:=peek(base+$d412) and 4;
    siddata[$23]:=peek(base+$d412) and 8;
    siddata[$24]:=((peek(base+$d412) and 2) shr 1)-1;
    siddata[$25]:=peek(base+$d413) and  $F;
    siddata[$26]:=peek(base+$d413) shr 4;
    siddata[$27]:=peek(base+$d414)and $F;
    siddata[$2d]:=(peek(base+$d414) and $F0) shl 22;
    siddata[$55]:=((peek(base+$d410)+256*peek(base+$d411)) and $FFF);

  // original filter_freq:=((ff * 5.8) + 30)/240000;
  // instead: ff*6 div 262144

    ff:=(peek(base+$d416) shl 3)+(peek(base+$d415) and 7);
    siddata[$6E]:=(ff shl 1)+(ff shl 2)+32;

    siddata[$59]:=(peek(base+$d417) and 1); //filter 1
    siddata[$5a]:=(peek(base+$d417) and 2);
    siddata[$5B]:=(peek(base+$d417) and 4);
    siddata[$6D]:=(peek(base+$d418) and $70) shr 4;   // filter output switch

  // original filter_resonance2:=0.5+(0.5/(1+(peek($d416) shr 4)));

    siddata[$6F]:=round(65536.0*(0.5+(0.5/(1+(peek(base+$d416) shr 4)))));

    siddata[$70]:=(peek(base+$d418) and 15); //volume

    siddata[$50]:=peek(base+$d404) shr 4;
    siddata[$51]:=peek(base+$d40b) shr 4;
    siddata[$52]:=peek(base+$d412) shr 4;     //waveforms
    end;

                 asm

  // adsr module

                 stmfd r13!,{r0-r12}

                 ldr   r7, sidptr
                 mov   r0,#0
                 str   r0,[r7,#0x1a8] //inner loop counter
                 str   r0,[r7,#0x1ac] //output
                 str   r0,[r7,#0x1b0] //output

                 ldr   r6,[r7,#4]
                 cmp   r6,#0
                 beq   p101
                 ldr   r0,[r7,#0x2C]
                 mov   r1,r0
                 cmp   r1,#0
                 moveq r0,#1
                 cmp   r1,#4
                 moveq r0,#1
                 b     p102

  p101:          mov   r0,#4
  p102:          str   r0,[r7,#0x2C]

                 ldr   r0,[r7,#0x2C]
                 cmp   r0,#3
                 ldreq   r1,[r7,#0x34]
                 streq   r1,[r7,#0x30]
                 beq     p103

  p107:          cmp   r0,#1
                 bne   p104
                 ldr   r1,[r7,#0x30] //adsrvol1
                 ldr   r2,[r7,#0x18] //sa1
                 add   r2,#0x40
                 ldr   r6,[r7,r2,lsl #2]
                 add   r1,r6
                 str   r1,[r7,#0x30]
                 cmp   r1,#1073741824
                 blt   p103
                 mov   r0,#2
                 str   r0,[r7,#0x2c]
                 b     p103

  p104:          cmp   r0,#2
                 bne   p105
                 ldr   r1,[r7,#0x30]
                 ldr   r2,[r7,#0x14] //sd1
                 add   r2,#0x30
                 ldr   r3,[r7,r2,lsl #2]
                 umull r4,r5,r1,r3
                 lsr   r4,#30
                 orr   r4,r4,r5,lsl #2
                 str   r4,[r7,#0x30]
                 ldr   r1,[r7,#0x34]
                 cmp   r4,r1
                 movlt r0,#3
                 strlt r0,[r7,#0x2c]
                 b     p103

  p105:          cmp   r0,#4
                 bne   p106
                 ldr   r1,[r7,#0x30]
                 ldr   r2,[r7,#0x1c] //sr1
                 add   r2,#0x30
                 ldr   r3,[r7,r2,lsl #2]
                 umull r4,r5,r1,r3
                 lsr   r4,#30
                 orr   r4,r4,r5,lsl #2
                 cmp   r4,#0x10000
                 movlt r4,#0
                 str   r4,[r7,#0x30]
                 strlt r4,[r7,#0x2c]
                 b     p103

  p106:          mov   r0,#0
                 str   r0,[r7,#0x30]

                 //chn2

  p103:          ldr   r6,[r7,#0x44]
                 cmp   r6,#0
                 beq   p111
                 ldr   r0,[r7,#0x6C]
                 mov   r1,r0
                 cmp   r1,#0
                 moveq r0,#1
                 cmp   r1,#4
                 moveq r0,#1
                 b     p112

  p111:          mov   r0,#4
  p112:          str   r0,[r7,#0x6C]

                 ldr   r0,[r7,#0x6C]
                 cmp   r0,#3
                 ldreq   r1,[r7,#0x74]
                 streq   r1,[r7,#0x70]
                 beq     p113

  p117:          cmp   r0,#1
                 bne   p114
                 ldr   r1,[r7,#0x70] //adsrvol1
                 ldr   r2,[r7,#0x58] //sa1
                 add   r2,#0x40
                 ldr   r6,[r7,r2,lsl #2]
                 add   r1,r6
                 str   r1,[r7,#0x70]
                 cmp   r1,#1073741824
                 blt   p113
                 mov   r0,#2
                 str   r0,[r7,#0x6c]
                 b     p113

  p114:          cmp   r0,#2
                 bne   p115
                 ldr   r1,[r7,#0x70]
                 ldr   r2,[r7,#0x54] //sd1
                 add   r2,#0x30
                 ldr   r3,[r7,r2,lsl #2]
                 umull r4,r5,r1,r3
                 lsr   r4,#30
                 orr   r4,r4,r5,lsl #2
                 str   r4,[r7,#0x70]
                 ldr   r1,[r7,#0x74]
                 cmp   r4,r1
                 movlt r0,#3
                 strlt r0,[r7,#0x6c]
                 b     p113

  p115:          cmp   r0,#4
                 bne   p116
                 ldr   r1,[r7,#0x70]
                 ldr   r2,[r7,#0x5c] //sr1
                 add   r2,#0x30
                 ldr   r3,[r7,r2,lsl #2]
                 umull r4,r5,r1,r3
                 lsr   r4,#30
                 orr   r4,r4,r5,lsl #2
                 cmp   r4,#0x10000
                 movlt r4,#0
                 str   r4,[r7,#0x70]
                 strlt r4,[r7,#0x6c]
                 b     p113

  p116:          mov   r0,#0
                 str   r0,[r7,#0x70]

                 //chn 3

  p113:          ldr   r6,[r7,#0x84]
                 cmp   r6,#0
                 beq   p121
                 ldr   r0,[r7,#0xaC]
                 mov   r1,r0
                 cmp   r1,#0
                 moveq r0,#1
                 cmp   r1,#4
                 moveq r0,#1
                 b     p122

  p121:          mov   r0,#4
  p122:          str   r0,[r7,#0xaC]

                 ldr   r0,[r7,#0xaC]
                 cmp   r0,#3
                 ldreq   r1,[r7,#0xb4]
                 streq   r1,[r7,#0xb0]
                 beq     p123

  p127:          cmp   r0,#1
                 bne   p124
                 ldr   r1,[r7,#0xb0] //adsrvol1
                 ldr   r2,[r7,#0x98] //sa1
                 add   r2,#0x40
                 ldr   r6,[r7,r2,lsl #2]
                 add   r1,r6
                 str   r1,[r7,#0xb0]
                 cmp   r1,#1073741824
                 blt   p123
                 mov   r0,#2
                 str   r0,[r7,#0xac]
                 b     p123

  p124:          cmp   r0,#2
                 bne   p125
                 ldr   r1,[r7,#0xb0]
                 ldr   r2,[r7,#0x94] //sd1
                 add   r2,#0x30
                 ldr   r3,[r7,r2,lsl #2]
                 umull r4,r5,r1,r3
                 lsr   r4,#30
                 orr   r4,r4,r5,lsl #2
                 str   r4,[r7,#0xb0]
                 ldr   r1,[r7,#0xb4]
                 cmp   r4,r1
                 movlt r0,#3
                 strlt r0,[r7,#0xac]
                 b     p123

  p125:          cmp   r0,#4
                 bne   p126
                 ldr   r1,[r7,#0xb0]
                 ldr   r2,[r7,#0x9c] //sr1
                 add   r2,#0x30
                 ldr   r3,[r7,r2,lsl #2]
                 umull r4,r5,r1,r3
                 lsr   r4,#30
                 orr   r4,r4,r5,lsl #2
                 cmp   r4,#0x10000
                 movlt r4,#0
                 str   r4,[r7,#0xb0]
                 strlt r4,[r7,#0xbc]
                 b     p123

  p126:          mov   r0,#0
                 str   r0,[r7,#0xb0]

  p123:          mov   r0,#1 // 10
                 str   r0,[r7,#0x1fc]




   p297:        ldr   r4,sidptr

                 // phase accum 1

               ldr   r0,[r4,#0x20]
                 ldr   r3,[r4,#0x00]
                 adds  r0,r0,r3,lsl #4//8    // PA @ 24 higher bits
                 ldrcs r1,[r4,#0x60]
                 ldrcs r2,[r4,#0x50]
                 andcs r1,r2
                 strcs r1,[r4,#0x60]
                 ldr   r1,[r4,#0x0c]
                 cmp   r1,#0
                 movne r0,#0
                 str r0,[r4,#0x20]

                 ldr r2,[r4,#0x24]
                 adds r2,r2,r3,lsl #8//12
                 movcs r1,#1
                 movcc r1,#0
                 str   r2,[r4,#0x24]
                 str   r1,[r4,#0x3c]

                                          // waveform 1

                 ldr r1,[r4,#0x140]
                 cmp r1,#2
                 bne p205
                 lsr r0,#8
                 sub r0,#8388608
                 str r0,[r4,#0x28]
                 b p204

  p205:          cmp r1,#1
                 bne p201
                 mov r5,r0                // triangle
                 lsls r5,#1
                 mvncs r5,r5
                 ldr r6,[r4,#0x08]
                 cmp r6,#0
                 ldrne r6,[r4,#0xa0]
                 lsls r6,#1
                 negcs r5,r5
                 lsr r5,#8
                 sub r5,#8388608
                 str r5,[r4,#0x28]
                 b p204

  p201:          cmp r1,#4
                 bne p203
                 mov r6,r0,lsr #20        //square r6
                 ldr r7,[r4,#0x14c]
                 cmp r6,r7
                 movge r6,#0xFFFFFF
                 movlt r6,#0
                 sub r6,#8388608
                 str r6,[r4,#0x28]
                 b p204

  p203:          cmp r1,#3
                 bne p206
                 mov r6,r0,lsr #22
                 and r6,#0x000003FC
                 add r6,#0x200
                 ldr r8,[r4,r6]
                 str r8,[r4,#0x28]
                 b p204

  p206:          cmp r1,#5
                 bne p207
                 mov r6,r0,lsr #22
                 and r6,#0x000003FC
                 add r6,#0x600
                 ldr r8,[r4,r6]
                 str r8,[r4,#0x28]
                 b p204

  p207:          cmp r1,#6
                 bne p208
                 mov r6,r0,lsr #22
                 and r6,#0x000003FC
                 add r6,#0xa00
                 ldr r8,[r4,r6]
                 str r8,[r4,#0x28]
                 b p204

  p208:          cmp r1,#7
                 bne p209
                 mov r6,r0,lsr #22
                 and r6,#0x000003FC
                 add r6,#0xe00
                 ldr r8,[r4,r6]
                 str r8,[r4,#0x28]
                 b p204

  p209:          cmp r1,#8                // noise
                 bne p204
                 ldr r7,[r4,#0x3C]
                 cmp r7,#1
                 bne p204

                 mov   r7,#0
                 mov   r2,#0
                 mov   r3,#0
                 ldr   r0,[r4,#0x38]
                 tst   r0,#4194304
                 orrne r7,#128
                 orrne r2,#1
                 tst   r0,#1048576
                 orrne r7,#64
                 tst   r0,#65536
                 orrne r7,#32
                 tst   r0,#8192
                 orrne r7,#16
                 tst   r0,#2048
                 orrne r7,#8
                 tst   r0,#128
                 orrne r7,#4
                 tst   r0,#16
                 orrne r7,#2
                 tst   r0,#4
                 orrne r7,#1
                 tst   r0,#131072
                 orrne r3,#1
                 eor   r2,r3
                 orr   r2,r2,r0,lsl #1
                 str   r2,[r4,#0x38]
                 sub   r7,#128
                 lsl   r7,#16
                 str   r7,[r4,#0x28]

                    // phase accum 2

  p204:          ldr   r0,[r4,#0x60]
                 ldr   r3,[r4,#0x40]
                 adds  r0,r0,r3,lsl #4//8    // PA @ 24 higher bits
                 ldrcs r1,[r4,#0xa0]
                 ldrcs r2,[r4,#0x90]
                 andcs r1,r2
                 strcs r1,[r4,#0xa0]
                 ldr   r1,[r4,#0x4c]
                 cmp   r1,#0
                 movne r0,#0
                 str r0,[r4,#0x60]

                 ldr r2, [r4,#0x64]
                 adds r2,r2,r3,lsl #8//12
                 movcs r1,#1
                 movcc r1,#0
                 str  r2,[r4,#0x64]
                 str  r1,[r4,#0x7c]


  // waveform 2

                 ldr r1,[r4,#0x144]
                 cmp r1,#2
                 bne p215
                 lsr r0,#8
                 sub r0,#8388608
                 str r0,[r4,#0x68]
                 b p214

  p215:          cmp r1,#1
                 bne p211
                 mov r5,r0             // triangle
                 lsls r5,#1
                 mvncs r5,r5
                 lsr r5,#8
                 sub r5,#8388608
                 ldr r6,[r4,#0x48]
                 cmp r6,#0
                 ldrne r6,[r4,#0x20]
                 lsls r6,#1
                 negcs r5,r5
                 str r5,[r4,#0x68]
                 b p214

  p211:          cmp r1,#4
                 bne p213
                 mov r6,r0,lsr #20     //square r6
                 ldr r7,[r4,#0x150]
                 cmp r6,r7
                 movge r6,#0xFFFFFF
                 movlt r6,#0
                 sub r6,#8388608
                 str r6,[r4,#0x68]
                 b p214

  p213:          cmp r1,#3
                 bne p216
                 mov r6,r0,lsr #22
                 and r6,#0x000003FC
                 add r6,#0x200
                 ldr r8,[r4,r6]
                 str r8,[r4,#0x68]
                 b p214

  p216:          cmp r1,#5
                 bne p217
                 mov r6,r0,lsr #22
                 and r6,#0x000003FC
                 add r6,#0x600
                 ldr r8,[r4,r6]
                 str r8,[r4,#0x68]
                 b p214

  p217:          cmp r1,#6
                 bne p218
                 mov r6,r0,lsr #22
                 and r6,#0x000003FC
                 add r6,#0xa00
                 ldr r8,[r4,r6]
                 str r8,[r4,#0x68]
                 b p214

  p218:          cmp r1,#7
                 bne p219
                 mov r6,r0,lsr #22
                 and r6,#0x000003FC
                 add r6,#0xe00
                 ldr r8,[r4,r6]
                 str r8,[r4,#0x68]
                 b p214

  p219:          cmp r1,#8    // noise
                 bne p214
  p212:          ldr r7,[r4,#0x7C]
                 cmp r7,#1
                 bne p214

                 mov   r7,#0
                 mov   r2,#0
                 mov   r3,#0
                 ldr   r0,[r4,#0x78]
                 tst   r0,#4194304
                 orrne r7,#128
                 orrne r2,#1
                 tst   r0,#1048576
                 orrne r7,#64
                 tst   r0,#65536
                 orrne r7,#32
                 tst   r0,#8192
                 orrne r7,#16
                 tst   r0,#2048
                 orrne r7,#8
                 tst   r0,#128
                 orrne r7,#4
                 tst   r0,#16
                 orrne r7,#2
                 tst   r0,#4
                 orrne r7,#1
                 tst   r0,#131072
                 orrne r3,#1
                 eor   r2,r3
                 orr   r2,r2,r0,lsl #1
                 str   r2,[r4,#0x78]
                 lsl   r7,#16
                 sub   r7,#8388608
                 str   r7,[r4,#0x68]


               // phase accum 3

  p214:          ldr   r0,[r4,#0xa0]
                 ldr   r3,[r4,#0x80]
                 adds  r0,r0,r3,lsl #4//8    // PA @ 24 higher bits
                 ldrcs r1,[r4,#0x20]
                 ldrcs r2,[r4,#0x10]
                 andcs r1,r2
                 strcs r1,[r4,#0x20]
                 ldr   r1,[r4,#0x8c]
                 cmp   r1,#0
                 movne r0,#0
                 str r0,[r4,#0xa0]

                 ldr r2,[r4,#0xa4]
                 adds r2,r2,r3,lsl #8//12
                 movcs r1,#1
                 movcc r1,#0
                 str   r2,[r4,#0xa4]
                 str   r1,[r4,#0xbc]


  // waveform 3

                 ldr r1,[r4,#0x148]
                 cmp r1,#2
                 bne p225
                 lsr r0,#8
                 sub r0,#8388608
                 str r0,[r4,#0xa8]
                 b p224

  p225:          cmp r1,#1
                 bne p221
                 mov r5,r0             // triangle
                 lsls r5,#1
                 mvncs r5,r5
                 ldr r6,[r4,#0x88]
                 cmp r6,#0
                 ldrne r6,[r4,#0x60]
                 lsls r6,#1
                 negcs r5,r5
                 lsr r5,#8
                 sub r5,#8388608
                 str r5,[r4,#0xa8]
                 b p224

  p221:          cmp r1,#4
                 bne p223
                 mov r6,r0,lsr #20     //square r6
                 ldr r7,[r4,#0x154]
                 cmp r6,r7
                 movge r6,#0xFFFFFF
                 movlt r6,#0
                 sub r6,#8388608
                 str r6,[r4,#0xa8]
                 b p224

  p223:          cmp r1,#3
                 bne p226
                 mov r6,r0,lsr #22
                 and r6,#0x000003FC
                 add r6,#0x200
                 ldr r8,[r4,r6]
                 str r8,[r4,#0xa8]
                 b p224

  p226:          cmp r1,#5
                 bne p227
                 mov r6,r0,lsr #22
                 and r6,#0x000003FC
                 add r6,#0x600
                 ldr r8,[r4,r6]
                 str r8,[r4,#0xa8]
                 b p224

  p227:          cmp r1,#6
                 bne p228
                 mov r6,r0,lsr #22
                 and r6,#0x000003FC
                 add r6,#0xa00
                 ldr r8,[r4,r6]
                 str r8,[r4,#0xa8]
                 b p224

  p228:          cmp r1,#7
                 bne p229
                 mov r6,r0,lsr #22
                 and r6,#0x000003FC
                 add r6,#0xe00
                 ldr r8,[r4,r6]
                 str r8,[r4,#0xa8]
                 b p224

  p229:          cmp r1,#8    // noise
                 bne p224
                 ldr r7,[r4,#0xbC]
                 cmp r7,#1
                 bne p224

                 mov   r7,#0
                 mov   r2,#0
                 mov   r3,#0
                 ldr   r0,[r4,#0xb8]
                 tst   r0,#4194304
                 orrne r7,#128
                 orrne r2,#1
                 tst   r0,#1048576
                 orrne r7,#64
                 tst   r0,#65536
                 orrne r7,#32
                 tst   r0,#8192
                 orrne r7,#16
                 tst   r0,#2048
                 orrne r7,#8
                 tst   r0,#128
                 orrne r7,#4
                 tst   r0,#16
                 orrne r7,#2
                 tst   r0,#4
                 orrne r7,#1
                 tst   r0,#131072
                 orrne r3,#1
                 eor   r2,r3
                 orr   r2,r2,r0,lsl #1
                 str   r2,[r4,#0xb8]
                 sub   r7,#128
                 lsl   r7,#16
  p222:          str   r7,[r4,#0xa8]

                 // ADSR multiplier and channel switches

  p224:          ldr r0,[r4,#0x30]
                 ldr r1,[r4,#0x28]
                 smull r2,r3,r0,r1
                 ldr r0,[r4,#0x158]
                 cmp r0,#0
                 moveq r3,#0
                 asr r3,#1
                 ldr r0,[r4,#0x164]
                 cmp r0,#0
                 moveq r2,#0
                 movne r2,r3
                 movne r3,#0
                 str r3,[r4,#0x1c4]
                 str r2,[r4,#0x170]


                 ldr r0,[r4,#0x70]
                 ldr r1,[r4,#0x68]
                 smull r2,r3,r0,r1
                 ldr r0,[r4,#0x15c]
                 cmp r0,#0
                 moveq r3,#0
                 asr r3,#1
                 ldr r0,[r4,#0x168]
                 cmp r0,#0
                 moveq r2,#0
                 movne r2,r3
                 movne r3,#0
                 str r3,[r4,#0x1c8]
                 str r2,[r4,#0x174]

                 ldr r0,[r4,#0xb0]
                 ldr r1,[r4,#0xa8]
                 smull r2,r3,r0,r1
                 ldr r0,[r4,#0x160]
                 cmp r0,#0
                 moveq r3,#0
                 asr r3,#1
                 ldr r0,[r4,#0x16c]
                 cmp r0,#0
                 moveq r2,#0
                 movne r2,r3
                 movne r3,#0
                 str r3,[r4,#0x1cc]
                 str r2,[r4,#0x178]

  // filters

                 mov r7,r4
                 ldr r3,[r7,#0x1bc] //fri
                 ldr r1,[r7,#0x1b8] //ffi
   //lsl r1,#1
                 ldr r6,[r7,#0x1b4]  // bandpass switch
                 mov r9, #0  // init output L
                 mov r10,#0  // init output R

                 // filter chn 0

                 ldr r2,[r7,#0x180]
                 smull r5,r12,r2,r3
                 lsr r5,#16
                 orr r5,r5,r12,lsl #16
                 ldr r0,[r7,#0x170]
                 sub r0,r5
                 ldr r4,[r7,#0x184]
                 sub r0,r4
                 smull r5,r12,r0,r1
                 lsr r5,#18
                 orr r5,r5,r12,lsl #14
                 add r2,r5
                 str r2,[r7,#0x180]
                 smull r5,r12,r1,r2
                 lsr r5,#18
                 orr r5,r5,r12,lsl #14
                 add r4,r5
                 str r4,[r7,#0x184]

                 // select filter output

                 ldr r5,[r7,#0x1c4]
                 tst r6,#0x2
                 addne r5,r2
                 tst r6,#0x1
                 addne r5,r4
                 tst r6,#0x4
                 addne r5,r0

                 // mix channel 0

                 mov r9,r5
                 asr r5,#1
                 mov r10,r5

                 //filter chn 1

                 ldr r2,[r7,#0x188]
                 smull r5,r12,r2,r3
                 lsr r5,#16
                 orr r5,r5,r12,lsl #16
                 ldr r0,[r7,#0x174]
                 sub r0,r5
                 ldr r4,[r7,#0x18c]
                 sub r0,r4
                 smull r5,r12,r0,r1
                 lsr r5,#18
                 orr r5,r5,r12,lsl #14
                 add r2,r5
                 str r2,[r7,#0x188]
                 smull r5,r12,r1,r2
                 lsr r5,#18
                 orr r5,r5,r12,lsl #14
                 add r4,r5
                 str r4,[r7,#0x18c]

                 // select filter output chn 1

                 ldr r5,[r7,#0x1c8]
                 tst r6,#0x2
                 addne r5,r2
                 tst r6,#0x1
                 addne r5,r4
                 tst r6,#0x4
                 addne r5,r0

                 // mix channel 1

                 asr r5,#1
                 add r9,r5
                 add r10,r5
                 asr r5,#1
                 add r9,r5
                 add r10,r5

                 //filter chn2

                 ldr r2,[r7,#0x190]
                 smull r5,r12,r2,r3
                 lsr r5,#16
                 orr r5,r5,r12,lsl #16
                 ldr r0,[r7,#0x178]
                 sub r0,r5
                 ldr r4,[r7,#0x194]
                 sub r0,r4
                 smull r5,r12,r0,r1
                 lsr r5,#18
                 orr r5,r5,r12,lsl #14
                 add r2,r5
                 str r2,[r7,#0x190]
                 smull r5,r12,r1,r2
                 lsr r5,#18
                 orr r5,r5, r12,lsl #14
                 add r4,r5
                 str r4,[r7,#0x194]

                 // select filter output chn 2

                 ldr r5,[r7,#0x1cc]
                 tst r6,#0x2
                 addne r5,r2
                 tst r6,#0x1
                 addne r5,r4
                 tst r6,#0x4
                 addne r5,r0

                 // mix channel 2

                 add r10,r5
                 asr r5,#1
                 add r9,r5

                 // volume

                 ldr r5,[r7,#0x1c0]
                 mul r4,r5,r9
                 mov r0,r4
                 mul r4,r5,r10
                 mov r6,r4

                 //  antialias r


                 ldr r8,[r7,#0x1b0]

                 add r8,r0  // r4
                 str r8,[r7,#0x1b0]

                 //  antialias l


                 ldr r8,[r7,#0x1ac]

                 add r8,r6 //r4       //lt
                 str r8,[r7,#0x1ac]



                 ldr r0,[r7,#0x1fc]
                 sub r0,#1
                 str r0,[r7,#0x1fc]

                 cmp r0,#0
                 bne p297

                       // for 12 bit pwm shift and unsign
  ldr r8,[r7,#0x1b0]

  asr r8,#11

  str r8,[r7,#0x1b0]

  ldr r8,[r7,#0x1ac]



  asr r8,#11  //#18


  str r8,[r7,#0x1ac]


                 ldmfd r13!,{r0-r12}

                 end;



  sid[0]:= siddata[$6b];
  sid[1]:= siddata[$6c];


  end;


initialization

begin
  for i:=0 to 127 do siddata[i]:=0;
  for i:=0 to 15 do siddata[$30+i]:=round(1073741824*(1-attacktable[i]));
  for i:=0 to 15 do siddata[$40+i]:=round(1073741824*attacktable[i]);
  for i:=0 to 1023 do siddata[128+i]:=combined[i];
  for i:=0 to 1023 do siddata[128+i]:=(siddata[128+i]-128) shl 16;
  siddata[$0e]:=$7FFFF8;
  siddata[$1e]:=$7FFFF8;
  siddata[$2e]:=$7FFFF8;
end;
end.

