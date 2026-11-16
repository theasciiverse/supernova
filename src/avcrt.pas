{ avcrt: the screen and keyboard for the Asciiverse editions of Scott
  Miller's text adventures, a stand-in for Turbo Pascal's Crt unit.

  The games were written for the IBM PC's 80x25 text screen. This unit keeps
  the Crt calls they make (Window, GotoXY, TextColor, ReadKey and the rest)
  but draws on any terminal, of any size, on Linux, macOS and Windows:

  - the screen is the terminal's own size, kept in a grid of PC characters
    (code page 437) and drawn as UTF-8 with ANSI colours;
  - text written to a window is word-wrapped at its right edge;
  - lines that scroll off the top of the main text window are kept, so the
    player can page back (Shift+PgUp, Shift+PgDn) and so a resized terminal
    can lay the whole story out again at the new width;
  - ReadLn and AvReadLine give a line editor with history;
  - the PC speaker is silent (Sound and NoSound do nothing);
  - an optional session log (AvLogOpen).

  Copyright (C) 2026 Asciiverse

  This file is free software: you may copy, redistribute and/or modify it
  under the terms of the GNU Affero General Public License as published by
  the Free Software Foundation, either version 3 of the License, or (at your
  option) any later version.

  This file is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public
  License for more details.

  You should have received a copy of the GNU Affero General Public License
  along with this program; if not, see https://gnu.org/licenses }

unit avcrt;

{$mode objfpc}{$H+}

interface

const
  BW40 = 0; C40 = 1; BW80 = 2; C80 = 3; Mono = 7;
  Black = 0; Blue = 1; Green = 2; Cyan = 3; Red = 4; Magenta = 5; Brown = 6;
  LightGray = 7; DarkGray = 8; LightBlue = 9; LightGreen = 10;
  LightCyan = 11; LightRed = 12; LightMagenta = 13; Yellow = 14; White = 15;
  Blink = 128;

  { extended key codes ReadKey returns after #0, as on the PC }
  kbHome = 71; kbUp = 72; kbPgUp = 73; kbLeft = 75; kbRight = 77;
  kbEnd = 79; kbDown = 80; kbPgDn = 81; kbIns = 82; kbDel = 83;
  kbF1 = 59; kbF10 = 68;
  { Shift or Ctrl with PgUp and PgDn: paging back through the story }
  kbBackUp = 132; kbBackDown = 118;

var
  TextAttr: Byte = 7;
  CheckBreak: Boolean = True;
  ScreenWidth: Integer = 80;
  ScreenHeight: Integer = 25;
  { called after the terminal changed size, before the main window's text
    is laid out again: the game sets its windows (AvSetMainWindow) and
    redraws whatever surrounds them }
  AvOnResize: procedure = nil;

procedure ClrScr;
procedure ClrEol;
procedure GotoXY(X, Y: Integer);
function WhereX: Integer;
function WhereY: Integer;
procedure TextColor(Color: Byte);
procedure TextBackground(Color: Byte);
procedure Window(X1, Y1, X2, Y2: Integer);
procedure DelLine;
procedure InsLine;
function ReadKey: Char;
function KeyPressed: Boolean;
procedure Delay(MS: LongInt);
procedure Sound(Hz: LongInt);
procedure NoSound;
procedure TextMode(Mode: Integer);
procedure CursorOn;
procedure CursorOff;
procedure CursorBig;

{ the main text window: the one whose lines are kept for paging back and
  laid out again after a resize; also makes it the current window }
procedure AvSetMainWindow(X1, Y1, X2, Y2: Integer);
{ word wrap for text written to the current window (on by default) }
procedure AvSetWrap(On: Boolean);
{ a line editor at the cursor: Left, Right, Home, End, Backspace, Delete,
  Ctrl+U, Up and Down for earlier lines when History is set; Enter ends it }
function AvReadLine(MaxLen: Integer; History: Boolean): string;
{ pages the main window back or forward when Key is one of the paging keys
  (kbBackUp, kbBackDown, and kbPgUp, kbPgDn when Plain is set); returns
  False for any other key }
function AvPageKey(Key: Byte; Plain: Boolean): Boolean;
{ writes a text from the game's data files, A then B, ending the line.
  The texts were laid out for a window Width columns wide by padding
  lines with spaces; the padding is taken out, so the text wraps at the
  window's own width, while the breaks the author meant (an indented line,
  an empty line, a short line well before the edge) are kept }
procedure AvShowText(const A, B: AnsiString; Width: Integer);
{ the folder beside the program, where its data files are }
function AvDataDir: string;
{ the player's state folder for the given title id, made if needed:
  $XDG_STATE_HOME/<id> or ~/.local/state/<id>, %LOCALAPPDATA%\<id> }
function AvStateDir(const Id: string): string;
{ opens the session log when the environment variable EnvName is set:
  <state folder>/<FileName>, appended to }
procedure AvLogOpen(const EnvName, StateDir, FileName: string);
procedure AvLog(const S: string);
function AvLogging: Boolean;
{ runs the game again from the start, in place of this process }
procedure AvRestart;
{ the current window's width and height }
function AvWindowWidth: Integer;
function AvWindowHeight: Integer;
{ a line to print on the terminal's own screen when the game ends }
procedure AvFarewell(const S: string);
{ restores the terminal and ends the program }
procedure AvQuit(Code: Integer);
{ restores the terminal, prints Msg and ends the program with code 1 }
procedure AvFatal(const Msg: string);
{ true when NO_COLOR is set: the player asked for no colour }
function AvNoColor: Boolean;

implementation

uses
{$IFDEF UNIX}
  BaseUnix, TermIO, Unix,
{$ENDIF}
{$IFDEF WINDOWS}
  Windows,
{$ENDIF}
  SysUtils;

type
  TCell = record
    Ch: Char;
    Attr: Byte;
  end;
  TRow = record
    Cells: array of TCell;
    Len: Integer;      { cells written from the window's left edge }
    Wrapped: Boolean;  { the line goes on in the next row (soft wrap) }
  end;
  TStoredRow = record
    Text: AnsiString;  { the characters, one per cell }
    Attrs: AnsiString; { one attribute byte per cell }
    Wrapped: Boolean;
  end;

const
  { code page 437, 128 to 255, as Unicode }
  CP437: array[128..255] of Word = (
    $00C7, $00FC, $00E9, $00E2, $00E4, $00E0, $00E5, $00E7,
    $00EA, $00EB, $00E8, $00EF, $00EE, $00EC, $00C4, $00C5,
    $00C9, $00E6, $00C6, $00F4, $00F6, $00F2, $00FB, $00F9,
    $00FF, $00D6, $00DC, $00A2, $00A3, $00A5, $20A7, $0192,
    $00E1, $00ED, $00F3, $00FA, $00F1, $00D1, $00AA, $00BA,
    $00BF, $2310, $00AC, $00BD, $00BC, $00A1, $00AB, $00BB,
    $2591, $2592, $2593, $2502, $2524, $2561, $2562, $2556,
    $2555, $2563, $2551, $2557, $255D, $255C, $255B, $2510,
    $2514, $2534, $252C, $251C, $2500, $253C, $255E, $255F,
    $255A, $2554, $2569, $2566, $2560, $2550, $256C, $2567,
    $2568, $2564, $2565, $2559, $2558, $2552, $2553, $256B,
    $256A, $2518, $250C, $2588, $2584, $258C, $2590, $2580,
    $03B1, $00DF, $0393, $03C0, $03A3, $03C3, $00B5, $03C4,
    $03A6, $0398, $03A9, $03B4, $221E, $03C6, $03B5, $2229,
    $2261, $00B1, $2265, $2264, $2320, $2321, $00F7, $2248,
    $00B0, $2219, $00B7, $221A, $207F, $00B2, $25A0, $00A0);
  { the PC's colour numbers to ANSI's }
  DosToAnsi: array[0..7] of Byte = (0, 4, 2, 6, 1, 5, 3, 7);
  MaxStored = 3000;

var
  Grid: array of TRow;
  CurX, CurY: Integer;
  WX1, WY1, WX2, WY2: Integer;
  MX1, MY1, MX2, MY2: Integer;        { the main window }
  HasMain: Boolean = False;
  PendingWrap: Boolean = False;
  SkipSpaces: Boolean = False;
  WrapOn: Boolean = True;
  CursorWanted: Boolean = True;
  Stored: array of TStoredRow;        { rows scrolled off the main window }
  StoredCount: Integer = 0;
  OutBuf: AnsiString = '';
  TermAttr: Integer = -1;             { the attribute the terminal has now }
  TermX: Integer = -1;                { where the terminal's cursor is }
  TermY: Integer = -1;
  KeyQ: AnsiString = '';              { keys read but not yet returned }
  History: array of AnsiString;
  LogFile: Text;
  LogOpen: Boolean = False;
  LogLine: AnsiString = '';
  Started: Boolean = False;
  Restored: Boolean = False;
  Paged: Integer = 0;                 { rows paged back, 0 when not }
  Farewell: AnsiString = '';
  EditActive: Boolean = False;        { the line editor's text, taken out }
  EditX, EditY, EditLen: Integer;     { of the grid before a resize }
{$IFDEF UNIX}
  SavedTios: Termios;
  HaveTios: Boolean = False;
{$ENDIF}
{$IFDEF WINDOWS}
  HOut, HIn: THandle;
  SavedOutMode, SavedInMode: DWORD;
  SavedCP: UINT;
{$ENDIF}

{ ---------------------------------------------------------------- output }

procedure RawWrite(const S: AnsiString);
{$IFDEF WINDOWS}
var
  Done: DWORD;
{$ENDIF}
begin
  if S = '' then Exit;
{$IFDEF UNIX}
  fpWrite(1, S[1], Length(S));
{$ENDIF}
{$IFDEF WINDOWS}
  WriteFile(HOut, S[1], Length(S), Done, nil);
{$ENDIF}
end;

procedure Flush;
begin
  if OutBuf <> '' then
  begin
    RawWrite(OutBuf);
    OutBuf := '';
  end;
end;

procedure Emit(const S: AnsiString);
begin
  OutBuf := OutBuf + S;
  if Length(OutBuf) > 16384 then Flush;
end;

function Utf8Of(C: Char): AnsiString;
var
  U: Word;
begin
  if Ord(C) < 32 then
    Result := ' '
  else if Ord(C) < 127 then
    Result := C
  else if Ord(C) = 127 then
    Result := #$E2#$8C#$82
  else
  begin
    U := CP437[Ord(C)];
    if U < $800 then
      Result := Chr($C0 or (U shr 6)) + Chr($80 or (U and $3F))
    else
      Result := Chr($E0 or (U shr 12)) + Chr($80 or ((U shr 6) and $3F)) +
        Chr($80 or (U and $3F));
  end;
end;

procedure TermGoto(X, Y: Integer);
begin
  if (X <> TermX) or (Y <> TermY) then
  begin
    Emit(#27'[' + IntToStr(Y) + ';' + IntToStr(X) + 'H');
    TermX := X;
    TermY := Y;
  end;
end;

procedure TermColor(A: Byte);
var
  Fg, Bg: Integer;
  S: AnsiString;
begin
  if A = TermAttr then Exit;
  Fg := A and 15;
  Bg := (A shr 4) and 7;
  S := #27'[0;';
  if Fg < 8 then
    S := S + IntToStr(30 + DosToAnsi[Fg])
  else
    S := S + IntToStr(90 + DosToAnsi[Fg - 8]);
  S := S + ';' + IntToStr(40 + DosToAnsi[Bg]);
  if (A and 128) <> 0 then S := S + ';5';
  Emit(S + 'm');
  TermAttr := A;
end;

procedure PaintCell(X, Y: Integer);
begin
  TermGoto(X, Y);
  TermColor(Grid[Y - 1].Cells[X - 1].Attr);
  Emit(Utf8Of(Grid[Y - 1].Cells[X - 1].Ch));
  Inc(TermX);
  if TermX > ScreenWidth then TermX := -1; { unsure after the last column }
end;

procedure PaintRow(Y, XFrom, XTo: Integer);
var
  X: Integer;
begin
  for X := XFrom to XTo do PaintCell(X, Y);
end;

procedure PaintAll;
var
  Y: Integer;
begin
  Emit(#27'[0m'#27'[2J');
  TermAttr := -1;
  for Y := 1 to ScreenHeight do PaintRow(Y, 1, ScreenWidth);
end;

procedure SetCell(X, Y: Integer; C: Char; A: Byte);
begin
  Grid[Y - 1].Cells[X - 1].Ch := C;
  Grid[Y - 1].Cells[X - 1].Attr := A;
end;

procedure BlankRow(Y, XFrom, XTo: Integer; A: Byte);
var
  X: Integer;
begin
  for X := XFrom to XTo do SetCell(X, Y, ' ', A);
end;

{ the grid, made for the screen size: old contents are kept where they fit }
procedure SizeGrid(W, H: Integer);
var
  Old: array of TRow;
  Y, X: Integer;
begin
  Old := Grid;
  Grid := nil;
  SetLength(Grid, H);
  for Y := 0 to H - 1 do
  begin
    SetLength(Grid[Y].Cells, W);
    for X := 0 to W - 1 do
    begin
      Grid[Y].Cells[X].Ch := ' ';
      Grid[Y].Cells[X].Attr := 7;
    end;
    Grid[Y].Len := 0;
    Grid[Y].Wrapped := False;
    if Y < Length(Old) then
    begin
      for X := 0 to W - 1 do
        if X < Length(Old[Y].Cells) then Grid[Y].Cells[X] := Old[Y].Cells[X];
    end;
  end;
  ScreenWidth := W;
  ScreenHeight := H;
end;

{ -------------------------------------------------------------- terminal }

procedure TermSize(out W, H: Integer);
{$IFDEF UNIX}
var
  WS: TWinSize;
{$ENDIF}
{$IFDEF WINDOWS}
var
  Info: TConsoleScreenBufferInfo;
{$ENDIF}
begin
  W := 0;
  H := 0;
{$IFDEF UNIX}
  if fpIoctl(1, TIOCGWINSZ, @WS) = 0 then
  begin
    W := WS.ws_col;
    H := WS.ws_row;
  end;
{$ENDIF}
{$IFDEF WINDOWS}
  if GetConsoleScreenBufferInfo(HOut, Info) then
  begin
    W := Info.srWindow.Right - Info.srWindow.Left + 1;
    H := Info.srWindow.Bottom - Info.srWindow.Top + 1;
  end;
{$ENDIF}
  if W < 20 then W := 80;
  if H < 10 then H := 25;
  if W > 250 then W := 250;
  if H > 200 then H := 200;
end;

procedure StartTerminal;
{$IFDEF UNIX}
var
  T: Termios;
{$ENDIF}
begin
  if Started then Exit;
  Started := True;
{$IFDEF UNIX}
  if TCGetAttr(0, SavedTios) = 0 then
  begin
    HaveTios := True;
    T := SavedTios;
    CFMakeRaw(T);
    T.c_oflag := T.c_oflag or OPOST or ONLCR;
    TCSetAttr(0, TCSANOW, T);
  end;
{$ENDIF}
{$IFDEF WINDOWS}
  HOut := GetStdHandle(STD_OUTPUT_HANDLE);
  HIn := GetStdHandle(STD_INPUT_HANDLE);
  GetConsoleMode(HOut, SavedOutMode);
  GetConsoleMode(HIn, SavedInMode);
  SetConsoleMode(HOut, SavedOutMode or ENABLE_PROCESSED_OUTPUT or $0004);
  SetConsoleMode(HIn, ENABLE_WINDOW_INPUT or ENABLE_EXTENDED_FLAGS);
  SavedCP := GetConsoleOutputCP;
  SetConsoleOutputCP(65001);
{$ENDIF}
  { the alternate screen, no wheel-to-arrow translation, cursor hidden }
  RawWrite(#27'[?1049h'#27'[?1007l'#27'[?25l'#27'[0m'#27'[2J');
end;

procedure RestoreTerminal;
begin
  if not Started or Restored then Exit;
  Restored := True;
  Flush;
  RawWrite(#27'[0m'#27'[?25h'#27'[?1049l');
  if Farewell <> '' then RawWrite(Farewell);
{$IFDEF UNIX}
  if HaveTios then TCSetAttr(0, TCSANOW, SavedTios);
{$ENDIF}
{$IFDEF WINDOWS}
  SetConsoleMode(HOut, SavedOutMode);
  SetConsoleMode(HIn, SavedInMode);
  SetConsoleOutputCP(SavedCP);
{$ENDIF}
end;

procedure SleepMS(MS: LongInt);
begin
  if MS <= 0 then Exit;
  SysUtils.Sleep(MS);
end;

{ -------------------------------------------------------------- the log }

function Stamp: string;
begin
  Result := FormatDateTime('hh:nn:ss.zzz', Now);
end;

procedure AvLogOpen(const EnvName, StateDir, FileName: string);
begin
  if GetEnvironmentVariable(EnvName) = '' then Exit;
  AssignFile(LogFile, IncludeTrailingPathDelimiter(StateDir) + FileName);
  {$I-}
  if FileExists(IncludeTrailingPathDelimiter(StateDir) + FileName) then
    Append(LogFile)
  else
    Rewrite(LogFile);
  {$I+}
  if IOResult <> 0 then Exit;
  LogOpen := True;
  WriteLn(LogFile, Stamp, ' session start, ', FormatDateTime('yyyy-mm-dd', Now));
  System.Flush(LogFile);
end;

procedure AvLog(const S: string);
begin
  if not LogOpen then Exit;
  WriteLn(LogFile, Stamp, ' ', S);
  System.Flush(LogFile);
end;

function AvLogging: Boolean;
begin
  Result := LogOpen;
end;

procedure LogChar(C: Char);
begin
  if not LogOpen then Exit;
  if C = #10 then
  begin
    AvLog('out: ' + TrimRight(LogLine));
    LogLine := '';
  end
  else if C >= ' ' then
  begin
    if C < #127 then LogLine := LogLine + C else LogLine := LogLine + Utf8Of(C);
  end;
end;

{ ----------------------------------------------------- stored story rows }

procedure StoreRow(Y: Integer);
var
  R: TStoredRow;
  X, N: Integer;
begin
  N := Grid[Y - 1].Len;
  if N > MX2 - MX1 + 1 then N := MX2 - MX1 + 1;
  SetLength(R.Text, N);
  SetLength(R.Attrs, N);
  for X := 1 to N do
  begin
    R.Text[X] := Grid[Y - 1].Cells[MX1 + X - 2].Ch;
    R.Attrs[X] := Chr(Grid[Y - 1].Cells[MX1 + X - 2].Attr);
  end;
  R.Wrapped := Grid[Y - 1].Wrapped;
  if StoredCount >= Length(Stored) then
  begin
    if Length(Stored) < MaxStored then
      SetLength(Stored, Length(Stored) + 256)
    else
    begin
      { drop the oldest quarter }
      for X := 0 to StoredCount - MaxStored div 4 - 1 do
        Stored[X] := Stored[X + MaxStored div 4];
      Dec(StoredCount, MaxStored div 4);
    end;
  end;
  Stored[StoredCount] := R;
  Inc(StoredCount);
end;

{ ------------------------------------------------------------- scrolling }

function SameOutside(Y1, Y2, X1, X2: Integer): Boolean;
var
  Y, X: Integer;
begin
  Result := True;
  for Y := Y1 to Y2 - 1 do
    for X := 1 to ScreenWidth do
      if (X < X1) or (X > X2) then
        if (Grid[Y - 1].Cells[X - 1].Ch <> Grid[Y].Cells[X - 1].Ch) or
          (Grid[Y - 1].Cells[X - 1].Attr <> Grid[Y].Cells[X - 1].Attr) then
          Exit(False);
end;

{ scrolls rows Y1..Y2 of columns X1..X2 up by one, a blank row at the bottom }
procedure ScrollUp(X1, Y1, X2, Y2: Integer);
var
  Y, X: Integer;
  Full: Boolean;
begin
  if HasMain and (X1 = MX1) and (X2 = MX2) and (Y1 = MY1) and (Y2 = MY2) then
    StoreRow(Y1);
  Full := SameOutside(Y1, Y2, X1, X2);
  for Y := Y1 to Y2 - 1 do
  begin
    for X := X1 to X2 do Grid[Y - 1].Cells[X - 1] := Grid[Y].Cells[X - 1];
    Grid[Y - 1].Len := Grid[Y].Len;
    Grid[Y - 1].Wrapped := Grid[Y].Wrapped;
  end;
  BlankRow(Y2, X1, X2, TextAttr);
  Grid[Y2 - 1].Len := 0;
  Grid[Y2 - 1].Wrapped := False;
  if Y1 = Y2 then
    PaintRow(Y2, X1, X2)
  else if Full then
  begin
    { the terminal scrolls the whole width; what is outside the window is
      the same in every row, so only the new bottom row needs drawing }
    TermColor(TextAttr);
    Emit(#27'[' + IntToStr(Y1) + ';' + IntToStr(Y2) + 'r');
    Emit(#27'[' + IntToStr(Y2) + ';1H'#27'D');
    Emit(#27'[r');
    TermX := -1;
    TermY := -1;
    PaintRow(Y2, 1, ScreenWidth);
  end
  else
    for Y := Y1 to Y2 do PaintRow(Y, X1, X2);
end;

procedure ScrollDown(X1, Y1, X2, Y2: Integer);
var
  Y, X: Integer;
begin
  for Y := Y2 downto Y1 + 1 do
  begin
    for X := X1 to X2 do Grid[Y - 1].Cells[X - 1] := Grid[Y - 2].Cells[X - 1];
    Grid[Y - 1].Len := Grid[Y - 2].Len;
    Grid[Y - 1].Wrapped := Grid[Y - 2].Wrapped;
  end;
  BlankRow(Y1, X1, X2, TextAttr);
  Grid[Y1 - 1].Len := 0;
  Grid[Y1 - 1].Wrapped := False;
  for Y := Y1 to Y2 do PaintRow(Y, X1, X2);
end;

procedure NewLine(Soft: Boolean);
begin
  Grid[CurY - 1].Wrapped := Soft;
  PendingWrap := False;
  CurX := WX1;
  if CurY < WY2 then
    Inc(CurY)
  else
    ScrollUp(WX1, WY1, WX2, WY2);
  Grid[CurY - 1].Wrapped := False;
end;

{ ---------------------------------------------------------- writing text }

procedure PutChar(C: Char);
var
  P, X, N: Integer;
  Word: array of TCell;
begin
  if SkipSpaces then
  begin
    if C = ' ' then Exit;
    SkipSpaces := False;
  end;
  if PendingWrap then
  begin
    if WrapOn and (C = ' ') then
    begin
      NewLine(True);
      SkipSpaces := True;
      Exit;
    end;
    if WrapOn then
    begin
      { carry the word that does not fit to the next line }
      P := WX2;
      while (P >= WX1) and (Grid[CurY - 1].Cells[P - 1].Ch <> ' ') do Dec(P);
      if P > WX1 then
      begin
        N := WX2 - P;
        SetLength(Word, N);
        for X := 1 to N do Word[X - 1] := Grid[CurY - 1].Cells[P + X - 1];
        for X := P + 1 to WX2 do SetCell(X, CurY, ' ', Word[X - P - 1].Attr);
        PaintRow(CurY, P + 1, WX2);
        { trim the spaces the line now ends in }
        while (P >= WX1) and (Grid[CurY - 1].Cells[P - 1].Ch = ' ') do Dec(P);
        Grid[CurY - 1].Len := P - WX1 + 1;
        NewLine(True);
        for X := 0 to N - 1 do
        begin
          Grid[CurY - 1].Cells[CurX - 1] := Word[X];
          PaintCell(CurX, CurY);
          Inc(CurX);
        end;
        Grid[CurY - 1].Len := CurX - WX1;
      end
      else
        NewLine(True);
    end
    else
      NewLine(True);
  end;
  SetCell(CurX, CurY, C, TextAttr);
  PaintCell(CurX, CurY);
  if CurX - WX1 + 1 > Grid[CurY - 1].Len then Grid[CurY - 1].Len := CurX - WX1 + 1;
  if CurX < WX2 then
    Inc(CurX)
  else
    PendingWrap := True;
end;

procedure WriteChars(P: PChar; N: Integer);
var
  I: Integer;
  C: Char;
begin
  for I := 0 to N - 1 do
  begin
    C := P[I];
    if not HasMain or ((WX1 = MX1) and (WY1 = MY1) and (WX2 = MX2) and (WY2 = MY2)) then
      LogChar(C);
    case C of
      #10: begin SkipSpaces := False; NewLine(False); end;
      #13: begin PendingWrap := False; CurX := WX1; end;
      #7: ;
      #8: begin PendingWrap := False; if CurX > WX1 then Dec(CurX); end;
    else
      PutChar(C);
    end;
  end;
end;

{ -------------------------------------------------------------- keyboard }

procedure QueueKey(C: Char);
begin
  KeyQ := KeyQ + C;
end;

procedure QueueExt(Code: Byte);
begin
  KeyQ := KeyQ + #0 + Chr(Code);
end;

{$IFDEF UNIX}
function ReadByte(TimeoutMS: Integer; out B: Byte): Boolean;
var
  FDs: TFDSet;
  TV: TTimeVal;
begin
  fpFD_ZERO(FDs);
  fpFD_SET(0, FDs);
  TV.tv_sec := TimeoutMS div 1000;
  TV.tv_usec := (TimeoutMS mod 1000) * 1000;
  Result := False;
  if fpSelect(1, @FDs, nil, nil, @TV) > 0 then
    Result := fpRead(0, B, 1) = 1;
end;

{ an escape sequence after ESC: arrows, Home, End, PgUp, PgDn, Ins, Del, F1
  to F10, with Shift or Ctrl on PgUp and PgDn for paging }
procedure ParseEscape;
var
  B: Byte;
  S: AnsiString;
  Mods, Num, P: Integer;
  Fin: Char;
begin
  if not ReadByte(40, B) then
  begin
    QueueKey(#27);
    Exit;
  end;
  if (B <> Ord('[')) and (B <> Ord('O')) then
  begin
    { Alt plus a key: the key alone }
    QueueKey(Chr(B));
    Exit;
  end;
  S := '';
  Fin := #0;
  while ReadByte(40, B) do
  begin
    if B in [Ord('0')..Ord('9'), Ord(';')] then
      S := S + Chr(B)
    else
    begin
      Fin := Chr(B);
      Break;
    end;
  end;
  Num := 0;
  Mods := 1;
  P := Pos(';', S);
  if P > 0 then
  begin
    Num := StrToIntDef(Copy(S, 1, P - 1), 0);
    Mods := StrToIntDef(Copy(S, P + 1, 9), 1);
  end
  else
    Num := StrToIntDef(S, 0);
  case Fin of
    'A': QueueExt(kbUp);
    'B': QueueExt(kbDown);
    'C': QueueExt(kbRight);
    'D': QueueExt(kbLeft);
    'H': QueueExt(kbHome);
    'F': QueueExt(kbEnd);
    'P': QueueExt(kbF1);
    'Q': QueueExt(kbF1 + 1);
    'R': QueueExt(kbF1 + 2);
    'S': QueueExt(kbF1 + 3);
    '~':
      case Num of
        1, 7: QueueExt(kbHome);
        2: QueueExt(kbIns);
        3: QueueExt(kbDel);
        4, 8: QueueExt(kbEnd);
        5: if Mods > 1 then QueueExt(kbBackUp) else QueueExt(kbPgUp);
        6: if Mods > 1 then QueueExt(kbBackDown) else QueueExt(kbPgDn);
        11..15: QueueExt(kbF1 + Num - 11);
        17..21: QueueExt(kbF1 + 5 + Num - 17);
      end;
  end;
end;

procedure PollKeys(TimeoutMS: Integer);
var
  B: Byte;
begin
  if not ReadByte(TimeoutMS, B) then Exit;
  repeat
    case B of
      27: ParseEscape;
      127: QueueKey(#8);
      10: QueueKey(#13);
      $C0..$FF: { a character outside ASCII: skip it }
        while ReadByte(5, B) and (B in [$80..$BF]) do ;
      $80..$BF: ;
    else
      QueueKey(Chr(B));
    end;
  until not ReadByte(0, B);
end;
{$ENDIF}

{$IFDEF WINDOWS}
procedure PollKeys(TimeoutMS: Integer);
var
  Rec: TInputRecord;
  N: DWORD;
  VK: Word;
  Shifted: Boolean;
  U: WideChar;
begin
  if WaitForSingleObject(HIn, TimeoutMS) <> WAIT_OBJECT_0 then Exit;
  while GetNumberOfConsoleInputEvents(HIn, N) and (N > 0) do
  begin
    if not ReadConsoleInputW(HIn, Rec, 1, N) then Exit;
    if (Rec.EventType <> KEY_EVENT) or not Rec.Event.KeyEvent.bKeyDown then
      Continue;
    VK := Rec.Event.KeyEvent.wVirtualKeyCode;
    Shifted := (Rec.Event.KeyEvent.dwControlKeyState and
      (SHIFT_PRESSED or LEFT_CTRL_PRESSED or RIGHT_CTRL_PRESSED)) <> 0;
    case VK of
      VK_UP: QueueExt(kbUp);
      VK_DOWN: QueueExt(kbDown);
      VK_LEFT: QueueExt(kbLeft);
      VK_RIGHT: QueueExt(kbRight);
      VK_HOME: QueueExt(kbHome);
      VK_END: QueueExt(kbEnd);
      VK_PRIOR: if Shifted then QueueExt(kbBackUp) else QueueExt(kbPgUp);
      VK_NEXT: if Shifted then QueueExt(kbBackDown) else QueueExt(kbPgDn);
      VK_INSERT: QueueExt(kbIns);
      VK_DELETE: QueueExt(kbDel);
      VK_F1..VK_F10: QueueExt(kbF1 + VK - VK_F1);
    else
      begin
        U := Rec.Event.KeyEvent.UnicodeChar;
        if (Ord(U) > 0) and (Ord(U) < 128) then QueueKey(Chr(Ord(U)));
      end;
    end;
  end;
end;
{$ENDIF}

{ ----------------------------------------------------- resizing, paging }

procedure GatherLines(var Lines: array of AnsiString; var Attrs: array of AnsiString;
  var Count: Integer; const T, A: AnsiString; Cont: Boolean);
begin
  if Cont and (Count > 0) then
  begin
    Lines[Count - 1] := Lines[Count - 1] + ' ' + T;
    if Attrs[Count - 1] <> '' then
      Attrs[Count - 1] := Attrs[Count - 1] + Attrs[Count - 1][Length(Attrs[Count - 1])] + A
    else
      Attrs[Count - 1] := #7 + A;
  end
  else
  begin
    Lines[Count] := T;
    Attrs[Count] := A;
    Inc(Count);
  end;
end;

{ lays the stored rows and the main window's rows out again at the main
  window's current width: everything goes to the stored rows, then the
  last of them come back into the window, bottom aligned }
procedure Reflow(const OldRows: array of TStoredRow; Below: Integer);
var
  Lines, Attrs: array of AnsiString;
  Count, I, J, W, Cut, H, Y, X, Total: Integer;
  T, A: AnsiString;
  Cont: Boolean;
  NewRows: array of TStoredRow;
  R: TStoredRow;
begin
  Total := StoredCount + Length(OldRows);
  SetLength(Lines, Total + 1);
  SetLength(Attrs, Total + 1);
  Count := 0;
  Cont := False;
  for I := 0 to StoredCount - 1 do
  begin
    T := TrimRight(Stored[I].Text);
    A := Copy(Stored[I].Attrs, 1, Length(T));
    if Cont then begin T := TrimLeft(T); A := Copy(Stored[I].Attrs, Length(Stored[I].Text) - Length(T) + 1, Length(T)); end;
    GatherLines(Lines, Attrs, Count, T, A, Cont);
    Cont := Stored[I].Wrapped;
  end;
  for I := 0 to High(OldRows) do
  begin
    T := OldRows[I].Text;
    A := OldRows[I].Attrs;
    if Cont then begin J := Length(T) - Length(TrimLeft(T)); T := Copy(T, J + 1, MaxInt); A := Copy(A, J + 1, MaxInt); end;
    GatherLines(Lines, Attrs, Count, T, A, Cont);
    Cont := OldRows[I].Wrapped;
  end;
  { wrap each line at the new width }
  W := MX2 - MX1 + 1;
  SetLength(NewRows, 0);
  for I := 0 to Count - 1 do
  begin
    T := Lines[I];
    A := Attrs[I];
    repeat
      if Length(T) <= W then
      begin
        R.Text := T; R.Attrs := A; R.Wrapped := False;
        SetLength(NewRows, Length(NewRows) + 1);
        NewRows[High(NewRows)] := R;
        Break;
      end;
      Cut := W;
      while (Cut > 0) and (T[Cut + 1] <> ' ') and (T[Cut] <> ' ') do Dec(Cut);
      if Cut = 0 then Cut := W;
      R.Text := TrimRight(Copy(T, 1, Cut));
      R.Attrs := Copy(A, 1, Length(R.Text));
      R.Wrapped := True;
      SetLength(NewRows, Length(NewRows) + 1);
      NewRows[High(NewRows)] := R;
      J := Cut + 1;
      while (J <= Length(T)) and (T[J] = ' ') do Inc(J);
      T := Copy(T, J, MaxInt);
      A := Copy(A, J, MaxInt);
    until T = '';
  end;
  { the last H rows go into the window, leaving the rows that were below
    the cursor blank below it again }
  H := MY2 - MY1 + 1 - Below;
  if H < 1 then H := 1;
  StoredCount := 0;
  for I := 0 to High(NewRows) - H do
  begin
    if StoredCount >= Length(Stored) then SetLength(Stored, StoredCount + 256);
    Stored[StoredCount] := NewRows[I];
    Inc(StoredCount);
  end;
  J := Length(NewRows) - H;
  for Y := MY1 to MY2 do
  begin
    BlankRow(Y, MX1, MX2, TextAttr);
    Grid[Y - 1].Len := 0;
    Grid[Y - 1].Wrapped := False;
  end;
  Y := MY1; { top aligned when the story is short }
  CurY := MY1;
  CurX := MX1;
  for I := 0 to High(NewRows) do
  begin
    if I < J then Continue;
    R := NewRows[I];
    for X := 1 to Length(R.Text) do
      if MX1 + X - 1 <= MX2 then
        SetCell(MX1 + X - 1, Y, R.Text[X], Ord(R.Attrs[X]));
    Grid[Y - 1].Len := Length(R.Text);
    Grid[Y - 1].Wrapped := R.Wrapped;
    CurY := Y;
    CurX := MX1 + Length(R.Text);
    Inc(Y);
  end;
  if CurX > MX2 then
  begin
    CurX := MX2;
    PendingWrap := True;
  end
  else
    PendingWrap := False;
  for Y := MY1 to MY2 do PaintRow(Y, MX1, MX2);
end;

function CheckResize: Boolean;
var
  W, H, Y, X, N, OX1, OX2: Integer;
  OldRows: array of TStoredRow;
  SaveX1, SaveY1, SaveX2, SaveY2, SaveCX, SaveCY: Integer;
  WasMain: Boolean;
  SaveAttr: Byte;
  Below: Integer;
begin
  Result := False;
  TermSize(W, H);
  if (W = ScreenWidth) and (H = ScreenHeight) then Exit;
  Result := True;
  Paged := 0;
  WasMain := HasMain and (WX1 = MX1) and (WY1 = MY1) and (WX2 = MX2) and (WY2 = MY2);
  SaveX1 := WX1; SaveY1 := WY1; SaveX2 := WX2; SaveY2 := WY2;
  SaveCX := CurX; SaveCY := CurY;
  SaveAttr := TextAttr;
  { the line being typed is drawn again by the editor, at its new place }
  if EditActive then
  begin
    for X := EditX to EditX + EditLen - 1 do
      if X <= Length(Grid[EditY - 1].Cells) then SetCell(X, EditY, ' ', TextAttr);
    Grid[EditY - 1].Len := EditX - WX1;
    CurX := EditX;
    CurY := EditY;
    PendingWrap := False;
  end;
  { the main window's rows down to the cursor's row }
  SetLength(OldRows, 0);
  Below := 0;
  if HasMain and WasMain then
  begin
    Below := MY2 - CurY;
    { only blank rows below the cursor are kept as room below it }
    for Y := CurY + 1 to MY2 do
      if Grid[Y - 1].Len > 0 then Below := 0;
  end;
  if HasMain then
  begin
    OX1 := MX1; OX2 := MX2;
    for Y := MY1 to MY2 do
    begin
      if WasMain and (Y > CurY) then Break;
      N := Grid[Y - 1].Len;
      if WasMain and (Y = CurY) and (CurX - MX1 > N) then N := CurX - MX1;
      if N > OX2 - OX1 + 1 then N := OX2 - OX1 + 1;
      SetLength(OldRows, Length(OldRows) + 1);
      SetLength(OldRows[High(OldRows)].Text, N);
      SetLength(OldRows[High(OldRows)].Attrs, N);
      for X := 1 to N do
      begin
        OldRows[High(OldRows)].Text[X] := Grid[Y - 1].Cells[OX1 + X - 2].Ch;
        OldRows[High(OldRows)].Attrs[X] := Chr(Grid[Y - 1].Cells[OX1 + X - 2].Attr);
      end;
      OldRows[High(OldRows)].Wrapped := Grid[Y - 1].Wrapped;
    end;
    { blank rows above the story's first line are not story }
    while (Length(OldRows) > 1) and (Trim(OldRows[0].Text) = '') and (StoredCount = 0) do
    begin
      for Y := 0 to High(OldRows) - 1 do OldRows[Y] := OldRows[Y + 1];
      SetLength(OldRows, Length(OldRows) - 1);
    end;
  end;
  SizeGrid(W, H);
  if Assigned(AvOnResize) and HasMain then
  begin
    for Y := 1 to H do
    begin
      BlankRow(Y, 1, W, 7);
      Grid[Y - 1].Len := 0;
      Grid[Y - 1].Wrapped := False;
    end;
    Emit(#27'[0m'#27'[2J');
    TermAttr := -1;
    TermX := -1;
    AvOnResize();
    TextAttr := SaveAttr;
    Reflow(OldRows, Below);
    if not WasMain then
    begin
      { leave the cursor where it was, inside the new screen }
      WX1 := SaveX1; WY1 := SaveY1; WX2 := SaveX2; WY2 := SaveY2;
      if WX2 > W then WX2 := W;
      if WY2 > H then WY2 := H;
      if WX1 > WX2 then WX1 := 1;
      if WY1 > WY2 then WY1 := 1;
      CurX := SaveCX; CurY := SaveCY;
      if CurX > WX2 then CurX := WX2;
      if CurY > WY2 then CurY := WY2;
    end;
  end
  else
  begin
    if WX2 > W then WX2 := W;
    if WY2 > H then WY2 := H;
    if WX1 > WX2 then WX1 := 1;
    if WY1 > WY2 then WY1 := 1;
    if CurX > WX2 then CurX := WX2;
    if CurY > WY2 then CurY := WY2;
    PaintAll;
  end;
  AvLog('resize: ' + IntToStr(W) + 'x' + IntToStr(H));
end;

procedure ShowCursor;
begin
  TermGoto(CurX, CurY);
  TermColor(TextAttr);
  if CursorWanted then Emit(#27'[?25h');
  Flush;
end;

procedure HideCursor;
begin
  Emit(#27'[?25l');
end;

{ draws the main window paged back by Paged rows }
procedure DrawPaged;
var
  H, Y, I, X, Live: Integer;
  Note: AnsiString;
begin
  H := MY2 - MY1 + 1;
  Live := 0;
  for Y := MY1 to MY2 do Inc(Live);
  for Y := MY1 to MY2 do
  begin
    { the row shown at Y: counted back from the bottom of the window }
    I := StoredCount + (Y - MY1) - Paged;
    TermGoto(MX1, Y);
    if I >= StoredCount then
    begin
      { a row of the window, shown lower down }
      for X := MX1 to MX2 do
      begin
        TermColor(Grid[MY1 + I - StoredCount - 1].Cells[X - 1].Attr);
        Emit(Utf8Of(Grid[MY1 + I - StoredCount - 1].Cells[X - 1].Ch));
      end;
      TermX := -1;
    end
    else
    begin
      for X := MX1 to MX2 do
      begin
        if (I >= 0) and (X - MX1 + 1 <= Length(Stored[I].Text)) then
        begin
          TermColor(Ord(Stored[I].Attrs[X - MX1 + 1]));
          Emit(Utf8Of(Stored[I].Text[X - MX1 + 1]));
        end
        else
        begin
          TermColor(7);
          Emit(' ');
        end;
      end;
      TermX := -1;
    end;
  end;
  Note := ' Shift+PgUp, Shift+PgDn: page back and forth. Any other key: back to the game ';
  if Length(Note) > MX2 - MX1 + 1 then Note := ' paging back ';
  TermGoto(MX2 - Length(Note) + 1, MY2);
  TermColor($70);
  Emit(Note);
  TermX := -1;
  if H = 0 then ;
end;

function AvPageKey(Key: Byte; Plain: Boolean): Boolean;
var
  H, Y: Integer;
begin
  Result := False;
  if not HasMain then Exit;
  H := MY2 - MY1 + 1;
  if (Key = kbBackUp) or (Plain and (Key = kbPgUp)) then
  begin
    Inc(Paged, H - 2);
    if Paged > StoredCount then Paged := StoredCount;
    Result := True;
  end
  else if (Key = kbBackDown) or (Plain and (Key = kbPgDn)) then
  begin
    Dec(Paged, H - 2);
    if Paged < 0 then Paged := 0;
    Result := True;
  end;
  if not Result then Exit;
  HideCursor;
  if Paged > 0 then
    DrawPaged
  else
    for Y := MY1 to MY2 do PaintRow(Y, MX1, MX2);
  Flush;
end;

procedure EndPaging;
var
  Y: Integer;
begin
  if Paged = 0 then Exit;
  Paged := 0;
  for Y := MY1 to MY2 do PaintRow(Y, MX1, MX2);
end;

{ waits up to TimeoutMS for a key, watching the terminal's size meanwhile }
procedure WaitKey(TimeoutMS: Integer);
var
  Waited: Integer;
begin
  Waited := 0;
  repeat
    if KeyQ <> '' then Exit;
    if CheckResize and EditActive then Exit;
    ShowCursor;
    if (TimeoutMS >= 0) and (TimeoutMS < 50) then
      PollKeys(TimeoutMS)
    else
      PollKeys(50);
    Inc(Waited, 50);
  until (KeyQ <> '') or ((TimeoutMS >= 0) and (Waited >= TimeoutMS));
end;

{ ------------------------------------------------------ the Crt interface }

procedure ClrScr;
var
  Y: Integer;
begin
  PendingWrap := False;
  SkipSpaces := False;
  for Y := WY1 to WY2 do
  begin
    BlankRow(Y, WX1, WX2, TextAttr);
    Grid[Y - 1].Len := 0;
    Grid[Y - 1].Wrapped := False;
    PaintRow(Y, WX1, WX2);
  end;
  if HasMain and (WX1 <= MX1) and (WX2 >= MX2) and (WY1 <= MY1) and (WY2 >= MY2) then
    StoredCount := 0;
  CurX := WX1;
  CurY := WY1;
end;

procedure ClrEol;
var
  X: Integer;
begin
  for X := CurX to WX2 do SetCell(X, CurY, ' ', TextAttr);
  if Grid[CurY - 1].Len > CurX - WX1 then Grid[CurY - 1].Len := CurX - WX1;
  PaintRow(CurY, CurX, WX2);
end;

procedure GotoXY(X, Y: Integer);
begin
  if (X < 1) or (Y < 1) or (WX1 + X - 1 > WX2) or (WY1 + Y - 1 > WY2) then Exit;
  PendingWrap := False;
  SkipSpaces := False;
  CurX := WX1 + X - 1;
  CurY := WY1 + Y - 1;
end;

function WhereX: Integer;
begin
  Result := CurX - WX1 + 1;
end;

function WhereY: Integer;
begin
  Result := CurY - WY1 + 1;
end;

procedure TextColor(Color: Byte);
begin
  TextAttr := (TextAttr and $70) or (Color and $0F);
  if Color > 15 then TextAttr := TextAttr or $80;
end;

procedure TextBackground(Color: Byte);
begin
  TextAttr := (TextAttr and $8F) or ((Color and 7) shl 4);
end;

procedure Window(X1, Y1, X2, Y2: Integer);
begin
  if X2 > ScreenWidth then X2 := ScreenWidth;
  if Y2 > ScreenHeight then Y2 := ScreenHeight;
  if (X1 < 1) or (Y1 < 1) or (X1 > X2) or (Y1 > Y2) then Exit;
  WX1 := X1; WY1 := Y1; WX2 := X2; WY2 := Y2;
  PendingWrap := False;
  SkipSpaces := False;
  CurX := WX1;
  CurY := WY1;
end;

procedure AvSetMainWindow(X1, Y1, X2, Y2: Integer);
begin
  Window(X1, Y1, X2, Y2);
  MX1 := WX1; MY1 := WY1; MX2 := WX2; MY2 := WY2;
  HasMain := True;
end;

function AvWindowWidth: Integer;
begin
  Result := WX2 - WX1 + 1;
end;

function AvWindowHeight: Integer;
begin
  Result := WY2 - WY1 + 1;
end;

procedure AvFarewell(const S: string);
begin
{$IFDEF WINDOWS}
  Farewell := Farewell + S + #13#10;
{$ELSE}
  Farewell := Farewell + S + #10;
{$ENDIF}
end;

procedure AvSetWrap(On: Boolean);
begin
  WrapOn := On;
end;

procedure DelLine;
begin
  if CurY < WY2 then
    ScrollUp(WX1, CurY, WX2, WY2)
  else
  begin
    BlankRow(CurY, WX1, WX2, TextAttr);
    Grid[CurY - 1].Len := 0;
    PaintRow(CurY, WX1, WX2);
  end;
end;

procedure InsLine;
begin
  ScrollDown(WX1, CurY, WX2, WY2);
end;

function ReadKey: Char;
begin
  WaitKey(-1);
  HideCursor;
  Result := KeyQ[1];
  Delete(KeyQ, 1, 1);
  if (Paged > 0) and not ((Result = #0) and (KeyQ <> '') and
    (Ord(KeyQ[1]) in [kbBackUp, kbBackDown])) then
    EndPaging;
  if (Result = #3) and (KeyQ = '') then AvQuit(0);
  if LogOpen then
  begin
    if Result = #0 then
      AvLog('key: extended ' + IntToStr(Ord(KeyQ[1])))
    else if (Result >= ' ') and (Result < #127) then
      AvLog('key: ' + Result)
    else
      AvLog('key: #' + IntToStr(Ord(Result)));
  end;
end;

function KeyPressed: Boolean;
begin
  if KeyQ = '' then
  begin
    if CheckResize then ;
    Flush;
    PollKeys(0);
  end;
  Result := KeyQ <> '';
end;

procedure Delay(MS: LongInt);
begin
  Flush;
  SleepMS(MS);
end;

procedure Sound(Hz: LongInt);
begin
end;

procedure NoSound;
begin
end;

procedure TextMode(Mode: Integer);
begin
  Window(1, 1, ScreenWidth, ScreenHeight);
  TextAttr := 7;
  ClrScr;
end;

procedure CursorOn;
begin
  CursorWanted := True;
end;

procedure CursorOff;
begin
  CursorWanted := False;
end;

procedure CursorBig;
begin
  CursorWanted := True;
end;

{ ------------------------------------------------------- the line editor }

function AvReadLine(MaxLen: Integer; History: Boolean): string;
var
  S, Saved: AnsiString;
  Pos0X, Pos0Y, P, HistAt, Room, I: Integer;
  C: Char;
  K: Byte;
  Attr: Byte;
  WasWrap: Boolean;

  procedure Redraw;
  var
    X: Integer;
  begin
    for X := 1 to Room do
    begin
      if X <= Length(S) then
        SetCell(Pos0X + X - 1, Pos0Y, S[X], Attr)
      else
        SetCell(Pos0X + X - 1, Pos0Y, ' ', Attr);
    end;
    PaintRow(Pos0Y, Pos0X, Pos0X + Room - 1);
    Grid[Pos0Y - 1].Len := Pos0X - WX1 + Length(S);
    CurX := Pos0X + P;
    CurY := Pos0Y;
  end;

  procedure Place;
  begin
    { the line starts where the cursor is; on a resize the prompt moves }
    if PendingWrap then NewLine(False);
    Pos0X := CurX;
    Pos0Y := CurY;
    Room := WX2 - Pos0X;
    if Room < 1 then
    begin
      NewLine(False);
      Pos0X := CurX;
      Room := WX2 - Pos0X;
    end;
    if Room > MaxLen then Room := MaxLen;
    if Length(S) > Room then SetLength(S, Room);
    if P > Length(S) then P := Length(S);
  end;

begin
  WasWrap := WrapOn;
  WrapOn := False;
  S := '';
  P := 0;
  Attr := TextAttr;
  HistAt := Length(AvCrt.History);
  Saved := '';
  Place;
  Redraw;
  repeat
    if KeyQ = '' then
    begin
      I := ScreenWidth * 1000 + ScreenHeight;
      EditActive := True;
      EditX := Pos0X;
      EditY := Pos0Y;
      EditLen := Room;
      WaitKey(-1);
      EditActive := False;
      if I <> ScreenWidth * 1000 + ScreenHeight then
      begin
        Place;
        Redraw;
      end;
      if KeyQ = '' then Continue;
    end;
    HideCursor;
    C := KeyQ[1];
    Delete(KeyQ, 1, 1);
    if C = #0 then
    begin
      K := Ord(KeyQ[1]);
      Delete(KeyQ, 1, 1);
      AvLog('key: extended ' + IntToStr(K));
      if AvPageKey(K, True) then Continue;
      EndPaging;
      case K of
        kbLeft: if P > 0 then Dec(P);
        kbRight: if P < Length(S) then Inc(P);
        kbHome: P := 0;
        kbEnd: P := Length(S);
        kbDel: if P < Length(S) then Delete(S, P + 1, 1);
        kbUp:
          if History and (HistAt > 0) then
          begin
            if HistAt = Length(AvCrt.History) then Saved := S;
            Dec(HistAt);
            S := Copy(AvCrt.History[HistAt], 1, Room);
            P := Length(S);
          end;
        kbDown:
          if History and (HistAt < Length(AvCrt.History)) then
          begin
            Inc(HistAt);
            if HistAt = Length(AvCrt.History) then S := Saved
            else S := Copy(AvCrt.History[HistAt], 1, Room);
            P := Length(S);
          end;
      end;
    end
    else
    begin
      EndPaging;
      if (C >= ' ') and (C < #127) then AvLog('key: ' + C)
      else AvLog('key: #' + IntToStr(Ord(C)));
      case C of
        #3: AvQuit(0);
        #13: Break;
        #8: if P > 0 then begin Delete(S, P, 1); Dec(P); end;
        #1: P := 0;
        #5: P := Length(S);
        #2: if P > 0 then Dec(P);
        #6: if P < Length(S) then Inc(P);
        #4: if P < Length(S) then Delete(S, P + 1, 1);
        #11: SetLength(S, P);
        #21: begin Delete(S, 1, P); P := 0; end;
        #27: begin S := ''; P := 0; end;
      else
        if (C >= ' ') and (C < #127) and (Length(S) < Room) then
        begin
          Insert(C, S, P + 1);
          Inc(P);
        end;
      end;
    end;
    Redraw;
  until False;
  EndPaging;
  P := Length(S);
  Redraw;
  if History and (Trim(S) <> '') then
  begin
    SetLength(AvCrt.History, Length(AvCrt.History) + 1);
    AvCrt.History[High(AvCrt.History)] := S;
  end;
  AvLog('line: ' + S);
  if LogOpen then LogLine := LogLine + S;
  WrapOn := WasWrap;
  Result := S;
end;

{ ----------------------------------------------- texts from the data files }

function SentenceEnd(const S: AnsiString): Boolean;
var
  L: Integer;
begin
  L := Length(S);
  while (L > 0) and (S[L] in ['"', '''', ')']) do Dec(L);
  Result := (L > 0) and (S[L] in ['.', '!', '?']);
end;

procedure AvShowText(const A, B: AnsiString; Width: Integer);
var
  T, Chunk, Content, Next, R: AnsiString;
  I, Trail, Lead: Integer;
begin
  T := A + B;
  R := '';
  I := 1;
  while I <= Length(T) do
  begin
    Chunk := Copy(T, I, Width);
    Inc(I, Width);
    Content := TrimRight(Chunk);
    if I > Length(T) then
    begin
      R := R + Content;
      Break;
    end;
    Next := Copy(T, I, Width);
    Lead := Length(Next) - Length(TrimLeft(Next));
    if Length(Chunk) = Width then Trail := Width - Length(Content) else Trail := 0;
    R := R + Content;
    if (Content = '') or (Lead >= 2) or (Trail >= 14) then
      R := R + #10
    else
    begin
      { a line the window's edge broke: one paragraph again }
      if SentenceEnd(Content) then R := R + '  '
      else if (Content <> '') and (Content[Length(Content)] <> '-') then R := R + ' ';
      while (I <= Length(T)) and (T[I] = ' ') do Inc(I);
    end;
  end;
  WriteChars(PChar(R), Length(R));
  WriteChars(#10, 1);
end;

{ ------------------------------------------- Input and Output as text files }

procedure AvTextWrite(var F: TextRec);
begin
  if F.BufPos > 0 then
  begin
    WriteChars(PChar(F.BufPtr), F.BufPos);
    F.BufPos := 0;
  end;
end;

procedure AvTextRead(var F: TextRec);
var
  S: AnsiString;
  N: Integer;
begin
  S := AvReadLine(F.BufSize - 2, False);
  WriteChars(#10, 1);
  S := S + #10;
  N := Length(S);
  if N > F.BufSize then N := F.BufSize;
  Move(S[1], F.BufPtr^, N);
  F.BufPos := 0;
  F.BufEnd := N;
end;

procedure AvTextNothing(var F: TextRec);
begin
end;

procedure AvTextClose(var F: TextRec);
begin
  F.Mode := fmClosed;
end;

procedure AvTextOpen(var F: TextRec);
begin
  if F.Mode = fmOutput then
  begin
    F.InOutFunc := @AvTextWrite;
    F.FlushFunc := @AvTextWrite;
  end
  else
  begin
    F.Mode := fmInput;
    F.InOutFunc := @AvTextRead;
    F.FlushFunc := @AvTextNothing;
  end;
  F.CloseFunc := @AvTextClose;
end;

procedure AssignAv(var F: Text);
begin
  Assign(F, '');
  TextRec(F).OpenFunc := @AvTextOpen;
end;

{ ----------------------------------------------------------- the folders }

function AvDataDir: string;
var
  Exe, D: string;
{$IFDEF LINUX}
  Buf: array[0..4095] of Char;
  N: LongInt;
{$ENDIF}
  PathList, Part: string;
  I: Integer;
begin
  Exe := '';
{$IFDEF LINUX}
  N := fpReadLink('/proc/self/exe', @Buf[0], SizeOf(Buf) - 1);
  if N > 0 then
  begin
    Buf[N] := #0;
    Exe := StrPas(@Buf[0]);
  end;
{$ENDIF}
  if Exe = '' then
  begin
    Exe := ParamStr(0);
    if (Pos('/', Exe) = 0) and (Pos('\', Exe) = 0) then
    begin
      { found on PATH: look for it there }
      PathList := GetEnvironmentVariable('PATH');
      while PathList <> '' do
      begin
        I := Pos(PathSeparator, PathList);
        if I = 0 then I := Length(PathList) + 1;
        Part := Copy(PathList, 1, I - 1);
        Delete(PathList, 1, I);
        if (Part <> '') and FileExists(IncludeTrailingPathDelimiter(Part) + Exe) then
        begin
          Exe := IncludeTrailingPathDelimiter(Part) + Exe;
          Break;
        end;
      end;
    end;
  end;
{$IFDEF UNIX}
  { through any symbolic links to the real file }
  I := 0;
  while (I < 16) and (fpReadLink(Exe) <> '') do
  begin
    D := fpReadLink(Exe);
    if (D <> '') and (D[1] <> '/') then D := ExtractFilePath(Exe) + D;
    Exe := D;
    Inc(I);
  end;
{$ENDIF}
  Result := ExtractFilePath(ExpandFileName(Exe));
end;

function AvStateDir(const Id: string): string;
var
  Base: string;
begin
{$IFDEF WINDOWS}
  Base := GetEnvironmentVariable('LOCALAPPDATA');
  if Base = '' then Base := GetEnvironmentVariable('APPDATA');
  if Base = '' then Base := '.';
{$ELSE}
  Base := GetEnvironmentVariable('XDG_STATE_HOME');
  if (Base = '') or (Base[1] <> '/') then
  begin
    Base := GetEnvironmentVariable('HOME');
    if Base = '' then Base := '.';
    Base := IncludeTrailingPathDelimiter(Base) + '.local' + DirectorySeparator + 'state';
  end;
{$ENDIF}
  Result := IncludeTrailingPathDelimiter(Base) + Id;
  ForceDirectories(Result);
  Result := IncludeTrailingPathDelimiter(Result);
end;

function AvNoColor: Boolean;
begin
  Result := GetEnvironmentVariable('NO_COLOR') <> '';
end;

{ ------------------------------------------------------------ the ending }

procedure AvQuit(Code: Integer);
begin
  AvLog('quit');
  RestoreTerminal;
  Halt(Code);
end;

procedure AvFatal(const Msg: string);
begin
  AvLog('fatal: ' + Msg);
  RestoreTerminal;
  WriteLn(StdErr, Msg);
  Halt(1);
end;

procedure AvRestart;
var
  Exe: string;
{$IFDEF UNIX}
  Args: array[0..1] of PChar;
{$ENDIF}
begin
  AvLog('restart');
  Exe := ExpandFileName(ParamStr(0));
  if not FileExists(Exe) then Exe := AvDataDir + ExtractFileName(ParamStr(0));
  RestoreTerminal;
  if LogOpen then CloseFile(LogFile);
  LogOpen := False;
{$IFDEF UNIX}
  Args[0] := PChar(Exe);
  Args[1] := nil;
  fpExecv(PChar(Exe), @Args[0]);
  Halt(1);
{$ELSE}
  Halt(ExecuteProcess(Exe, ''));
{$ENDIF}
end;

var
  W0, H0: Integer;

initialization
  StartTerminal;
  TermSize(W0, H0);
  SizeGrid(W0, H0);
  WX1 := 1; WY1 := 1; WX2 := ScreenWidth; WY2 := ScreenHeight;
  CurX := 1; CurY := 1;
  AssignAv(Output);
  Rewrite(Output);
  AssignAv(Input);
  Reset(Input);

finalization
  if LogOpen then
  begin
    AvLog('session end');
    CloseFile(LogFile);
    LogOpen := False;
  end;
  RestoreTerminal;
end.
