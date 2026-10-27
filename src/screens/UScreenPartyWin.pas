{* UltraStar Deluxe - Karaoke Game
 *
 * UltraStar Deluxe is the legal property of its developers, whose names
 * are too numerous to list here. Please refer to the COPYRIGHT
 * file distributed with this source distribution.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING. If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 *
 * $URL: https://ultrastardx.svn.sourceforge.net/svnroot/ultrastardx/trunk/src/screens/UScreenPartyWin.pas $
 * $Id: UScreenPartyWin.pas 2246 2010-04-18 13:43:36Z tobigun $
 *}

unit UScreenPartyWin;

interface

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

{$I switches.inc}

uses
  UDisplay,
  UMenu,
  UMusic,
  UThemes,
  sdl2,
  SysUtils;

type
  TScreenPartyWin = class(TMenu)
    public
      TextScoreTeam1:    cardinal;
      TextScoreTeam2:    cardinal;
      TextScoreTeam3:    cardinal;
      TextNameTeam1:     cardinal;
      TextNameTeam2:     cardinal;
      TextNameTeam3:     cardinal;
      StaticTeam1:       cardinal;
      StaticTeam1BG:     cardinal;
      StaticTeam1Deco:   cardinal;
      StaticTeam2:       cardinal;
      StaticTeam2BG:     cardinal;
      StaticTeam2Deco:   cardinal;
      StaticTeam3:       cardinal;
      StaticTeam3BG:     cardinal;
      StaticTeam3Deco:   cardinal;
      TextWinner:        cardinal;

      // "x of y rounds won" below each team
      TextRoundsTeam:    array[0..2] of cardinal;
      // draw: a row can be shown in the size (bar and medal) of a row above;
      // [row, size] (-1 if not needed), [r, r] are the statics of the theme
      RowBar:            array[0..2, 0..2] of integer;
      RowBG:             array[0..2, 0..2] of integer;
      RowDeco:           array[0..2, 0..2] of integer;
      // index of the subtitle and legend text, -1 if not found
      SubtitleText:      integer;
      LegendText:        integer;

      // page 2 "best performances": one box per category (PARTY_BEST_*)
      Page:              integer;
      HasBest:           boolean;
      StaticBest:        array[0..3] of cardinal;
      TextBestCategory:  array[0..3] of cardinal;
      TextBestName:      array[0..3] of cardinal;
      TextBestInfo:      array[0..3] of cardinal;

      // fanfare, then applause
      ShowTime:          cardinal;
      ApplausePlayed:    boolean;

      constructor Create; override;
      function ParseInput(PressedKey: cardinal; CharCode: UCS4Char; PressedDown: boolean): boolean; override;
      procedure OnShow; override;
      function Draw: boolean; override;
      procedure ShowBestPage;
      procedure SetBestVisible(Show: boolean);
      procedure ArrangeBestBoxes;
      procedure MoveBestBox(Index: integer; X, Y: real);
      procedure HideTeamRows;
      procedure ShowTeamRow(Row, Size, Team: integer);
  end;

const
  ID='ID_035';   //for help system

implementation

uses
  UGraphic,
  UHelp,
  UPath,
  URenderer,
  USkins,
  ULanguage,
  ULog,
  UMain,
  UParty,
  UUnicodeUtils;

{ theme entries of a row (0..2) }
function ThemeRowBar(Row: integer): TThemeStatic;
begin
  case Row of
    0: Result := Theme.PartyWin.StaticTeam1;
    1: Result := Theme.PartyWin.StaticTeam2;
    else Result := Theme.PartyWin.StaticTeam3;
  end;
end;

function ThemeRowBG(Row: integer): TThemeStatic;
begin
  case Row of
    0: Result := Theme.PartyWin.StaticTeam1BG;
    1: Result := Theme.PartyWin.StaticTeam2BG;
    else Result := Theme.PartyWin.StaticTeam3BG;
  end;
end;

function ThemeRowDeco(Row: integer): TThemeStatic;
begin
  case Row of
    0: Result := Theme.PartyWin.StaticTeam1Deco;
    1: Result := Theme.PartyWin.StaticTeam2Deco;
    else Result := Theme.PartyWin.StaticTeam3Deco;
  end;
end;

function ThemeRowName(Row: integer): TThemeText;
begin
  case Row of
    0: Result := Theme.PartyWin.TextNameTeam1;
    1: Result := Theme.PartyWin.TextNameTeam2;
    else Result := Theme.PartyWin.TextNameTeam3;
  end;
end;

function ThemeRowScore(Row: integer): TThemeText;
begin
  case Row of
    0: Result := Theme.PartyWin.TextScoreTeam1;
    1: Result := Theme.PartyWin.TextScoreTeam2;
    else Result := Theme.PartyWin.TextScoreTeam3;
  end;
end;

function TScreenPartyWin.ParseInput(PressedKey: cardinal; CharCode: UCS4Char; PressedDown: boolean): boolean;
begin
  Result := true;
  if (PressedDown) then
  begin // Key Down
    // check normal keys
    case PressedKey of
      SDLK_Q:
        begin
          Result := false;
          Exit;
        end;
    end;

    // check special keys
    case PressedKey of
      SDLK_ESCAPE,
      SDLK_BACKSPACE,
      SDLK_RETURN:
        begin
          // first page 2 with the best performances, then the main menu
          if (Page = 1) and HasBest then
          begin
            AudioPlayback.PlaySound(SoundLib.Change);
            ShowBestPage;
          end
          else
          begin
            AudioPlayback.PlaySound(SoundLib.Start);
            FadeTo(@ScreenMain);
          end;
        end;
      SDLK_TAB:
        begin
          ScreenPopupHelp.ShowPopup();
        end;
    end;
  end;
end;

const
  // page 2 layout (2 x 2 boxes below the banner)
  BEST_X: array[0..1] of real = (50, 410);
  BEST_Y: array[0..1] of real = (184, 344);
  BEST_W = 340;
  BEST_H = 140;

constructor TScreenPartyWin.Create;
var
  I, R, S, DY: integer;
  TS: TThemeStatic;
begin
  inherited Create;

  TextScoreTeam1 := AddText (Theme.PartyWin.TextScoreTeam1);
  TextScoreTeam2 := AddText (Theme.PartyWin.TextScoreTeam2);
  TextScoreTeam3 := AddText (Theme.PartyWin.TextScoreTeam3);
  TextNameTeam1 := AddText (Theme.PartyWin.TextNameTeam1);
  TextNameTeam2 := AddText (Theme.PartyWin.TextNameTeam2);
  TextNameTeam3 := AddText (Theme.PartyWin.TextNameTeam3);

  StaticTeam1 := AddStatic (Theme.PartyWin.StaticTeam1);
  StaticTeam1BG := AddStatic (Theme.PartyWin.StaticTeam1BG);
  StaticTeam1Deco := AddStatic (Theme.PartyWin.StaticTeam1Deco);
  StaticTeam2 := AddStatic (Theme.PartyWin.StaticTeam2);
  StaticTeam2BG := AddStatic (Theme.PartyWin.StaticTeam2BG);
  StaticTeam2Deco := AddStatic (Theme.PartyWin.StaticTeam2Deco);
  StaticTeam3 := AddStatic (Theme.PartyWin.StaticTeam3);
  StaticTeam3BG := AddStatic (Theme.PartyWin.StaticTeam3BG);
  StaticTeam3Deco := AddStatic (Theme.PartyWin.StaticTeam3Deco);

  TextWinner := AddText (Theme.PartyWin.TextWinner);

  // draw: statics of the bigger rows, moved down to the lower rows
  for R := 0 to 2 do
    for S := 0 to 2 do
    begin
      RowBar[R, S] := -1;
      RowBG[R, S] := -1;
      RowDeco[R, S] := -1;
    end;
  RowBar[0, 0] := StaticTeam1;
  RowBG[0, 0] := StaticTeam1BG;
  RowDeco[0, 0] := StaticTeam1Deco;
  RowBar[1, 1] := StaticTeam2;
  RowBG[1, 1] := StaticTeam2BG;
  RowDeco[1, 1] := StaticTeam2Deco;
  RowBar[2, 2] := StaticTeam3;
  RowBG[2, 2] := StaticTeam3BG;
  RowDeco[2, 2] := StaticTeam3Deco;
  for R := 1 to 2 do
    for S := 0 to R - 1 do
    begin
      DY := ThemeRowBG(R).Y - ThemeRowBG(S).Y;
      TS := ThemeRowBar(S);
      TS.Y := TS.Y + DY;
      RowBar[R, S] := AddStatic(TS);
      TS := ThemeRowBG(S);
      TS.Y := TS.Y + DY;
      RowBG[R, S] := AddStatic(TS);
      TS := ThemeRowDeco(S);
      TS.Y := TS.Y + DY;
      RowDeco[R, S] := AddStatic(TS);
    end;

  LoadFromTheme(Theme.PartyWin);

  // "x of y rounds won" below the bar of each team (left aligned with the name)
  TextRoundsTeam[0] := AddText(Theme.PartyWin.TextNameTeam1.X, Theme.PartyWin.StaticTeam1BG.Y + Theme.PartyWin.StaticTeam1BG.H + 2,
    0, 0, Theme.PartyWin.TextNameTeam1.Font, 0, 20, 1, 1, 1, 0, '', false, 0, 0, false);
  TextRoundsTeam[1] := AddText(Theme.PartyWin.TextNameTeam2.X, Theme.PartyWin.StaticTeam2BG.Y + Theme.PartyWin.StaticTeam2BG.H + 2,
    0, 0, Theme.PartyWin.TextNameTeam2.Font, 0, 20, 1, 1, 1, 0, '', false, 0, 0, false);
  TextRoundsTeam[2] := AddText(Theme.PartyWin.TextNameTeam3.X, Theme.PartyWin.StaticTeam3BG.Y + Theme.PartyWin.StaticTeam3BG.H + 2,
    0, 0, Theme.PartyWin.TextNameTeam3.Font, 0, 20, 1, 1, 1, 0, '', false, 0, 0, false);

  // page 2: four boxes (2 x 2) below the banner, colored in the team color
  // of the person in OnShow; white texts
  for I := 0 to 3 do
  begin
    StaticBest[I] := AddStatic(BEST_X[I mod 2], BEST_Y[I div 2], BEST_W, BEST_H, 1, 1, 1,
      Skin.GetTextureFileName('PartyPlayerButton'), TEXTURE_TYPE_TRANSPARENT);
    TextBestCategory[I] := AddText(BEST_X[I mod 2] + 18, BEST_Y[I div 2] + 10, 0, 0,
      Theme.PartyWin.TextNameTeam1.Font, 0, 22, 1, 1, 1, 0, '', false, 0, 0, false);
    TextBestName[I] := AddText(BEST_X[I mod 2] + 18, BEST_Y[I div 2] + 40, 0, 0,
      Theme.PartyWin.TextNameTeam1.Font, 0, 44, 1, 1, 1, 0, '', false, 0, 0, false);
    TextBestInfo[I] := AddText(BEST_X[I mod 2] + 18, BEST_Y[I div 2] + 100, 0, 0,
      Theme.PartyWin.TextNameTeam1.Font, 0, 20, 1, 1, 1, 0, '', false, 0, 0, false);
  end;

  // the subtitle from the theme is replaced by "Final score after X rounds";
  // the legend says "continue" while page 2 follows
  SubtitleText := -1;
  LegendText := -1;
  for I := 0 to High(Text) do
  begin
    if (Text[I].Text = Language.Translate('PARTY_WIN_DESC')) then
      SubtitleText := I;
    if (Text[I].Text = Language.Translate('PARTY_WIN_LEGEND_CONTINUE')) then
      LegendText := I;
  end;
end;

{ page 2: hides the teams and shows the best performances of the party }
procedure TScreenPartyWin.ShowBestPage;
begin
  Page := 2;

  Text[TextScoreTeam1].Visible := false;
  Text[TextScoreTeam2].Visible := false;
  Text[TextScoreTeam3].Visible := false;
  Text[TextNameTeam1].Visible := false;
  Text[TextNameTeam2].Visible := false;
  Text[TextNameTeam3].Visible := false;
  HideTeamRows;
  Text[TextRoundsTeam[0]].Visible := false;
  Text[TextRoundsTeam[1]].Visible := false;
  Text[TextRoundsTeam[2]].Visible := false;

  Text[TextWinner].Text := Language.Translate('PARTY_WIN_BEST_TITLE');
  if (SubtitleText >= 0) then
    Text[SubtitleText].Text := Language.Translate('PARTY_WIN_BEST_SUBTITLE');
  if (LegendText >= 0) then
    Text[LegendText].Text := Language.Translate('PARTY_WIN_LEGEND_CONTINUE');

  ArrangeBestBoxes;
  SetBestVisible(true);
end;

{ places the boxes of the categories with a value one after another without
  gaps: 4 -> 2 x 2, 3 -> two at the top and one centered below,
  2 -> side by side, 1 -> centered }
procedure TScreenPartyWin.ArrangeBestBoxes;
var
  I, Pos, Count: integer;
  X, Y: real;
begin
  Count := 0;
  for I := 0 to 3 do
    if (Party.Best[I].Score > 0) then
      Inc(Count);

  Pos := 0;
  for I := 0 to 3 do
    if (Party.Best[I].Score > 0) then
    begin
      Y := BEST_Y[Pos div 2];
      // centered: the only box, or the last box of an odd number
      if (Count = 1) or ((Count = 3) and (Pos = 2)) then
        X := (BEST_X[0] + BEST_X[1]) / 2
      else
        X := BEST_X[Pos mod 2];
      // with up to two boxes they stand in the middle of the free space
      if (Count <= 2) then
        Y := (BEST_Y[0] + BEST_Y[1]) / 2;
      MoveBestBox(I, X, Y);
      Inc(Pos);
    end;
end;

procedure TScreenPartyWin.MoveBestBox(Index: integer; X, Y: real);
begin
  Statics[StaticBest[Index]].Texture.X := X;
  Statics[StaticBest[Index]].Texture.Y := Y;
  Text[TextBestCategory[Index]].X := X + 18;
  Text[TextBestCategory[Index]].Y := Y + 10;
  Text[TextBestName[Index]].X := X + 18;
  Text[TextBestName[Index]].Y := Y + 40;
  Text[TextBestInfo[Index]].X := X + 18;
  Text[TextBestInfo[Index]].Y := Y + 100;
end;

const
  PARTY_WIN_APPLAUSE_DELAY = 1300; // ms: applause after the fanfare

{ boxes of page 2 are shown only for categories with a value }
procedure TScreenPartyWin.SetBestVisible(Show: boolean);
var
  I: integer;
  V: boolean;
begin
  for I := 0 to 3 do
  begin
    V := Show and (Party.Best[I].Score > 0);
    Statics[StaticBest[I]].Visible := V;
    Text[TextBestCategory[I]].Visible := V;
    Text[TextBestName[I]].Visible := V;
    Text[TextBestInfo[I]].Visible := V;
  end;
end;

function TScreenPartyWin.Draw: boolean;
begin
  if not ApplausePlayed and (SDL_GetTicks() - ShowTime >= PARTY_WIN_APPLAUSE_DELAY) then
  begin
    ApplausePlayed := true;
    AudioPlayback.PlaySound(SoundLib.Applause);
  end;
  Result := inherited Draw;
end;

procedure TScreenPartyWin.HideTeamRows;
var
  R, S: integer;
begin
  Text[TextScoreTeam1].Visible := false;
  Text[TextScoreTeam2].Visible := false;
  Text[TextScoreTeam3].Visible := false;
  Text[TextNameTeam1].Visible := false;
  Text[TextNameTeam2].Visible := false;
  Text[TextNameTeam3].Visible := false;
  for R := 0 to 2 do
    for S := 0 to 2 do
    begin
      if (RowBar[R, S] >= 0) then
        Statics[RowBar[R, S]].Visible := false;
      if (RowBG[R, S] >= 0) then
        Statics[RowBG[R, S]].Visible := false;
      if (RowDeco[R, S] >= 0) then
        Statics[RowDeco[R, S]].Visible := false;
    end;
end;

{ shows the team in row Row (0..2) in the size and with the medal of row Size }
procedure TScreenPartyWin.ShowTeamRow(Row, Size, Team: integer);
var
  C, NameText, ScoreText: integer;
  DY: integer;
  TT: TThemeText;
begin
  if (Size < 0) or (Size > Row) or (RowBar[Row, Size] < 0) then
    Size := Row;
  DY := ThemeRowBG(Row).Y - ThemeRowBG(Size).Y;

  case Row of
    0: begin NameText := TextNameTeam1; ScoreText := TextScoreTeam1; end;
    1: begin NameText := TextNameTeam2; ScoreText := TextScoreTeam2; end;
    else begin NameText := TextNameTeam3; ScoreText := TextScoreTeam3; end;
  end;

  TT := ThemeRowName(Size);
  Text[NameText].X := TT.X;
  Text[NameText].Y := TT.Y + DY;
  Text[NameText].Size := TT.Size;
  Text[NameText].Text := Party.Teams[Team].Name;
  Text[NameText].Visible := true;

  TT := ThemeRowScore(Size);
  Text[ScoreText].X := TT.X;
  Text[ScoreText].Y := TT.Y + DY;
  Text[ScoreText].Size := TT.Size;
  Text[ScoreText].Text := IntToStr(Party.Teams[Team].Score);
  Text[ScoreText].Visible := true;

  Text[TextRoundsTeam[Row]].X := ThemeRowName(Size).X;
  Text[TextRoundsTeam[Row]].Y := ThemeRowBG(Row).Y + ThemeRowBG(Size).H + 2;

  Statics[RowBar[Row, Size]].Visible := true;
  Statics[RowBG[Row, Size]].Visible := true;
  Statics[RowDeco[Row, Size]].Visible := true;

  // bar and background in the team color
  C := ColorExists('P' + IntToStr(Team + 1) + 'Dark');
  if (C >= 0) then
  begin
    if (ThemeRowBG(Size).Color = 'TeamColor') then
    begin
      Statics[RowBG[Row, Size]].Texture.ColR := Color[C].RGB.R;
      Statics[RowBG[Row, Size]].Texture.ColG := Color[C].RGB.G;
      Statics[RowBG[Row, Size]].Texture.ColB := Color[C].RGB.B;
    end;
    if (ThemeRowBar(Size).Color = 'TeamColor') then
    begin
      Statics[RowBar[Row, Size]].Texture.ColR := Color[C].RGB.R;
      Statics[RowBar[Row, Size]].Texture.ColG := Color[C].RGB.G;
      Statics[RowBar[Row, Size]].Texture.ColB := Color[C].RGB.B;
    end;
  end;
end;

procedure TScreenPartyWin.OnShow;
const
  BEST_KEYS: array[0..3] of string = ('PARTY_WIN_BEST_TOTAL', 'PARTY_WIN_BEST_NOTES',
    'PARTY_WIN_BEST_GOLDEN', 'PARTY_WIN_BEST_LINE');
var
 I, J: integer;
 Ranking: AParty_TeamRanking;
 WinnerCount: integer;

begin
  inherited;

  if not Help.SetHelpID(ID) then
    Log.LogWarn('No Entry for Help-ID ' + ID, 'ScreenPartyWin');

  // get team ranking
  // Ranking is sorted by score
  Ranking := Party.GetTeamRanking;

  //Set Winnertext: "<team> wins the party!" or "Draw: <teams>"
  WinnerCount := 0;
  for I := 0 to High(Ranking) do
    if (Ranking[I].Rank = PR_First) then
      Inc(WinnerCount);
  if (WinnerCount > 1) then
    Text[TextWinner].Text := Format(Language.Translate('PARTY_WIN_DRAW'), [Party.GetWinnerString(-1)])
  else
    Text[TextWinner].Text := Format(Language.Translate('PARTY_WIN_WINNER'), [Party.GetWinnerString(-1)]);

  if (SubtitleText >= 0) then
    Text[SubtitleText].Text := Format(Language.Translate('PARTY_WIN_FINAL'), [Length(Party.Rounds)]);

  // rounds won by each team (in the order of the ranking, like the bars)
  for I := 0 to 2 do
  begin
    Text[TextRoundsTeam[I]].Visible := (I <= High(Ranking));
    if (I <= High(Ranking)) then
      Text[TextRoundsTeam[I]].Text := Format(Language.Translate('PARTY_WIN_ROUNDS'),
        [Party.RoundsWon(Ranking[I].Team), Length(Party.Rounds)]);
  end;

  // page 2: best performances of the party (only complete songs count)
  Page := 1;
  HasBest := false;
  for I := 0 to 3 do
  begin
    if (Party.Best[I].Score > 0) then
      HasBest := true;
    Text[TextBestCategory[I]].Text := Language.Translate(BEST_KEYS[I]);
    Text[TextBestName[I]].Text := ShortenName(Party.Best[I].Name, 20);
    Text[TextBestInfo[I]].Text := Format(Language.Translate('PARTY_WIN_BEST_INFO'),
      [Party.Best[I].Score, ShortenName(Party.Best[I].Song, 28)]);
    // (no color lookup without a team: "P0Dark" does not exist and the
    //  result -1 does not fit into a cardinal)
    J := -1;
    if (Party.Best[I].Team >= 0) then
      J := ColorExists('P' + IntToStr(Party.Best[I].Team + 1) + 'Dark');
    if (J >= 0) then
    begin
      Statics[StaticBest[I]].Texture.ColR := Color[J].RGB.R;
      Statics[StaticBest[I]].Texture.ColG := Color[J].RGB.G;
      Statics[StaticBest[I]].Texture.ColB := Color[J].RGB.B;
    end;
  end;
  SetBestVisible(false);
  if (LegendText >= 0) then
  begin
    if HasBest then
      Text[LegendText].Text := Language.Translate('PARTY_WIN_LEGEND_NEXT')
    else
      Text[LegendText].Text := Language.Translate('PARTY_WIN_LEGEND_CONTINUE');
  end;

  // fanfare first, then applause (Draw)
  ShowTime := SDL_GetTicks();
  ApplausePlayed := false;
  if (SoundLib.PartyFanfare <> nil) then
    AudioPlayback.PlaySound(SoundLib.PartyFanfare)
  else
  begin
    ApplausePlayed := true;
    AudioPlayback.PlaySound(SoundLib.Applause);
  end;
  // teams in the order of the ranking; with a draw the lower row gets the
  // size and the medal of the first row with the same rank
  HideTeamRows;
  for I := 0 to 2 do
    if (I <= High(Ranking)) then
    begin
      J := I;
      while (J > 0) and (Ranking[J - 1].Rank = Ranking[I].Rank) do
        Dec(J);
      ShowTeamRow(I, J, Ranking[I].Team);
    end;
end;

end.
