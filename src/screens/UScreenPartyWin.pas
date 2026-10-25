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

      // "x of y rounds won" below each team and the best performance
      TextRoundsTeam:    array[0..2] of cardinal;
      TextBest:          cardinal;
      // index of the subtitle text, -1 if not found
      SubtitleText:      integer;

      // fanfare, then applause
      ShowTime:          cardinal;
      ApplausePlayed:    boolean;

      constructor Create; override;
      function ParseInput(PressedKey: cardinal; CharCode: UCS4Char; PressedDown: boolean): boolean; override;
      procedure OnShow; override;
      function Draw: boolean; override;
  end;

const
  ID='ID_035';   //for help system

implementation

uses
  UGraphic,
  UHelp,
  ULanguage,
  ULog,
  UMain,
  UParty,
  UUnicodeUtils;

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
          AudioPlayback.PlaySound(SoundLib.Start);
          FadeTo(@ScreenMain);
        end;
      SDLK_TAB:
        begin
          ScreenPopupHelp.ShowPopup();
        end;
    end;
  end;
end;

constructor TScreenPartyWin.Create;
var
  I: integer;
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

  LoadFromTheme(Theme.PartyWin);

  // "x of y rounds won" below the bar of each team (left aligned with the name)
  TextRoundsTeam[0] := AddText(Theme.PartyWin.TextNameTeam1.X, Theme.PartyWin.StaticTeam1BG.Y + Theme.PartyWin.StaticTeam1BG.H + 2,
    0, 0, Theme.PartyWin.TextNameTeam1.Font, 0, 20, 1, 1, 1, 0, '', false, 0, 0, false);
  TextRoundsTeam[1] := AddText(Theme.PartyWin.TextNameTeam2.X, Theme.PartyWin.StaticTeam2BG.Y + Theme.PartyWin.StaticTeam2BG.H + 2,
    0, 0, Theme.PartyWin.TextNameTeam2.Font, 0, 20, 1, 1, 1, 0, '', false, 0, 0, false);
  TextRoundsTeam[2] := AddText(Theme.PartyWin.TextNameTeam3.X, Theme.PartyWin.StaticTeam3BG.Y + Theme.PartyWin.StaticTeam3BG.H + 2,
    0, 0, Theme.PartyWin.TextNameTeam3.Font, 0, 20, 1, 1, 1, 0, '', false, 0, 0, false);

  // best performance of the party, below the teams
  TextBest := AddText(400, 485, 0, 0, Theme.PartyWin.TextNameTeam1.Font, 0, 22, 1, 0.85, 0.3, 1, '', false, 0, 0, false);

  // the subtitle from the theme is replaced by "Final score after X rounds"
  SubtitleText := -1;
  for I := 0 to High(Text) do
    if (Text[I].Text = Language.Translate('PARTY_WIN_DESC')) then
    begin
      SubtitleText := I;
      Break;
    end;
end;

const
  PARTY_WIN_APPLAUSE_DELAY = 1300; // ms: applause after the fanfare

function TScreenPartyWin.Draw: boolean;
begin
  if not ApplausePlayed and (SDL_GetTicks() - ShowTime >= PARTY_WIN_APPLAUSE_DELAY) then
  begin
    ApplausePlayed := true;
    AudioPlayback.PlaySound(SoundLib.Applause);
  end;
  Result := inherited Draw;
end;

procedure TScreenPartyWin.OnShow;
var
 I: integer;
 Ranking: AParty_TeamRanking;
 WinnerCount: integer;

  Function GetTeamColor(Team: integer): cardinal;
  var
    NameString: string;
  begin
    NameString := 'P' + InttoStr(Team+1) + 'Dark';

    Result := ColorExists(NameString);
  end;

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

  // best single performance of the party
  Text[TextBest].Visible := (Party.BestScore > 0);
  if (Party.BestScore > 0) then
    Text[TextBest].Text := Format(Language.Translate('PARTY_WIN_BEST'),
      [Party.BestName, Party.BestScore, Party.BestSong]);

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
  if (Length(Party.Teams) >= 1) then
  begin
    Text[TextScoreTeam1].Text := IntToStr(Party.Teams[Ranking[0].Team].Score);
    Text[TextNameTeam1].Text := Party.Teams[Ranking[0].Team].Name;

    Text[TextScoreTeam1].Visible := true;
    Text[TextNameTeam1].Visible := true;
    Statics[StaticTeam1].Visible := true;
    Statics[StaticTeam1BG].Visible := true;
    Statics[StaticTeam1Deco].Visible := true;

    //Set Static Color to Team Color
    if (Theme.PartyWin.StaticTeam1BG.Color = 'TeamColor') then
    begin
      I := GetTeamColor(Ranking[0].Team);
      if (I <> -1) then
      begin
        Statics[StaticTeam1BG].Texture.ColR := Color[I].RGB.R;
        Statics[StaticTeam1BG].Texture.ColG := Color[I].RGB.G;
        Statics[StaticTeam1BG].Texture.ColB := Color[I].RGB.B;
      end;
    end;

    if (Theme.PartyWin.StaticTeam1.Color = 'TeamColor') then
    begin
      I := GetTeamColor(Ranking[0].Team);
      if (I <> -1) then
      begin
        Statics[StaticTeam1].Texture.ColR := Color[I].RGB.R;
        Statics[StaticTeam1].Texture.ColG := Color[I].RGB.G;
        Statics[StaticTeam1].Texture.ColB := Color[I].RGB.B;
      end;
    end;
  end
  else
  begin
    Text[TextScoreTeam1].Visible := false;
    Text[TextNameTeam1].Visible := false;
    Statics[StaticTeam1].Visible := false;
    Statics[StaticTeam1BG].Visible := false;
    Statics[StaticTeam1Deco].Visible := false;
  end;

  if (Length(Party.Teams) >= 2) then
  begin
    Text[TextScoreTeam2].Text := IntToStr(Party.Teams[Ranking[1].Team].Score);
    Text[TextNameTeam2].Text := Party.Teams[Ranking[1].Team].Name;

    Text[TextScoreTeam2].Visible := true;
    Text[TextNameTeam2].Visible := true;
    Statics[StaticTeam2].Visible := true;
    Statics[StaticTeam2BG].Visible := true;
    Statics[StaticTeam2Deco].Visible := true;

    //Set Static Color to Team Color
    if (Theme.PartyWin.StaticTeam2BG.Color = 'TeamColor') then
    begin
      I := GetTeamColor(Ranking[1].Team);
      if (I <> -1) then
      begin
        Statics[StaticTeam2BG].Texture.ColR := Color[I].RGB.R;
        Statics[StaticTeam2BG].Texture.ColG := Color[I].RGB.G;
        Statics[StaticTeam2BG].Texture.ColB := Color[I].RGB.B;
      end;
    end;

    if (Theme.PartyWin.StaticTeam2.Color = 'TeamColor') then
    begin
      I := GetTeamColor(Ranking[1].Team);
      if (I <> -1) then
      begin
        Statics[StaticTeam2].Texture.ColR := Color[I].RGB.R;
        Statics[StaticTeam2].Texture.ColG := Color[I].RGB.G;
        Statics[StaticTeam2].Texture.ColB := Color[I].RGB.B;
      end;
    end;
  end
  else
  begin
    Text[TextScoreTeam2].Visible := false;
    Text[TextNameTeam2].Visible := false;
    Statics[StaticTeam2].Visible := false;
    Statics[StaticTeam2BG].Visible := false;
    Statics[StaticTeam2Deco].Visible := false;
  end;

  if (Length(Party.Teams) >= 3) then
  begin
    Text[TextScoreTeam3].Text := IntToStr(Party.Teams[Ranking[2].Team].Score);
    Text[TextNameTeam3].Text := Party.Teams[Ranking[2].Team].Name;

    Text[TextScoreTeam3].Visible := true;
    Text[TextNameTeam3].Visible := true;
    Statics[StaticTeam3].Visible := true;
    Statics[StaticTeam3BG].Visible := true;
    Statics[StaticTeam3Deco].Visible := true;

    //Set Static Color to Team Color
    if (Theme.PartyWin.StaticTeam3BG.Color = 'TeamColor') then
    begin
      I := GetTeamColor(Ranking[2].Team);
      if (I <> -1) then
      begin
        Statics[StaticTeam3BG].Texture.ColR := Color[I].RGB.R;
        Statics[StaticTeam3BG].Texture.ColG := Color[I].RGB.G;
        Statics[StaticTeam3BG].Texture.ColB := Color[I].RGB.B;
      end;
    end;

    if (Theme.PartyWin.StaticTeam3.Color = 'TeamColor') then
    begin
      I := GetTeamColor(Ranking[2].Team);
      if (I <> -1) then
      begin
        Statics[StaticTeam3].Texture.ColR := Color[I].RGB.R;
        Statics[StaticTeam3].Texture.ColG := Color[I].RGB.G;
        Statics[StaticTeam3].Texture.ColB := Color[I].RGB.B;
      end;
    end;
  end
  else
  begin
    Text[TextScoreTeam3].Visible := false;
    Text[TextNameTeam3].Visible := false;
    Statics[StaticTeam3].Visible := false;
    Statics[StaticTeam3BG].Visible := false;
    Statics[StaticTeam3Deco].Visible := false;
  end;
end;

end.
