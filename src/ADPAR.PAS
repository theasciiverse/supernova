{//-------------------------------------------------------------------------}
{/*                                                                         }
{Copyright (C) 2014 Jason Self <j@jxself.org>                               }
{                                                                           }
{This file is free software: you may copy, redistribute and/or modify it    }
{under the terms of the GNU Affero General Public License as published by   }
{the Free Software Foundation, either version 3 of the License, or (at your }
{option) any later version.                                                 }
{                                                                           }
{This file is distributed in the hope that it will be useful, but WITHOUT   }
{ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or      }
{FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License}
{for more details.                                                          }
{                                                                           }
{You should have received a copy of the GNU Affero General Public License   }
{along with this program; if not, see https://gnu.org/licenses or write to: }
{  Free Software Foundation, Inc.                                           }
{  51 Franklin Street, Fifth Floor                                          }
{  Boston, MA 02110-1301                                                    }
{  USA                                                                      }
{                                                                           }
{This file incorporates work covered by the following copyright and         }
{permission notice:                                                         }
{                                                                           }
{Copyright (C) 1990, 2009 - Apogee Software, Ltd.                           }
{                                                                           }
{This file is part of Supernova.  Supernova is free software; you can       }
{redistribute it and/or modify it under the terms of the GNU General Public }
{License as published by the Free Software Foundation; either version 3     }
{of the License, or (at your option) any later version.                     }
{                                                                           }
{This program is distributed in the hope that it will be useful,            }
{but WITHOUT ANY WARRANTY; without even the implied warranty of             }
{MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                       }
{                                                                           }
{See the GNU General Public License for more details.                       }
{                                                                           }
{You should have received a copy of the GNU General Public License          }
{along with this program; if not, see https://gnu.org/licenses or write to: }
{  Free Software Foundation, Inc.                                           }
{  51 Franklin Street, Fifth Floor                                          }
{  Boston, MA 02110-1301                                                    }
{  USA                                                                      }
{                                                                           }
{Original Source: 1990 Scott Miller                                         }
{Prepared for public release: 03/19/09 - Joe Siegler, Apogee Software, Ltd. }
{*/                                                                         }
{//-------------------------------------------------------------------------}
(*****************************************************************************)
(*                                  ADPAR                                    *)
(*    >> Contains the Parser, Initialization, Time and Misc. Routines <<     *)
(*                         Programmer: Scott Miller                          *)
(*                       << Began February 2, 1985 >>                        *)
(*                       Copyright 1985 Scott Miller                         *)
(*****************************************************************************)

procedure RL(Pointer:integer);forward;
procedure RS(Pointer:integer);forward;
procedure RR(Pointer:integer);forward;
procedure RB(Pointer,Colour:byte);forward;
procedure RB2(Pointer,Colour:byte);forward;
procedure MC(WhichChar,WatchRoom,ToRoom:byte;MessageNum:Integer);forward;
procedure Move(New:byte);forward;
procedure DEAD;forward;
procedure Call13;forward;
procedure Van(o:byte);forward;
function  FN(VNP:byte):Str29;forward;
function  Here(Obj:byte):Boolean;forward;
function  Up(Word:Str130):Str1;forward;

{ Asciiverse: the screen and keyboard come from avcrt, which draws the PC's
  80x25 text screen on a terminal of any size. The framed screen grows with
  the terminal: the status panel across the top, the story window below it.
  The PC speaker is silent (the SDL square wave of the free-software version
  is not built), so the waits that only timed a sound are left out. }
procedure nSetActiveWin(win:pwin);
 begin
  with win^ do
   if win=win2 then AvSetMainWindow(x,y,x1,y1) else window(x,y,x1,y1);
 end;

procedure nWindow(var win : pwin; x,y,x1,y1 : integer);
 begin
  win^.x:=x;   win^.y:=y;
  win^.x1:=x1; win^.y1:=y1;
 end;

procedure init_windows;
 begin
  stdscr:=@win_arr[1];
  win1:=@win_arr[2];
  win2:=@win_arr[3];
  nWindow(stdscr,1,1,ScreenWidth,ScreenHeight);
  nWindow(win1,2,2,ScreenWidth-1,4);
  nWindow(win2,2,5,ScreenWidth-1,ScreenHeight-1);
 end;

{ the story window's size: 78x20 on the PC }
function WinW:integer; begin WinW:=ScreenWidth-2 end;
function WinH:integer; begin WinH:=ScreenHeight-5 end;

{ a row of the death and victory banners, the story window's full width }
procedure Banner(y:integer;c:char;Edge:boolean);
 var fx:integer;
 begin
  gotoxy(1,y);
  for fx:=1 to WinW do
   if Edge or(fx=1)or(fx=WinW)then write(c) else write(' ');
 end;

procedure WritePrompt(x,y:integer);
 begin
  gotoxy(x,y);
  write(chr(175));
 end;

procedure InitScrKbd;
 begin
  buflen:=127;
  CheckBreak:=false;
  init_windows;
  nsetActiveWin(stdscr);
 end;

procedure DoneScrKbd;
 begin
  nSetActiveWin(stdscr);
  clrscr;
 end;

procedure sounddelayed( Hz,step: Integer ); begin end;

procedure sounddelayed( Hz: Integer ); begin end;

procedure ReadLine(var S:String);
 begin
  S:=AvReadLine(buflen,false);
  buflen:=127;
 end;

procedure SF; begin SFlag:=True end;

procedure Cur(Num:byte);
 begin
  case Num of
   1:cursoron;      { Underline   }
   2:cursorbig;     { Solid block }
   3:cursoroff;     { Invisible   }
  end;
 end;

procedure Col(Num1,Num2:byte);
 begin if Color then textcolor(Num1) else textcolor(Num2) end;

procedure Bak(Num1,Num2:byte);
 begin if Color then textbackground(Num1) else textbackground(Num2) end;

procedure Bor(Num1,Num2:byte);
 begin
  {with Result do
   begin AX:=$B00;if Color then BX:=Num1 else BX:=Num2 end;intr($10,Result)}
 end;

function  En(Num:byte):boolean;
 begin if Num in Events then En:=true else En:=false end;

procedure Add(Num:byte);
 begin Events:=Events+[Num] end;

procedure Min(Num:byte);
 begin Events:=Events-[Num] end;

procedure Score(Num,pointer:integer);
 begin if not en(pointer)then begin Sc:=Sc+Num;Add(Pointer)end end;

procedure Cn(s:str78);
 begin gotoxy((AvWindowWidth div 2)-(length(s)div 2),wherey);write(s);
  if wherey<AvWindowHeight then gotoxy(1,wherey+1) else writeln end;

procedure wCn(s:str78);
 begin gotoxy((AvWindowWidth div 2)-(length(s)div 2),wherey);writeln(s);end;

procedure Pause;
 begin col(15,15);write('Press any key to continue...');
  CFlag:=ReadKey;col(11,7);writeln;
 end;

procedure Tune(Octave,Note,Duration:integer);
  var Frequency:real;
      i:integer;
 begin
  Frequency:=32.625;
  for i:=1 to Octave do
   Frequency:=Frequency*2;
  for i:=1 to Note-1 do
   Frequency:=Frequency*1.059463094;
  if Duration <> 0 then
   begin
    sound(round(Frequency));
    delay(Duration div 10); { Asciiverse: a beat, the note is silent }
    nosound
   end
  else sound(round(Frequency));
 end;

procedure Play(Start,Stop,Speed:integer);
  var x:integer;
 begin
  if Start<=Stop then
   for x:=Start to Stop do
    if Speed>0 then sound(x) { Asciiverse: no wait for a silent tone }
     else sounddelayed(x)
  else
   for x:= Start downto Stop do
    if Speed>0 then sound(x)
     else sounddelayed(x);
  if Speed>0 then begin
   nosound;if Region=4 then sound(20);if Region=5 then sound(60);
   end;
 end;

procedure Explode(Duration:byte);
  var x:integer;
 begin for x:=Duration*999 downto 20 do sounddelayed(random(x));nosound end;

procedure Walls(Duration:byte);
  var x:integer;
 begin for x:=1 to Duration*999 do sounddelayed(random(35)+20);nosound end;

procedure Static;
  var x,y:integer;
 begin
  for x:=1 to 50 do
   case random(2) of
    0:for y:=1 to random(70)+10 do sounddelayed(random(4000)+3000);
    1:begin nosound;delay(random(29))end
   end;nosound;if Region=5 then sound(60)
 end;

procedure Blast;
  var x:byte;
 begin
  for x:=1 to 40 do
   begin play(550-x*6,600+x*6,0);play(600+x*6,550-x*6,0)end;explode(2)
 end;

procedure Dopen(Num:byte);
 begin writeln('The door slides open...');
  if Num<>0 then play(50,125-Num,Num)
  else begin for i:=3500 to 5000 do sounddelayed(random(4500)+i);nosound;end;
  if Region=5 then sound(60)
 end;

procedure Dclose(Num:byte);
 begin writeln('The sliding door closes.');
  if Num<>0 then play(125-Num,50,Num)
  else begin for i:=5000 downto 3500 do sounddelayed(random(4500)+i);nosound;end;
  if Region=5 then sound(60)
 end;

procedure Door(New,Num:byte);
 begin
  if en(7)then RL(22)else
  if en(8)then RL(23)else begin DOpen(Num);Move(New);DClose(Num)end
 end;

procedure won; forward;

procedure SoundTest;
  var ch:char;
 begin

  while true do begin
    
    writeln(' Sounds ');
    writeln(' 1. Won ');
    writeln(' 2. explode(32) ');
    writeln(' 3. Walls(12) ');
    writeln(' 4. Static ');
    writeln(' 5. Blast ');
    writeln(' 6. Dopen(10) ');
    writeln(' 7. Dclose(0) ');
    writeln(' Q. Quit ');

    ch:=readkey;

    if ch='q' then halt;

    case ch of
     '1' : Won;
     '2' : explode(32);
     '3' : Walls(12);
     '4' : Static;
     '5' : Blast;
     '6' : Dopen(10);
     '7' : DClose(0);
     '8' : begin
            for x:=1 to 20 do for y:=1 to x*8 do sounddelayed(x*9,trunc((168-y)/8)); nosound;
           end;
    end;

  end;

 end;

procedure Time1;
 begin Tic:=Tic+1; Min(128); { <--Negates DEAD } col(13,15);
  for x:=1 to TMax do T[x]:=T[x]-1;
  if T[2]=1 then begin PStat:=PStat-[5];RL(1)end;
  case T[3] of { Hunger }
   25:begin PStat:=PStat+[2];RL(2)end;
   12:RL(3);
   4:begin Bor(4,7);RL(4)end;
   1:begin RL(124);DEAD;end
  end;
  case T[4] of { Thirst }
   22:begin PStat:=PStat+[6];RL(5)end;
   11:RL(6);
   4:begin Bor(4,7);RL(7)end;
   1:begin RL(125);DEAD;end
  end;
  case T[5] of { Sleep }
   32:begin PStat:=PStat+[5];RL(8)end;
   14:RL(9);
   5:begin Bor(4,7);RL(10)end;
   1:begin RL(126);DEAD;end;
   2..4,6..13:begin x:=random(29)+1;
          if(x in Inv)and not(x in Wear)then
           begin Van(x);R[x]:=Prm;
            writeln('A bout of weariness causes you to loose your grip on',
                    ' the ',FN(x),'!')
           end
         end
  end;
  case T[29] of { Laser Injury }
   9:RS(214);
   4:begin RL(507);Bor(4,7)end;
   2,3,5..8,10,11:begin repeat x:=random(27)+1 until x in[1..12,16..20,22..26,28];
     if(x in Inv)and not(x in Wear)then
      begin Van(x);R[x]:=Prm;
       if random(2)=0 then
        writeln('A sudden stab of pain shoots up your side, you drop the ',
                 FN(x),'.') else begin
        writeln('The ',FN(x),' falls from your grip as you almost collapse ',
                'from the');writeln('extreme pain.')end
      end
     end;
   1:begin RS(215);DEAD;end
  end;
  case T[12] of  { Sickness }
   120,99,83,55:RL(207);
   65:begin PStat:=PStat+[3];RL(208)end;
   47:RL(209); 30:RS(73); 15:RS(74); 4:begin Bor(4,7);RS(75)end;
   1:begin RS(76);DEAD end;
   2,3,5..14,16..29:if(random(25)=0)and(Inv<>[])and not(en(125))then
          begin RS(232);
           for x:=1 to 29 do if(x in Inv)and not(x in Wear)then
            begin Van(x);R[x]:=Prm end
          end
  end;
  Col(10,7);
  if(Prm in[81..88])and(T[30]<1)and(random(4)=0)then
   if 28 in Wear then
    begin T[30]:=9;RS(153+Prm);
     for i:=999 to 2300 do sounddelayed(random(i*3)+i);
     for i:=3000 downto 20 do sounddelayed(random(i*4)+i*2);nosound
    end
   else
    begin
     write('A small droid appears from the ');
     case Prm of
      81:write('south'); 82:write('southwest'); 83:write('west');
      84:write('northwest'); 85:write('north'); 86:write('northeast');
      87:write('east'); 88:write('southeast')
     end; writeln(' section of the corridor and flies');
     RS(242);RS(243);for i:=20 to 3000 do sounddelayed(random(i*3)+i);nosound;
     delay(1500);DEAD
    end;
 end; { Time1 }

procedure Time2A;
 begin col(10,7);  { Pre-Jungle Planet }
  case T[1] of
   19:MC(1,13,13,0);
   18:begin MC(1,8,8,1);MC(1,13,8,2)end;
   17:if en(19) then begin RS(9);T[1]:=11;end;
   11..16:if not(en(19))and(Prm=8)and(random(2)=1)then RL(0);
   10:MC(1,8,9,3);
   9:begin MC(1,9,0,4);T[1]:=Null;end;
   5..7:if(en(2))and(en(3))then begin RB2(5-(T[1]-3),10);col(10,7)end;
   4:if Prm=8 then begin T[1]:=11;RS(5)end;
  end;
  if(T[7]=1)then begin RS(35);DEAD;end;
  if(T[6]=2)and(en(7))then RL(140);
  if(T[6]=1)and(en(7))then begin RS(20);DEAD;end;
  case T[8] of { Lift-off countdown }
   5:RL(181); 4:RL(182); 3:RL(191); 2:RL(192);
   1:if en(10)then
      begin Min(10);Min(26);Min(27);Explode(32);
       sound(20);Bor(0,0);Score(10,122);
       n[84]:='reactor regulat\';
       RB(7,10);delay(9999);Pause;col(10,7);RS(43);PStat:=PStat-[2,5,6];
       Region:=4;T[3]:=150;T[4]:=125;T[5]:=230;T[8]:=0;T[9]:=1;T[10]:=5;end
     else begin RS(44);Explode(32);DEAD;end;
  end;
  if T[9]<1 then T[9]:=15;
  if(Region=4)and(Prm=1)and(T[9]=12)then RS(62);
  if T[10] in[1..4]then RL(194);
  if(Tic>3)and(Prm=8)and not(en(9))and not(en(7))then
   begin RS(6);Add(9)end else
  if(Tic>5)and(Prm=8)and(en(9))and not(en(16))and not(en(7))then
   begin RS(7);Add(16)end;
  case Prm of
    1:if(random(2)=0)and(T[9]>12)and(T[9]<15)and(Region=4)and not en(129)then
       begin RL(593);RL(594);Add(129)end
      else if(random(20)=0)and(Region=4)then RL(592);
    7:if random(5)=0 then RL(595);
    8:if random(3)=1 then RL(24)else if random(3)=1 then RL(178);
   15,17,19:case random(60) of
     1:RL(596);
     2:RL(597);
     3,4:if RC>40 then begin if T[4]>10 then T[4]:=10;RL(598)end;
     end; {case}
   20:if random(4)=1 then RL(25);
  end; {case}
  if Prm=SinkRm then begin RL(85);L[Prm]:=L[Prm]+[79];end;
end; { Time2A }

procedure Time2B;
 begin col(10,7);  { Jungle Planet }
  Maze:=not(Maze);
  if Prm in[42..49]then
   begin writeln('Some of the walls shift positions.');Walls(4);end;
  case Prm of
   7:if random(5)=0 then RL(595);
   26..29,32..34,59,60:case random(40) of
      0,1:RL(210); 2,3:RL(211); 4:RS(77); 5,6:RS(78); 7,8:RL(212);
      9:RL(213); 10:RL(214); 11:begin RL(215);play(6000,6001,20)end
     end;
   42..50:if random(7)=0 then RL(280);
  end; {case}
  if(Prm=28)and(random(2)=0)then RL(233);
  if Prm=SinkRm then begin RL(85);L[Prm]:=L[Prm]+[79];end;
  if T[11]=2 then RL(205);
  if T[11]=1 then begin RS(70);DEAD;end;
  if T[13]=1 then begin RB(11,10);for x:=1 to 3 do begin tune(4,2,200);
   delay(99);tune(4,5,200);delay(99)end;Pause end;
  if(T[14]=2)and(Prm in[40,41])then RL(251);
  if T[14]=1 then
   case Prm of 40:begin RL(249);Walls(8);end;41:begin RL(250);Walls(8);end end;
  if(T[15]=1)and(Prm=39)then begin RS(94);DEAD;end;
  if T[17]=4 then begin RS(109);DEAD;end;
  if T[17]=1 then begin Add(36);if Prm=56 then begin RS(110);Walls(8);end end;
  if T[18]=2 then begin RS(123);Walls(12)end;
  if(T[18]=1)and(Prm=53)then begin RS(124);Walls(12);DEAD;end;
  if T[19]=1 then begin RS(128);Walls(12);DEAD;end;
 end; { Time2B }

procedure Time2C;
 begin col(11,7);  { Inner Planet }
  if T[20]=1 then
   case Prm of 73:DClose(20);66:begin RL(337);play(105,50,20)end end;
  col(10,7);
  if(Prm=74)and not(en(47))then
   writeln('There is something flashing on the computer''s screen.');
  if(Prm=73)and(CodeSet<>4)then begin
   writeln('There''s an alarm sound coming over the radio.');
   for x:=1 to 23 do
    begin
     for i:=450 to 999 do sounddelayed(i);
     for i:=999 downto 450 do sounddelayed(i);
    end;nosound
   end;
  case random(50) of
   1..3:if here(38)then RL(588);
   4,5:begin RL(589);Explode(3)end;
   6:begin RS(244);for x:=1 to 7 do Static;end
   else if(Prm in[64,73])and(random(9)=0)then begin RL(590);RL(591)end
  end;
 end; { Time2C }

procedure Time2D;  { Planetship }
  function Warn(Message,IfTime,Said:integer):boolean;
   begin Warn:=false;
    if not en(Said)and(IfTime>=T[26])then
     begin if Said<>59 then begin Static;RS(Message);Static end
           else if Prm>99 then begin Static;RS(Message);Static end;
      if(Said=59)and(Prm<100)then begin end
      else begin Warn:=True;Add(Said)end
     end
   end; {Warn}
 begin col(11,7);
 for x:=0 to 2 do if T[23+x]>2 then Score(20,118+x); { 60 total points }
 if en(64)then Score(10,121);
  if T[21]=1 then
   case Prm of 91:DClose(20);86:begin RL(337);play(110,50,15)end end;
  col(10,7);
  if(Prm=95)and not(en(48))then begin
   writeln('A loud siren is sounding off...');
   play(300,530,6);delay(200);play(300,530,6)end;
  if(Prm=91)and not en(53)then begin writeln('An alarm is ringing...');
    for x:=1 to 23 do begin sound(400);delay(99);sound(940);delay(60);nosound;
   end end;
  if T[22]=1 then
   begin write('The door slides open...');play(50,60,65);
    writeln('then closes.');play(60,50,60);
    if en(50)then RS(153)else
    if Inv=[] then begin RS(247);RS(248)end
    else begin RS(154);RS(155);Inv:=[];end;
    delay(2500);write('The door slides open...');play(50,60,65);
    writeln('then closes.');play(60,50,65);
   end;
  case T[23] of
   13:begin if Prm=91 then RL(438);MC(2,91,91,161);Add(53)end;
   12:MC(2,91,91,162);
   11:begin if Prm in[86,91]then DOpen(15);MC(2,91,86,163);MC(2,86,86,164);
       if Prm in[86,91]then DClose(15)end;
   10:begin MC(2,86,87,165);MC(2,87,87,166)end;
   9:begin if Prm in[87,89]then DOpen(65);MC(2,87,89,167);MC(2,89,89,168);
      if Prm in[87,89]then DClose(65)end;
   7,8:if Prm=89 then begin ScrnSet:=4;RL(417)end;
   6:begin if Prm in[87,89]then DOpen(65);MC(2,89,87,169);MC(2,87,87,170);
      if Prm in[87,89]then DClose(65)end;
   5:begin MC(2,87,86,171);MC(2,86,86,172)end;
   4:if T[21]<2 then begin MC(2,86,91,173);if Prm in[86,91]then DOpen(15);
      if Prm=86 then RL(418);MC(2,91,91,174);if Prm in[86,91]then DClose(15)end
      else if Prm=86 then begin RL(418);MC(2,0,91,0)end;
   1:if Prm=91 then begin RL(419);Van(123);DClose(55)end else Van(123)
  end; {T[23]}
  if(T[23]>1)and(T[23]<4)and(Prm=91)then begin T[24]:=7;T[23]:=NULL;end;
  case T[24] of
   7:if Prm=91 then RS(175);
   6:if Prm=91 then begin RS(176);RS(177)end;
   5:if Prm=91 then begin RS(178);RS(179)end;
   4:begin if Prm=91 then RL(420);if not(1 in Inv)then T[24]:=2;end;
   2,3:if(Prm=91)and(1 in Inv)then RL(419+T[24]);
   1:begin Van(123);if Prm=91 then begin RS(180);DOpen(55);RL(418);
      DClose(55)end;
     end;
  end; {T[24]}
  case T[25] of
   2..5:if Prm=91 then RS(188-T[25]);
   1:begin if Prm=91 then RS(187);T[24]:=2;T[26]:=40;Add(64)end;
  end; {T[25]}
  if en(64)then
  if not Warn(198,38,54)then
  if not Warn(199,33,55)then
  if not Warn(203,30,59)then
  if not Warn(200,25,57)then
  if not Warn(201,20,58)then
  if not Warn(202,15,56)then
  if not Warn(204,10,60)then
  if not Warn(205,6,61)then
  if not Warn(206,3,62)then
  if not Warn(207,2,63)then begin end;
  if T[26]=1 then begin RS(197);DEAD;end;
  if(T[27]=1998)and(Prm=99)then  begin RS(213);Blast;DEAD;end;
  if(T[28]=1998)and(Prm=101)then begin RS(213);Blast;DEAD;end;
 end; { Time2D }

procedure Directory;
var
  SM1Found  : boolean;
  Info      : TSearchRec;
begin
  {ChDir(Drive+':');}
  SM1Found:=false;
  writeln;
  if FindFirst ('*',faAnyFile,Info)=0 then
    repeat
      if length(Info.Name)>4 then
       if copy(Info.Name,length(Info.Name)-2,3)='sm1' then
        begin
         if not SM1Found then
          writeln('Here is a list of the SAVE/RESTORE files on the ',
                  'disk in drive ',up(Drive),':');
        SM1Found:=true;
        writeln('    * ',copy(Info.Name,1,length(Info.Name)-4));
       end;
    until FindNext(Info)<>0;
  
  FindClose(Info);
  writeln;
  if not SM1Found then
   begin
    writeln('There are not any SAVE/RESTORE files on the disk in drive ',
            up(Drive),':');writeln;
   end;
  Pause;{ChDir(Log+':');}
end; {Directory}

function Up(Word:Str130):Str1;
 begin word:=word+' ';
  if(Word[1]='l')and(Word[2]=' ')then insert('ook',Word,2);
  if(Word[1]='e')and(Word[2]='x')and(Word[3]=' ')then insert('amine',Word,3);
  delete(Word,length(word),2);Up:='';
  for x:=1 to length(Word) do Word[x]:=upcase(Word[x]);
  col(12,15); write(Word); col(11,7)
 end;

procedure Spaces(var I:Str130);
 begin I:=concat(' ',I,' ')end;

procedure QFormat(var I:Str130);
 begin
  if(I[1]='.')or(I[1]=' ')then delete(I,1,1);
  if(I[length(I)]='.')or(I[length(I)]=' ')then delete(I,length(I),1);
 end;

procedure PreFormat(var I:Str130);
 procedure D(A:Str29;B:byte);
  begin while pos(A,I)<>0 do delete(I,pos(A,I),B)end;
 begin D('  ',1);QFormat(I);
  FFlag:=0; if(length(I)>0)then FFlag:=1;
  Spaces(I);
  Crawl:=false;if pos(' crawl ',I)>0 then Crawl:=true;D(' crawl ',6);
  D(' walk ',5);D(' run ',4);D(' go ',3);D(' travel ',7);
  QFormat(I); if(length(I)=0)and(FFlag=1)then FFlag:=2; Spaces(I);
  D(' of ',3);D(' the ',4);D(' very ',5);D(' more ',5);D(' and ',4);
  D(' large ',6);D(' big ',4);D(' huge ',5);D(' please ',7);
  D(' small ',6);D(' little ',7);D(' tiny ',5);
  D('''',1);D('#',1);D('!',1);D('?',1);D(' number ',7);
  QFormat(I); if(length(I)=0)and(FFlag=1)then FFlag:=3; Spaces(I);
  while pos('examine ',I)>0  do delete(I,pos('examine ',I)+2,5);
  while pos(' into ',I)>0    do delete(I,pos(' into ',I)+3,2);
  while pos(' onto ',I)>0    do delete(I,pos(' onto ',I)+3,2);
  while pos(' inside ',I)>0  do delete(I,pos(' inside ',I)+3,4);
  while pos(' within ',I)>0  do delete(I,pos(' within ',I)+1,4);
  while pos('look ',I)>0     do delete(I,pos('look ',I)+1,3);
  while pos('. ',I)>0        do delete(I,pos('. ',I)+1,1);
  while pos(',',I)>0         do
   begin insert(' ',I,pos(',',I));delete(I,pos(',',I),1)end;
  D('..',1);D(' .',1);D('  ',1);
  QFormat(I);
  if(length(I)=0)then
   begin EFlag:=Null;
    case FFlag of
     2:RL(193);
     3:RL(186)
     else writeln('Pardon me?')
    end;
   end
 end; { PreFormat }

procedure LowerCase(var I:Str130);
 begin
  if(length(I)>0)then
   for x:=1 to length(I) do
    if(I[x] in['A'..'Z'])then
     I[x]:=chr(ord(I[x])+32);
 end; { LowerCase }

procedure ChopSeven(var I:Str130);
  var Word:Str130;
 begin
  if(length(I)>0)then
   begin
    I:=I+' '; x:=1;
     repeat
      Word:='';
      while(I[x]<>' ')and(I[x]<>'.')and(I[x]<>',')do
       begin Word:=Word+I[x]; x:=x+1 end;
      if(length(Word)>7)then
       begin
        y:=pos(Word,I); x:=x+(7-length(Word));
        delete(I,y,length(Word)); delete(Word,8,130);
        insert(Word,I,y)
       end;
      x:=x+1;
     until(x-1)=length(I);
    delete(I,length(I),1)
   end
  end; { ChopSeven }

procedure FindMood(var input:Str130;var Word:Str29;var Md:byte);
  var Temp1:Str53;
      Temp2:Str29;
      Counter:char;
 begin
  Spaces(input);x:=0;
  while x < AMax do
   begin x:=x+1;
    Counter:='1';
    Temp1:=A[x];
    while pos(Counter,Temp1)>0 do
     begin
      Temp2:=copy(Temp1,1,pos(Counter,Temp1)-1);
      if(pos(' '+Temp2+' ',input)>0)then
       begin
        Word:=Temp2;
        Md:=x;if Md=2 then Md:=1;
        x:=AMax;Counter:='8';
        delete(input,pos(Temp2,input),length(Temp2)+1);
       end;
      delete(Temp1,1,pos(Counter,Temp1));
      Counter:=succ(Counter);
     end;
   end;
  QFormat(input);
 end; { FindMood }

function FN(VNP:byte) : Str29; { ( Finds first Noun ) }
  var Temp:Str29;
 begin SF;
  Temp:=n[VNP];
  FN:=copy(Temp,1,pos('\',Temp)-1);
 end; { FW }

function Here(Obj:byte) : Boolean;
 begin Here:=false;
  if Obj in L[Prm] then Here:=true;
  if(Obj=79)and(MugCon=79)and(29 in Inv)then Here:=true;
  if Obj<=MMax then if(R[Obj]=Prm)or(Obj in Inv)then Here:=true;
  if(Obj=58)and((3 in Inv)or(4 in Inv)or(R[4]=Prm)or(R[3]=Prm))then Here:=true;
 end;

function Present : Boolean;
  label JUMP;
 begin Present:=false; x:=0;
  if not(Vb in [17,18,37,39]) then
   if N1<>Null then
    if Here(N1) then
     if N2<>Null then
      if Here(N2) then Present:=true
      else writeln('You can''t see any ',FN(N2),' here.')
     else Present:=true
    else writeln('You can''t see any ',FN(N1),' here.')
   else Present:=true
  else
   begin JUMP: x:=x+1;
    if x<=NMax then
     if x in NounSet then
      if Here(x) then goto JUMP
      else begin writeln('You can''t see any ',FN(x),' here.');end
     else goto JUMP
    else Present:=true
   end
 end; { Present }

procedure Convert(var n:byte;Max:byte);
 begin
  case Max of
   1:case n of                     { Verbs }
      12:n:=11; 14:n:=13; 23:n:=22; 27:n:=26;
      29:n:=28; 34:n:=33; 36:n:=35; 38:n:=37; 40:n:=39; 43:n:=42; 45:n:=44;
      52:n:=51; 55:n:=54; 57,58:n:=56; 60,61:n:=59; 63:n:=62;
     end;
   2:case n of                     { Nouns }
      13..15:n:=12; 21:n:=20; 33:n:=32; 36:n:=35; 39:n:=38; 45:n:=44;
      50:n:=49; 53:n:=52; 65:n:=64; 67:n:=66; 70:n:=69; 76,77:n:=75;
      97:n:=96; 101,102:n:=100; 114:n:=113; 117:n:=116; 63:n:=62;
      27:n:=26; 57:n:=56; 61:n:=60; 91:n:=90; 105..108:n:=109; 31:n:=28;
      133:n:=46; 84:if Prm>21 then n:=128; 115:if Prm=28 then n:=112;
      58:if Prm=52 then n:=64;
     end;
   3:case n of                  { Prepositions }
       2:n:=1; 4:n:=3; 8:n:=7 ;
     end;
  end;
 end; { Convert }

procedure FindWord( var I    : Str130;   { input string }
                    var VNP  : byte;     { flags which # word found }
                    var Word : Str29;    { stores last word found }
                        Max  : byte);    { check which list? }
  const Slash = '\';
  var j,ps:byte;
      Temp1,Temp2:Str29;
 begin
  QFormat(I); Spaces(I); J:=0;
  while (j<m[Max]) do
   begin
    j:=j+1;
    case Max of 1:Temp1:=v[j]; 2:Temp1:=n[j]; 3:Temp1:=p[j] end;
    ps:=pos(Slash,Temp1);
    while ps>0 do
     begin
      Temp2:=copy(Temp1,1,ps-1);
      if(copy(I,1,length(Temp2)+2)=' '+Temp2+' ')then
       begin { Match Found }
        VNP:=j;
        Convert(VNP,Max);
        Word:=Temp2;
        delete(I,1,length(Temp2)+1);
        case Max of 1:VStr:=Word; 2:NStr:=Word end;
        j:=m[Max];
        Temp1:='X';
       end;
      delete(Temp1,1,ps);
      ps:=pos(Slash,Temp1);
     end;
   end; { main loop }
  QFormat(I);
 end; { FindWord }

procedure Dictionary(IfFound,SkipList:byte);
  var StopLoopFlag:byte;
 begin VNP:=Null; list:=1; StopLoopFlag:=1;
  while(list<4)and(StopLoopFlag=1)do
   begin
    if list=SkipList then list:=list+1
     else
      begin
       FindWord(input,VNP,Word,list);
       if(VNP<>Null)then
        begin EFlag:=IfFound;list:=list-1;StopLoopFlag:=0;end;
       list:=list+1;
      end
   end;
  if(EFlag<>IfFound)then
  begin
   EFlag:=5;input:=input+' ';
   Word:=copy(input,1,pos(' ',input)-1);
   if(pos(' '+Word+' ',' top directi next some from is under underne '+
                        'leaning but speak pay ')>0)then
    EFlag:=IfFound
   else If Word[1] in['0','1','2','3','4','5','6','7','8','9'] then EFlag:=17;
   if IfFound=14 then EFlag:=14;
   QFormat(input);
  end;
 end; { Dictionary }

procedure RL(Pointer:Integer);
 begin SF;
  if(pointer<>StoreL)then
   begin StoreL:=pointer;
    seek(L1,pointer);
    read(L1,Text3)
   end;
  writeln(Text3);
 end; { Read Line }

procedure RS(Pointer:Integer);
 begin SF;
  if(pointer<>StoreS)then
   begin StoreS:=pointer;
    seek(S1,pointer);
    read(S1,Text4)
   end;
  writeln(Text4);
 end; { Read Special }

procedure RR(Pointer:integer);
 begin SF;
  if(pointer<>StoreR)then
   begin StoreR:=pointer;
    seek(R1,pointer);
    seek(R2,pointer);
    read(R1,Text1);
    read(R2,Text2);
   end;
  write(Text1);
  writeln(Text2);
 end; { Read Room }

procedure RB(Pointer,Colour:byte);
  var Block:Str255;
      Tstart,TStop:Str19;
 begin SF; Col(Colour,7);
  str(Pointer-1,TStart);
  str(Pointer,TStop);
  TStart:='('+TStart+')';
  TStop:='('+TStop+')';
  if old>=Pointer then reset(T1);
  old:=Pointer+1;
  repeat readln(T1,Block) until Block=TStart;
  repeat
   readln(T1,Block);
   if(Block<>TStop)then writeln(Block)
  until Block=TStop; col(11,7);
 end;

procedure RB2(Pointer,Colour:byte);
  var Block:Str255;
      Tstart,TStop:Str19;
 begin SF; Col(Colour,7);
  str(Pointer-1,TStart);
  str(Pointer,TStop);
  TStart:='('+TStart+')';
  TStop:='('+TStop+')';
  if old2>=Pointer then reset(T2);
  old2:=Pointer+1;
  repeat readln(T2,Block) until Block=TStart;
  repeat
   readln(T2,Block);
   if(Block<>TStop)then writeln(Block)
  until Block=TStop; col(11,7);
 end;

procedure Won;
  const W=800;H=400;Q=200;T=131;
  label JUMP;
 begin writeln;
  gotoxy(1,WinH);for x:=1 to 5 do
   begin writeln;delay(99);sound(x*50);Bor(x,7)end;
  col(4,15);bak(1,7);
  Banner(WinH-5,'#',true);
  delay(99);sound(300);Bor(6,0);
  for x:=1 to 3 do begin
  Banner(WinH-5+x,'#',false);
        delay(99);sound(300+(x*50));Bor(x+8,15)end;
  Banner(WinH-1,'#',true);
  delay(99);sound(500);Bor(14,0);
  gotoxy((WinW div 2)-13,WinH-3);col(31,31);
  write('Y O U   H A V E   W O N ! !');delay(99);sound(550);
  gotoxy(1,WinH);bak(0,0);Bor(2,7);writeln;delay(99);nosound;
  for x:=1 to 12 do begin writeln;delay(80)end;
  gotoxy(1,WinH-11);Col(9,9);
  writeln('                              S U P E R N O V A');writeln;Col(11,7);
  writeln('     Programmed by . . . . . . . . . . . . . . . . . . . . . Scott Miller');
  writeln('     Story by  . . . . . . . . . . . . . . . . . . . . . . . Scott Miller');
  writeln('     Additional story development. . . . . . . . . . . . . . . Terry Nagy');
  writeln;writeln;
  Vb:=78;Call13;writeln;writeln;Col(3,7);
  write('Press any hey to quit...');
  tune(2,8,q);tune(2,8,q);tune(3,1,w);
  repeat
   tune(2,8,q);tune(2,8,q);
   tune(3,1,h);tune(2,12,h);tune(2,10,h);tune(2,8,q);tune(2,8,q);
   tune(3,1,w);tune(2,8,t);tune(2,8,t);tune(2,8,t);
   if keypressed then goto JUMP;
   tune(3,1,h);tune(2,12,h);tune(2,10,h);tune(2,8,t);tune(2,8,t);tune(2,8,t);
   tune(3,3,w);
   if keypressed then goto JUMP;
   tune(2,10,q);tune(2,10,q);
   tune(3,3,h);tune(3,1,h);tune(2,12,h);tune(2,10,q);tune(2,10,q);
   if keypressed then goto JUMP;
   tune(3,3,w);tune(2,10,t);tune(2,10,t);tune(2,10,t);
   tune(3,3,h);tune(3,1,h);tune(2,12,h);tune(2,10,t);tune(2,10,t);tune(2,10,t);
   tune(3,1,w);
  until keypressed;
  JUMP: CFlag:=ReadKey;
  DoneScrKbd;
  AvFarewell('Congratulations!');
  HALT;
 end; { Won }

{ Asciiverse: the frame and the status panel, drawn for the terminal's size
  when the game starts and again whenever the terminal is resized }
procedure DrawFrame;
 var fx,fy:integer;
 begin
  init_windows;
  nSetActiveWin(stdscr);
  col(7,15);bak(1,7);
  for fx:=1 to ScreenWidth do
   begin gotoxy(fx,1);write(chr(205));gotoxy(fx,ScreenHeight);write(chr(205))end;
  for fy:=2 to ScreenHeight-1 do
   begin gotoxy(1,fy);write(chr(179));gotoxy(ScreenWidth,fy);write(chr(179))end;
  gotoxy(1,4);write(chr(198));for fx:=2 to ScreenWidth-1 do
   begin gotoxy(fx,4);write(chr(205))end;
  gotoxy(ScreenWidth,4);write(chr(181));
  gotoxy(1,1);write(chr(213));gotoxy(ScreenWidth,1);write(chr(184));
  gotoxy(1,ScreenHeight);write(chr(212));
  gotoxy(ScreenWidth,ScreenHeight);write(chr(190));
  nSetActiveWin(win1);
  bak(4,7);col(14,0);gotoxy(1,1);
  for fx:=1 to WinW do write(' ');
   gotoxy(1,1);write('Move');
  gotoxy(WinW-11,1);write('Score');
  bak(7,7);gotoxy(1,2);
  for fx:=1 to WinW do write(' ');
  bak(5,7);col(15,0);
  gotoxy(1,2);write('Player Condition:');
  col(7,15);bak(1,7);
 end;

procedure DrawStatus;
 begin
    nSetActiveWin(win1);
    bak(4,7);col(14,0);
    gotoxy(7,1);write(Tic,'   ');
    gotoxy((WinW div 2)-5-(length(RN[Prm])div 2),1);
      write('      ',RN[Prm],'      ');
    gotoxy(WinW-4,1);write('    ');gotoxy(WinW-4,1);write(Sc,' ');
    bak(7,7);
    col(1,0);gotoxy(21,2);
    if PStat=[] then write('Healthy') else write('  *    ');
    col(15,0);gotoxy(32,2);
    if 2 in PStat then begin col(31,16);write('Hungry')end
    else write(' *    ');
    col(4,0);gotoxy(42,2);
    if 3 in PStat then begin col(20,16);write('Sick')end
    else write(' *  ');
    col(0,0);gotoxy(50,2);
    if 4 in PStat then begin col(16,16);write('Injured')end
    else write('   *   ');
    col(6,0);gotoxy(61,2);
    if 5 in PStat then begin col(22,16);write('Tired')end
    else write('  *  ');
    col(5,0);gotoxy(70,2);
    if 6 in PStat then begin col(21,16);write('Thirsty')end
    else write('   *   ');
    nSetActiveWin(win2);bak(0,0);
 end;

procedure Resized;
 var Attr:byte;
 begin
  Attr:=TextAttr;
  DrawFrame;DrawStatus;
  TextAttr:=Attr;
 end;

procedure PlayerInput(var LINE:Str130);
  label JUMP;
  var Ch : Char;
      ExtCode : integer;
  procedure Key(k:Str19); begin Line:=Line+k;QFlag:=true;write(k)end;
 begin
 {with Result do begin}
  WRITELN; { Main Space In Game }
  if(length(Line)=0)then
   begin
    DrawStatus;
    if en(66)then begin gotoxy(1,WinH);goto JUMP;end;
    gotoxy(1,WinH);col(28,31);writeln;
    WritePrompt(1,WinH-1);
    Cur(1);
    col(14,7);gotoxy(3,WinH-1);
    AvSetWrap(false);
    QFlag:=false;
    repeat
     Ch:=Readkey;
     { Read Extended (Scan) Code }
     if Ch = #0 then ExtCode:=Ord(Readkey);
     sounddelayed(99,1);speaker_on:=true;delay(1);case Region of 4:sound(20);5:sound(60)end;
     case Ch of
     ^h:begin
	if(wherex=1)and(wherey=WinH)then
           begin gotoxy(WinW,wherey-1); ClrEol; end else
         if length(Line)>0 then write(^h,' ',^h);
         delete(Line,length(Line),2);
        end;
     ^m:QFlag:=true
     else
      begin
       if(Ord(Ch)>0)and(length(Line)<110)then
        begin write(Ch);Line:=Line+Ch;end
       else if AvPageKey(ExtCode,false) then
        { Asciiverse: Shift+PgUp and Shift+PgDn page back through the story }
       else { read scan }
        begin
         case ExtCode of
          59:key('Save');      71:key('Northwest');
          60:key('Restore');   73:key('Northeast');
          61:key('R D');       79:key('Southwest');
          62:key('Look');      81:key('Southeast');
          63:key('Get all');   82:key('Down');
          64:key('Drop all');  83:key('Up');
          65:key('Score');     104:begin QFlag:=true;RR(0)end;
          66:key('Inventory');
          67:key('Wait');
          68:begin Line:='';key('Repeat')end;
          94,30:key('by Scott Miller');
          95,47:key('Version A Dec 9, 85');
          31:SoundTest;
         end;
        if Prm in[1..7] then
         case ExtCode of
          72:key('Fore'); 75:key('Port'); 77:key('Starboard'); 80:key('Aft')
         end
        else
         case ExtCode of
          72:key('North'); 75:key('West'); 77:key('East'); 80:key('South')
         end
       end
      end
     end; {case}
     until QFlag=true;
    Cur(3);AvSetWrap(true);
    col(5,7);WritePrompt(1,WinH-1);col(11,7);gotoxy(1,WinH);
    if length(Line)>WinW-2 then writeln;
    LowerCase(Line);Spaces(Line);
    if(pos(' r ',Line)>0)or(pos(' repeat ',Line)>0)then PreFormat(Line);
    if(Line='r')or(Line='repeat')then Line:=Again else Again:=Line;
    Spaces(Line);
    while pos(' then ',Line)>0 do
     begin
      x:=pos(' then ',Line);delete(Line,x,5);insert('.',Line,x)
     end;
    ChopSeven(Line);
    PreFormat(Line);
   end;
   if(pos('.',Line)>0)then
    begin    { SEPERATES LINE INTO SINGLE INPUTS }
     input:=copy(Line,1,pos('.',Line));
     delete(Line,1,pos('.',Line));
     delete(input,pos('.',input),1);
     PreFormat(input);
    end
   else
    begin
     input:=Line; Line:='';
    end; { END OF LINE SEPERATION }
   Spaces(input);
   while pos(' it ',input)>0 do
    begin x:=pos(' it ',input)+1;delete(input,x,2);insert(LastNoun,input,x);
     PreFormat(input);ChopSeven(input);
    end;
   while pos(' them ',input)>0 do
    begin x:=pos(' them ',input)+1;delete(input,x,4);insert(LastNoun,input,x);
     PreFormat(input);ChopSeven(input);
    end;
   QFormat(input);
   col(11,7);
   JUMP:
 {end;} { of with statement }
 end; { PlayerInput }

procedure Title;
 var Off:integer;
 begin
  Off:=(ScreenHeight-25)div 2;
  clrscr;textcolor(7);Color:=true;
  if ParamCount=0 then begin
   write('Do you want ');textcolor(15);write('C');textcolor(7);
   write('olor or ');textcolor(15);write('B');textcolor(7);
   write('lack and white? ');textcolor(15); CFlag:=ReadKey;
   if(upcase(CFlag)='B')or(upcase(CFlag)='M')then
    begin Color:=false;write('Monochrome')end
   else write('Color');delay(300);
  end
  else
   begin input:=ParamStr(1);CFlag:=input[1];
    if(CFlag='/')and(length(input)>1)then CFlag:=input[2];
    if(upcase(CFlag)='B')or(upcase(CFlag)='M')then
     begin Color:=false;writeln('Monochrome screen option...')end
    else writeln('Color screen option...');delay(999)
   end;
  clrscr;textmode(BW80);
  Cur(3);

                 {**** Public Domain title screen ****}
  {Col(9,9);gotoxy(1,1);
  cn('S U P E R N O V A');
  Col(9,7);gotoxy(1,3);
  cn('Published by');
  gotoxy(1,5);
  cn('APOGEE SOFTWARE PRODUCTIONS');
  writeln;
  Col(11,7);
  cn('This game is placed in the public domain for your enjoyment.   Please do');
  cn('not abuse this product or the author''s rights.');
  writeln;
  cn('If you enjoy this game the author asks that you contribute $10 (by check).');
  cn('This payment  will encourage the author  to create similar games  and will');
  cn('help compensate him  for the several years work that went into  Supernova.');
  cn('This fee will also register the payer for telephone support and clues.');
  writeln;
  Col(14,15);
  writeln('Please make checks payable to:  Scott Miller');
  writeln;
  writeln('Scott Miller      (214) 240-0614');
  writeln('4206 Mayflower Drive');
  writeln('Garland, TX 75043');
  writeln;
  writeln('Also call for help:  Terry Nagy  (214) 271-3065');
  writeln;
  Col(11,7);delay(7000);
  cn('Thanks, enjoy the game...');

  Col(7,7);gotoxy(27,25);delay(999);
  write('Press any key to continue.');repeat;delay(1);until keypressed;
  CFlag:=ReadKey;}bak(1,0);clrscr;
                 {**** Main SUPERNOVA title screen ****}

  Bor(1,0);Col(15,15);Bak(4,0);
  for x:=1 to ScreenWidth do
   begin gotoxy(x,1);write(chr(205));gotoxy(x,ScreenHeight-1);write(chr(205))end;
  for y:=1 to ScreenHeight-1 do
   begin gotoxy(1,y);write(chr(186));gotoxy(ScreenWidth,y);write(chr(186))end;
  gotoxy(1,1);write(chr(201)); gotoxy(ScreenWidth,1);write(chr(187));
  gotoxy(1,ScreenHeight-1);write(chr(200));
  gotoxy(ScreenWidth,ScreenHeight-1);write(chr(188));
  Bak(1,0);
  Col(2,7);gotoxy(1,10+Off);cn('Copyright 1987 Scott Miller');
  Col(14,7);gotoxy(1,12+Off);cn('Version B');
  Col(7,7);gotoxy(1,15+Off);
  cn('Programmed by Scott Miller');
  cn('Story by Scott Miller and Terry Nagy');
  gotoxy(1,23+Off);Col(3,7);
  cn('Press any key to continue.');
  repeat
   gotoxy((ScreenWidth div 2)-8,8+Off);
   if Color then textcolor(random(16))
   else case random(3) of  0:textcolor(0); 1:textcolor(7); 2:textcolor(15)end;
   write('S U P E R N O V A');
   delay(60); { Asciiverse: the PC took about a millisecond a turn; 60 keeps
                the colours flickering without flooding the terminal }
  until keypressed;
  CFlag:=ReadKey;
  if Color then textmode(C80)else textmode(BW80);
 end; { Title }

procedure Init1;
  label Abort;
  var Off:integer;
 begin ABORT: Off:=(ScreenHeight-25)div 2;
  Bor(0,0);bak(0,0);clrscr;nosound;
  Cur(3);randomize;
  Log:='A'; { Asciiverse: was the current drive's letter, from a folder name
             too long for Word, which failed the next write }
  for x:=1 to 20 do begin sound(x*9);delay(x*2)end;nosound;
  gotoxy(1,9+Off);y:=0;col(14,7);Identity:='';
  Cn('Please enter your identity code name:');col(12,15);
  repeat begin i:=random(maxint); delay(1) end; until keypressed;
  repeat CFlag:=ReadKey;
   if(CFlag<>chr(13))then
    if(CFlag<>^h)then Identity:=Identity+upcase(CFlag)
    else delete(Identity,length(Identity),2);
   gotoxy(1,11+Off);Cn(' '+Identity+' ');
{sound(50);delay(50);nosound;}
   for x:=1 to 50 do sounddelayed(50,1); nosound;
  until CFlag=chr(13);
  col(10,7);gotoxy(1,7+Off);
  if identity<>'' then
   Cn(' IDENTITY CODE ACCEPTED--YOU MAY PROCEED '+Identity)
  else begin
   col(25,31);Bor(4,7);Cn('IDENTITY CODE REJECTED--ABORTING SEQUENCE')end;
  LowerCase(Identity);ChopSeven(Identity);
  delay(1500);
  if Identity='' then goto ABORT;
  assign(L1,'L1');
  assign(C1,'C1');
  assign(S1,'S1');
  assign(R1,'R1');assign(R2,'R2');
  assign(T1,'SM');assign(T2,'B1');
  reset(R1);reset(R2);
  reset(S1);reset(L1);reset(C1);
 end; { Init1 }

procedure Init2;
 begin
  bak(0,0);clrscr; { the identity screen goes before the frame is drawn }
  DrawFrame;
  AvOnResize:=@Resized;
  nSetActiveWin(win2);
  bak(0,0);
  gotoxy(1,WinH-10);col(14,7);
  wcn('Working 14 hours a day in the core of some dusty, smelly mine');
  wcn('is not your idea of the perfect lifestyle.');
  wcn('Barre-An is a dust ball in space, its only salvation being that it is');
  wcn('rich in precious barre-an metal.  Or used to be.  Nowadays the mines');
  wcn('don''t seem so generous, which is why you''re looking for a more');
  wcn('profitable venture.');
  wcn('A break, that''s all you ask for, maybe today you figure...');
  writeln;
 end; { Init2 }

procedure Init3;
 begin
  Line    :='';
  Again   :='z';
  LastNoun:='mug';
  Vb      :=Null;
  Prm     :=8;
  Sc      :=0;
  Tic     :=0;
  PStat   :=[6];
  Events  :=[];
  for o   :=1 to MMax do r[o]:=Null;
  Inv     :=[3,8];
  Mov     :=[1..29];
  AlienRm :=Null;
  FriendRm:=91;
  Brief   :=[];
  Wear    :=[];
  MugCon  :=99;
  FoodCon :=4;
  SatchCon:=6;
  HolstCon:=Null;
  NicheCon:=Null;
  SinkRm  :=Null;
  PyraCon :=Null;
  Serum   :=Null;
  HingeCon:=9;
  PodumCon:=18;
  RobotCon:=12;
  Socket  :=[22..25];
  CodeSet :=7;
  ScrnSet :=1;
  Floor   :=1;
  Region  :=1;
  TFlag   :=1;
  Old     :=250;
  Old2    :=Old;
  Maze    :=true;
  Drive   :='A';
  StoreR:=-1;StoreS:=-1;StoreL:=-1;StoreC:=-1;{ Stores Last Read File Number }
  Dir[1]:='NORTH';Dir[2]:='SOUTH';Dir[3]:='EAST';Dir[4]:='WEST';
  Dir[5]:='NORTHEAST';Dir[6]:='NORTHWEST';
  Dir[7]:='SOUTHEAST';Dir[8]:='SOUTHWEST';
  m[1]:=VMax;m[2]:=NMax;m[3]:=PMax;
  for x   :=1 to TMax do T[x]:=Null;
  T[2]    :=0;
  T[3]    :=70;  { Hunger }
  T[4]    :=26;  { Thirst }
  T[5]    :=85; { Sleep (No relation to the T[2] sleep timer!) }
  NoNounOnly  :=[1..8,15,16,30,77..79,82,85..87,95];
  OneNounMaybe:=[9..14,25,32,46,59..60,66..71,80,81,90,91];
  ToNounOnly  :=[33,49,64,88,93];
  ToNounMaybe :=[19,41..44,48,50,53,54,74..76,89,90,92,94];
  { NOTE:  All other verbs would be OneNounOnly! }
  nSetActiveWin(win2);gotoxy(1,WinH-1);
 end; { Init3 }

procedure Save;
  label JUMPABORT,JUMPBACK;
  {var   DiskTest:file;}
 begin SF; JUMPBACK: nosound; for x:=1 to 20 do writeln;
  Bor(2,7);CFlag:=Drive;Cur(2);
  gotoxy(1,2);
  { remove floppy drive selection
  write('Which disk drive (default ',Up(Drive),':)? ');
  col(14,15);buflen:=1;readline(Drive);col(11,7);
  Drive:=upcase(Drive);if not(Drive in['A','B'])then Drive:=CFlag;}
  gotoxy(1,5);
  writeln('Make sure your SAVE/RESTORE disk is in disk drive ',up(Drive),':');
  writeln;writeln;
  write('SAVE under what file name (''',up('/'),''' aborts SAVE)? ');
  buflen:=8;col(14,15);readline(input);col(11,7);
  Cur(3);
  while pos(' ',input)>0 do delete(input,pos(' ',input),1);
  while pos('.',input)>0 do delete(input,pos('.',input),1);
  while pos(':',input)>0 do delete(input,pos(':',input),1);
  if pos('/',input)>0 then
   begin writeln;writeln(up('SAVE ABORTED'));goto JUMPABORT;end;
  LowerCase(input);
  if(pos('list',input)>0)or(pos('dir',input)>0)or(pos('file',input)>0)then
   begin Directory;goto JUMPBACK;end;
  if length(input)=0 then input:='LASTSAVE';writeln;writeln;
  writeln('The game file ',Up(Input),' is now being saved on disk drive ',
           up(Drive),':...');
  { don't put Drive
  input:=Drive+':'+input;}
  assign(Objects,input+'.sm1');
  rewrite(Objects);
  for x:=0 to RMax do write(Objects,L[x]);
  close(Objects);
  assign(Things,input+'.sm2');
  rewrite(Things);
  write(Things,Prm,Region,MugCon,FoodCon,SatchCon,NicheCon,PyraCon,
               HingeCon,PodumCon,AlienRm,FriendRm,SinkRm,Serum,TFlag,
               RobotCon,CodeSet,ScrnSet,HolstCon);
  for x:=1 to MMax do write(Things,R[x]);
  close(Things);
  assign(Timers,input+'.sm3');
  rewrite(Timers);
  write(Timers,Tic,Sc,RC,Floor);
  for x:=1 to TMax do write(Timers,T[x]);
  close(Timers);
  with SetSave do
   begin aInv:=Inv;aPStat:=PStat;aEvents:=Events;
    aSocket:=Socket;aWear:=Wear;end;
  assign(Sets,input+'.sm4');
  rewrite(Sets);
  write(Sets,SetSave);
  close(Sets);
  writeln;writeln;delete(input,1,2);
  writeln('Your present game location is now SAVED under the name ',
           up(input),'.');
  writeln; JUMPABORT: writeln;
  { remove checking SUPERNOVA floppy disk
  writeln('Please make sure the SUPERNOVA disk is in drive ',up(Log),':');
  writeln;writeln;Pause;
  assign(DiskTest,'Nova.com');}
  {$I-}
  {reset(DiskTest);}
  {$I+}
  {if IOResult<>0 then
   begin Col(15,15);close(DiskTest);write(^g);goto JUMPABORT;end;
  close(DiskTest);} Col(11,7);
  Bor(0,0);Line:='l';
  case Region of 4:sound(20);5:sound(60)end
 end; { SAVE }

procedure Restore;
  label JUMP,JUMPBACK;
  {var   DiskTest:file;}
 begin SF; JUMPBACK: nosound; for x:=1 to 25 do writeln;
  Bor(6,7);CFlag:=Drive;Cur(2);
  gotoxy(1,2);
  { remove floppy disk selection
  write('Which disk drive (default ',Up(Drive),':)? ');
  col(14,15);buflen:=1;readline(Drive);col(11,7);
  Drive:=upcase(Drive);if not(Drive in['A','B'])then Drive:=CFlag;}
  gotoxy(1,5);
  writeln('Make sure your SAVE/RESTORE disk is in disk drive ',up(Drive),':');
  writeln;writeln;
  write('RESTORE from what file name (''',up('/'),''' aborts RESTORE)? ');
  buflen:=8;col(14,15);readline(input);col(11,7);
  Cur(3);
  while pos(' ',input)>0 do delete(input,pos(' ',input),1);
  while pos('.',input)>0 do delete(input,pos('.',input),1);
  while pos(':',input)>0 do delete(input,pos(':',input),1);
  if pos('/',input)>0 then
   begin writeln;writeln(up('RESTORE ABORTED'));goto JUMP;end;
  LowerCase(input);
  if(pos('list',input)>0)or(pos('dir',input)>0)or(pos('file',input)>0)then
   begin Directory;goto JUMPBACK;end;
  if length(input)=0 then input:='LASTSAVE';writeln;writeln;
  writeln('The game file ',Up(Input),' is now being restored from drive ',
           up(Drive),':...');
  { Don't put Drive
  input:=Drive+':'+input;}
  assign(Objects,input+'.sm1');
  {$I-}
  reset(Objects);
  {$I+}
  if IOResult<>0 then
   begin close(Objects);col(12,15);writeln;writeln;delete(input,1,2);
    for x:=1 to length(input) do input[x]:=upcase(input[x]);
    wCn('The file '+input+' does not exist on your SAVE/RESTORE disk!');
    writeln(^g);delay(2000);col(11,7);goto JUMPBACK;
   end;
  reset(Objects);
  for x:=0 to RMax do read(Objects,L[x]);
  close(Objects);
  assign(Things,input+'.sm2');
  reset(Things);
  read(Things,Prm,Region,MugCon,FoodCon,SatchCon,NicheCon,PyraCon,
              HingeCon,PodumCon,AlienRm,FriendRm,SinkRm,Serum,TFlag,
              RobotCon,CodeSet,ScrnSet,HolstCon);
  for x:=1 to MMax do read(Things,R[x]);
  close(Things);
  assign(Timers,input+'.sm3');
  reset(Timers);
  read(Timers,Tic,Sc,RC,Floor);
  for x:=1 to TMax do read(Timers,T[x]);
  close(Timers);
  assign(Sets,input+'.sm4');
  reset(Sets);
  read(Sets,SetSave);
  close(Sets);
  with SetSave do
   begin Inv:=aInv;PStat:=aPStat;Events:=aEvents;
    Socket:=aSocket;Wear:=aWear;end;
  Add(126);
  writeln;writeln;delete(input,1,2);
  writeln('Your present game location is now RESTORED from the name ',
           up(input),'.');
  writeln; JUMP: writeln;
  { remove checking SUPERNOVA floppy disk
  writeln('Please make sure the SUPERNOVA disk is in drive ',up(Log),':');
  writeln;writeln;Pause;
  assign(DiskTest,'Nova.com');}
  {$I-}
  {reset(DiskTest);}
  {$I+}
  {if IOResult<>0 then
   begin Col(15,15);close(DiskTest);write(^g);goto JUMP;end;
  close(DiskTest);} Col(11,7);
  Bor(0,0);
  case Region of 4:sound(20);5:sound(60)end;
  if Region>1 then
   begin
    n[84]:='reactor regulat\';
    n[126]:='hinged mouth\mouth\hinge\';
   end
   else
    begin
     n[84]:='middle table\middle\';
     n[126]:='bar\';
    end;
  if en(34)then n[18]:='glass ball\ball\glass\'
   else n[18]:='dusty ball\ball\dusty\';
  if Prm>79 then
   begin
    n[40]:='sockets\socket\';
    n[82]:='laser beam\beam\laser\';
    n[110]:='speaker\';
   end else
   begin
    n[40]:='cyan button\cyan\';
    n[82]:='solar map\map\solar\drawing\';
    n[110]:='keyhole\';
   end;
   Min(128);Line:='l';
 end; { RESTORE }

procedure MoreThanOne;
 begin
  if((N1=58)or(58 in NounSet)or(N2=58))and Here(3) and Here(4) then
   begin Cur(2);
    repeat write('Which one, the R)usty or S)hiney key? ');
     CFlag:=Readkey;writeln(CFlag);writeln until upcase(CFlag) in ['R','S'];
    case upcase(CFlag) of 'R':x:=3; 'S':x:=4 end;
    if N1=58 then N1:=x;
    if N2=58 then N2:=x;
    if 58 in NounSet then begin NounSet:=NounSet-[58];NounSet:=NounSet+[x] end;
   end;
  if((N1=86)or(86 in NounSet)or(N2=86))and(Prm=8)then
   begin Cur(2);
    repeat write('Which one, the W)estern, M)iddle or E)astern table? ');
     CFlag:=ReadKey;writeln(CFlag);
     writeln until upcase(CFlag) in ['W','M','E'];
    case upcase(CFlag) of 'W':x:=83; 'M':x:=84; 'E':x:=85 end;
    if N1=86 then N1:=x;
    if N2=86 then N2:=x;
    if 86 in NounSet then begin NounSet:=NounSet-[86];NounSet:=NounSet+[x] end;
   end;
  if((N1=44)or(44 in NounSet)or(N2=44))and(Prm in[1,70])and(Vb<>28)then
   begin Cur(2);
    repeat write('Which one, the T)an, P)urple or C)yan button? ');
     CFlag:=ReadKey;writeln(CFlag);
     writeln until upcase(CFlag) in ['T','P','C'];
    case upcase(CFlag) of 'T':x:=41; 'P':x:=43; 'C':x:=40 end;
    if N1=44 then N1:=x;
    if N2=44 then N2:=x;
    if 44 in NounSet then begin NounSet:=NounSet-[44];NounSet:=NounSet+[x] end;
   end;
  if(N1=58)and Here(3)and not(Here(4))then N1:=3;
  if(N2=58)and Here(3)and not(Here(4))then N2:=3;
  if(58 in NounSet)and Here(3)and not(Here(4))then
    begin NounSet:=NounSet-[58];NounSet:=NounSet+[3] end;
  if(N1=58)and Here(4)and not(Here(3))then N1:=4;
  if(N2=58)and Here(4)and not(Here(3))then N2:=4;
  if(58 in NounSet)and Here(4)and not(Here(3))then
    begin NounSet:=NounSet-[58];NounSet:=NounSet+[4] end;
end; { MoreThanOne }


function Print(Word:Str29):Str1;
 begin Print:='';writeln('--you can''t use the word ',Up(Word),' here.')end;

procedure Parser_Syntax(var Input:Str130);
   label JUMP1, JUMP2;
begin
 Word:=''; Md:=Null; Num:=Null; Code:=Null;
 Vb:=Null; N1:=Null; N2:=Null; NounSet:=[];
JUMP1:  { Used if the player forgets the first noun. }
 FFlag:=Null; Pr:=Null;
JUMP2:  { Used if the player forgets the second noun or preposition. }
 EFlag:=Null;
 FindMood(input,Word,Md);
 if(length(input)>0)then
  begin
   FindMood(input,Word,Num);
   if(Num=Null)then
    begin
     FindWord(input,Vb,Word,1);
     if(Vb<>Null)then
      if(length(input)=0)then
       begin
        if(Vb in NoNounOnly)or(Vb in OneNounMaybe)then EFlag:=Legal;
        if EFlag<>Legal then
         begin
          if(Vb=35)and here(35)then begin EFlag:=Legal;N1:=35;NStr:='seat';end;
          if(Vb=47)and here(6)then begin EFlag:=Legal;N1:=6;end;
          if(Vb=62)and here(80)then begin EFlag:=Legal;N1:=80;end;
          if(Vb=65)and here(124)then begin EFlag:=Legal;N1:=124;end;
          if EFlag<>Legal then EFlag:=4
         end
       end
      else
       if(Vb in NoNounOnly)then Dictionary(3,9)
       else
        if not(Vb in[17,18,37,39])then       { get,drop and but branch-off }
         if not(Vb in[25,32,56,66..69,71,80,81])then { characters and type }
          begin
           if(Vb<>FFlag)then FindWord(input,N1,Word,2);
           if(N1<>Null)then LastNoun:=FN(N1);
           if(N1<>Null)then
            if(Word<>'all')then
             if(length(input)=0)then
              if(Vb in ToNounOnly)then
               if(VStr='fill')and(Prm=SinkRm)and(N1=29)then
                  begin N2:=79;Pr:=6;EFlag:=Legal;end else
               if(Vb=64)and(Prm=8)and(N1 in[29,99])and(not en(21))and
                  here(8)then begin Pr:=6;N2:=8;EFlag:=Legal;end else
               if(Vb=88)and(Prm in[9..11])and(N1=56)and here(3)then
                  begin Pr:=6;N2:=3;EFlag:=Legal;end
               else EFlag:=15
              else EFlag:=Legal
             else
              if(Vb in ToNounMaybe)or(Vb in ToNounOnly)then
               begin
                FindWord(input,Pr,Word,3);
                if(Pr<>Null)then
                 if(length(input)=0)then
                   if(Vb=50)and(Pr in[1,9])then EFlag:=Legal
                   else EFlag:=6
                 else
                  if(Vb<>50)then  { branch for turning dials }
                   begin
                    FindWord(input,N2,Word,2);
                    if(N2<>Null)then
                     if(Word<>'all')then
                      if(length(input)=0)then EFlag:=Legal
                      else Dictionary(12,9)
                     else EFlag:=16
                    else Dictionary(11,2)
                   end
                  else
                   begin
                    val(input,Code,testc);
                    if(testc=0)then EFlag:=Legal
                    else begin delete(input,1,testc-1);Dictionary(14,9);end;
                   end
                else Dictionary(9,3)
               end
              else
               begin Dictionary(3,9);if(List=2)then EFlag:=8;end
             else EFlag:=16
           else Dictionary(10,2)
          end
         else { Special case for TYPE, characters, etc. }
          begin
           QFormat(input);
           EFlag:=Legal
          end { of Special case for SAY, TYPE, etc. }
        else  { Special case for GET and DROP }
         while EFlag=Null do
          begin N1:=Null;
           FindWord(input,N1,Word,2);
           if(N1<>Null)then LastNoun:=FN(N1);
           if(N1<>Null)then
            if not(N1 in NounSet)then
             begin
              NounSet:=NounSet+[N1];
              if(length(input)=0)then EFlag:=Legal
             end
            else EFlag:=13
           else Dictionary(10,2)
          end { of Special case for GET and DROP }
     else Dictionary(7,1)
    end
   else EFlag:=2
  end
 else EFlag:=1;
 if EFlag<>Legal then
  begin Line:='';play(199,199,55);delay(70);play(60,60,55)end;
 case EFlag of
 1:RL(186);
 2:writeln('The word ',up(Word),' is too many adverbs.');
 3:write('Illegal input',Print(Word));
 4:if(Vb=56)then RL(187)
   else
    begin
     write('Noun missing--');
     case Vb of
      35,62:writeln('what do you want to ',up(Word),' on?');
      65:writeln('what do you want to ',up(Word),' to?')
      else writeln('what do you want to ',up(Word),'?');
     end;
     PlayerInput(line);
     if(length(input)>0)then goto JUMP1;
    end;
 5:if(length(Word)>1)then
    writeln('The word ',up(Word),' is not used in this adventure.')
   else
    writeln('The letter ',up(Word),' is not used as shorthand in this parser.');
 6:begin
    writeln('Noun missing--what do you want to ',up(VStr),up(' the '),
            up(NStr),' ',up(PStr),'?');
    PlayerInput(line); FFlag:=Vb;
    if(length(input)>0)then goto JUMP2;
   end;
 7:write('Verb missing',Print(Word));
 8:RL(188);
 9:write('Preposition expected',Print(Word));
 10:write('Noun expected',Print(Word));
 11:write('Indirect noun expected',Print(Word));
 12:write('No more input expected',Print(Word));
 13:writeln('Illegal noun used--',up(Word),' referenced more than once.');
 14:write('Number expected',Print(Word));
 15:begin
     write('Preposition and noun missing--');
     if(Vb in[33,48])then
      writeln('where do you want to ',up(VStr),' the ',up(NStr),'?') else
     if Vb=49 then
      begin Pr:=1;
       writeln('who do you want to ',up(VStr),' the ',up(NStr),' to?')end
     else begin Pr:=6;
       writeln('what do you want to ',up(VStr),' the ',up(NStr),' with?')end;
     PlayerInput(line); FFlag:=Vb;
     if(length(input)>0)then goto JUMP2;
    end;
 16:RL(189);
 17:RL(576)
 end;
end; { Parser Syntax }

procedure MC(WhichChar,WatchRoom,ToRoom:byte;MessageNum:Integer);
    { WhichChar refers to the character(s) being moved.               }
    { WatchRoom is the room the player must be in to see the responce.}
    { ToRoom is the room the character(s) move to.                    }
    { MessageNum is the message that is written if the player sees.   }
 begin
  if(Prm=WatchRoom)then RS(MessageNum);
  case WhichChar of     { 1 = Aliens,  2 = Scientist }
   1:begin
      L[AlienRm]:=L[AlienRm]-[124];AlienRm:=ToRoom;
      L[AlienRm]:=L[AlienRm]+[124]
     end;
   2:begin
      L[FriendRm]:=L[FriendRm]-[123];FriendRm:=ToRoom;
      L[FriendRm]:=L[FriendRm]+[123]
     end
  end;
  SFlag:=false;
 end;

procedure Van(o:byte);
 begin
  Inv:=Inv-[o];
  r[o]:=Null;
  L[Prm]:=L[Prm]-[o];
  if o in Wear then Wear:=Wear-[o];
  if o=SatchCon then SatchCon:=Null;
  if o=MugCon then MugCon:=Null;
  if o=16 then Min(6);
  if o=NicheCon then NicheCon:=Null;
  if o=PyraCon then PyraCon:=Null;
  if o=HingeCon then HingeCon:=Null;
  if o=PodumCon then PodumCon:=Null;
  if o=16 then begin Min(37);Min(6)end;
  if o=RobotCon then RobotCon:=Null;
  if o in Socket then Socket:=Socket-[o];
  if o=HolstCon then HolstCon:=Null
 end;

procedure Crazy;
 begin SF; RL(random(7)+127)end;

procedure NoSense;
 begin RL(190) end;

procedure Say(What1,What2:Str29);
 begin SF; writeln('The ',What1,' is already ',What2,'.') end;

{******************* END OF PARSER AND MISC. PROCEDURES *********************}
