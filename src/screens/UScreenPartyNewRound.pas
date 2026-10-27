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
 * $URL: https://ultrastardx.svn.sourceforge.net/svnroot/ultrastardx/trunk/src/screens/UScreenPartyNewRound.pas $
 * $Id: UScreenPartyNewRound.pas 2246 2010-04-18 13:43:36Z tobigun $
 *}

unit UScreenPartyNewRound;

interface

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

{$I switches.inc}

uses
  UDisplay,
  UFiles,
  UMenu,
  UMusic,
  UThemes,
  sdl2,
  SysUtils;

type
  TScreenPartyNewRound = class(TMenu)
    private
      VisibleRound:  Integer;

    public
      //Texts:
      TextRound: array [0..6] of cardinal;

      TextWinner: array [0..6] of cardinal;

      TextNextRound: cardinal;
      TextNextRoundNo: cardinal;
      // "Singing:" label left of the next singers
      TextSingers: cardinal;
      // index of the subtitle text ("Next players to the mics!"), -1 if not found
      SubtitleText: integer;
      TextNextPlayer1: cardinal;
      TextNextPlayer2: cardinal;
      TextNextPlayer3: cardinal;

      //Statics
      StaticRound: array [0..6] of cardinal;

      //Scores
      TextScoreTeam1: cardinal;
      TextScoreTeam2: cardinal;
      TextScoreTeam3: cardinal;
      TextNameTeam1: cardinal;
      TextNameTeam2: cardinal;
      TextNameTeam3: cardinal;

      TextTeam1Players: cardinal;
      TextTeam2Players: cardinal;
      TextTeam3Players: cardinal;

      StaticTeam1: cardinal;
      StaticTeam2: cardinal;
      StaticTeam3: cardinal;
      StaticNextPlayer1: cardinal;
      StaticNextPlayer2: cardinal;
      StaticNextPlayer3: cardinal;

      // duet announcement (Feature 4)
      StaticRoundBox:    integer;  //< "Round X of Y" box (theme), -1 if not found
      StaticRuleBox:     integer;  //< rule box (theme), -1 if not found
      StaticTableHead:   integer;  //< head of the round table (theme), -1 if not found
      TextTableRound:    integer;  //< "Round" (theme), -1 if not found
      TextTableWinner:   integer;  //< "Winner" (theme), -1 if not found
      TextDuetTeam:      cardinal; //< "<team>'s turn!"
      TextDuetVoice:     array[0..1] of cardinal; //< "sings <voice>" (in the box)
      TextDuetMic:       array[0..1] of cardinal; //< "Mic 1" (above the box)



      constructor Create; override;
      function ParseInput(PressedKey: cardinal; CharCode: UCS4Char; PressedDown: boolean): boolean; override;
      procedure OnShow; override;
      procedure Refresh;
      { duet round (Feature 4): overview of all pairs or announcement of
        the team that sings next (after the song was chosen) }
      function DuetAnnouncement: boolean;
      procedure ShowDuet;
      { duet announcement: simplified screen in the middle (song, team,
        singers with mic and voice); SetDuetLayout(false) restores the
        normal layout }
      procedure SetDuetLayout(Announce: boolean);
      procedure ShowPassMedleyOrder;
  end;

const
  ID='ID_033';   //for help system

implementation

uses
  UGraphic,
  UHelp,
  UIni,
  USongs,
  ULanguage,
  ULog,
  UMain,
  UParty,
  USong,
  UUnicodeUtils;

function TScreenPartyNewRound.ParseInput(PressedKey: cardinal; CharCode: UCS4Char; PressedDown: boolean): boolean;
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
      SDLK_BACKSPACE :
        begin
          AudioPlayback.PlaySound(SoundLib.Back);
          CheckFadeTo(@ScreenMain,'MSG_END_PARTY');
        end;

      SDLK_TAB:
        begin
          ScreenPopupHelp.ShowPopup();
        end;

      SDLK_RETURN:
        begin
          AudioPlayback.PlaySound(SoundLib.Start);
          if DuetAnnouncement then
          begin
            // next team sings the chosen duet song
            Party.StartDuetPass;
            CatSongs.Selected := Party.DuetSong;
            SoundLib.PauseBgMusic;
            FadeTo(@ScreenSing);
          end
          else
            Party.CallBeforeSongSelect;
        end;

      SDLK_UP:
        begin
         if VisibleRound > 0 then
         begin
           Dec(VisibleRound);
           Refresh;
         end;
        end;

      SDLK_DOWN:
        begin
          if VisibleRound < (Length(Party.Rounds) - 7) then
          begin
            Inc(VisibleRound);
            Refresh;
          end;
        end;
    end;
  end;
end;

procedure TScreenPartyNewRound.Refresh;
var
  N, I: Integer;
  NumRounds: Integer;
begin
  //Set Visibility of Round Infos
  NumRounds := Length(Party.Rounds);

  N := VisibleRound;

  if ((NumRounds-7) < N) then
  begin
    N := NumRounds - 7;
    VisibleRound := N;
  end;

  if (N < 0) then
  begin
    N := 0;
    VisibleRound := 0;
  end;

  //Set Visibility of Round Infos
  for I := 0 to 6 do
  begin
    if (I <= High(Party.Rounds)) then
    begin
      Statics[StaticRound[I]].Visible := True;
      Text[TextRound[I]].Visible := True;
      Text[TextWinner[I]].Visible := True;

      // update texts:
      Text[TextRound[I]].Text := IntToStr(I + 1 + N)+') ' + Language.Translate('MODE_' + uppercase(Party.Modes[Party.Rounds[I + N].Mode].Name) + '_NAME');
      // long names (e.g. "Pass the Micro-Medley") must not run into the winner column
      if (LengthUTF8(Text[TextRound[I]].Text) > 17) then
        Text[TextRound[I]].Size := Theme.PartyNewRound.TextRound1.Size * 17 / LengthUTF8(Text[TextRound[I]].Text)
      else
        Text[TextRound[I]].Size := Theme.PartyNewRound.TextRound1.Size;
      Text[TextWinner[I]].Text := Party.GetWinnerString(I + N);
    end
    else
    begin
      Statics[StaticRound[I]].Visible := False;
      Text[TextRound[I]].Visible := False;
      Text[TextWinner[I]].Visible := False;
    end;
  end;
end;

constructor TScreenPartyNewRound.Create;
var
  ThemeStaticBase, ThemeTextBase: integer;
  I: integer;
begin
  inherited Create;

  TextRound[0] := AddText (Theme.PartyNewRound.TextRound1);
  TextRound[1] := AddText (Theme.PartyNewRound.TextRound2);
  TextRound[2] := AddText (Theme.PartyNewRound.TextRound3);
  TextRound[3] := AddText (Theme.PartyNewRound.TextRound4);
  TextRound[4] := AddText (Theme.PartyNewRound.TextRound5);
  TextRound[5] := AddText (Theme.PartyNewRound.TextRound6);
  TextRound[6] := AddText (Theme.PartyNewRound.TextRound7);

  TextWinner[0] := AddText (Theme.PartyNewRound.TextWinner1);
  TextWinner[1] := AddText (Theme.PartyNewRound.TextWinner2);
  TextWinner[2] := AddText (Theme.PartyNewRound.TextWinner3);
  TextWinner[3] := AddText (Theme.PartyNewRound.TextWinner4);
  TextWinner[4] := AddText (Theme.PartyNewRound.TextWinner5);
  TextWinner[5] := AddText (Theme.PartyNewRound.TextWinner6);
  TextWinner[6] := AddText (Theme.PartyNewRound.TextWinner7);

  TextNextRound := AddText (Theme.PartyNewRound.TextNextRound);
  TextNextRoundNo := AddText (Theme.PartyNewRound.TextNextRoundNo);
  TextNextPlayer1 := AddText (Theme.PartyNewRound.TextNextPlayer1);
  TextNextPlayer2 := AddText (Theme.PartyNewRound.TextNextPlayer2);
  TextNextPlayer3 := AddText (Theme.PartyNewRound.TextNextPlayer3);

  StaticRound[0] := AddStatic (Theme.PartyNewRound.StaticRound1);
  StaticRound[1] := AddStatic (Theme.PartyNewRound.StaticRound2);
  StaticRound[2] := AddStatic (Theme.PartyNewRound.StaticRound3);
  StaticRound[3] := AddStatic (Theme.PartyNewRound.StaticRound4);
  StaticRound[4] := AddStatic (Theme.PartyNewRound.StaticRound5);
  StaticRound[5] := AddStatic (Theme.PartyNewRound.StaticRound6);
  StaticRound[6] := AddStatic (Theme.PartyNewRound.StaticRound7);

  //Scores
  TextScoreTeam1 := AddText (Theme.PartyNewRound.TextScoreTeam1);
  TextScoreTeam2 := AddText (Theme.PartyNewRound.TextScoreTeam2);
  TextScoreTeam3 := AddText (Theme.PartyNewRound.TextScoreTeam3);
  TextNameTeam1 := AddText (Theme.PartyNewRound.TextNameTeam1);
  TextNameTeam2 := AddText (Theme.PartyNewRound.TextNameTeam2);
  TextNameTeam3 := AddText (Theme.PartyNewRound.TextNameTeam3);

  //Players
  TextTeam1Players := AddText (Theme.PartyNewRound.TextTeam1Players);
  TextTeam2Players := AddText (Theme.PartyNewRound.TextTeam2Players);
  TextTeam3Players := AddText (Theme.PartyNewRound.TextTeam3Players);

  StaticTeam1 := AddStatic (Theme.PartyNewRound.StaticTeam1);
  StaticTeam2 := AddStatic (Theme.PartyNewRound.StaticTeam2);
  StaticTeam3 := AddStatic (Theme.PartyNewRound.StaticTeam3);
  StaticNextPlayer1 := AddStatic (Theme.PartyNewRound.StaticNextPlayer1);
  StaticNextPlayer2 := AddStatic (Theme.PartyNewRound.StaticNextPlayer2);
  StaticNextPlayer3 := AddStatic (Theme.PartyNewRound.StaticNextPlayer3);

  ThemeStaticBase := Length(Statics);
  ThemeTextBase := Length(Text);
  LoadFromTheme(Theme.PartyNewRound);

  // theme elements that the duet announcement moves or hides
  StaticRoundBox := -1;
  StaticRuleBox := -1;
  StaticTableHead := -1;
  for I := 0 to High(Theme.PartyNewRound.Statics) do
  begin
    if (Theme.PartyNewRound.Statics[I].Tex = 'PartyRoundBG3') then
      StaticRoundBox := ThemeStaticBase + I
    else if (Theme.PartyNewRound.Statics[I].Tex = 'PartyRoundBG4') then
      StaticRuleBox := ThemeStaticBase + I
    else if (Theme.PartyNewRound.Statics[I].Tex = 'PartyRoundBG1') then
      StaticTableHead := ThemeStaticBase + I;
  end;
  TextTableRound := -1;
  TextTableWinner := -1;
  for I := ThemeTextBase to High(Text) do
  begin
    if (Text[I].Text = Language.Translate('PARTY_ROUND')) then
      TextTableRound := I
    else if (Text[I].Text = Language.Translate('PARTY_ROUND_WINNER')) then
      TextTableWinner := I;
  end;

  TextDuetTeam := AddText(400, 240, 0, 0, Theme.PartyNewRound.TextNextRound.Font, 0, 40,
    1, 1, 1, 1, '', false, 0, 0, false);
  TextDuetVoice[0] := AddText(290, 362, 0, 0, Theme.PartyNewRound.TextNextRound.Font, 0, 22,
    1, 1, 1, 1, '', false, 0, 0, false);
  TextDuetVoice[1] := AddText(510, 362, 0, 0, Theme.PartyNewRound.TextNextRound.Font, 0, 22,
    1, 1, 1, 1, '', false, 0, 0, false);
  TextDuetMic[0] := AddText(265, 278, 0, 0, Theme.PartyNewRound.TextNextRound.Font, 0, 22,
    1, 1, 1, 1, '', false, 0, 0, false);
  TextDuetMic[1] := AddText(535, 278, 0, 0, Theme.PartyNewRound.TextNextRound.Font, 0, 22,
    1, 1, 1, 1, '', false, 0, 0, false);
  Text[TextDuetTeam].Visible := false;
  Text[TextDuetVoice[0]].Visible := false;
  Text[TextDuetVoice[1]].Visible := false;
  Text[TextDuetMic[0]].Visible := false;
  Text[TextDuetMic[1]].Visible := false;

  // label left of the boxes with the next singers
  TextSingers := AddText(Theme.PartyNewRound.StaticNextPlayer1.X - 10,
    Theme.PartyNewRound.StaticNextPlayer1.Y + 12, 0, 0,
    Theme.PartyNewRound.TextNextRound.Font, Theme.PartyNewRound.TextNextRound.Style, 22,
    1, 1, 1, 2, Language.Translate('PARTY_ROUND_SINGERS'), false, 0, 0, false);

  // the subtitle from the theme is replaced by "Round X of Y: <round type>"
  SubtitleText := -1;
  for I := 0 to High(Text) do
    if (Text[I].Text = Language.Translate('PARTY_ROUND_DESC')) then
    begin
      SubtitleText := I;
      Break;
    end;
end;

procedure TScreenPartyNewRound.OnShow;
  function GetTeamPlayers(const Num: integer): UTF8String;
  var
    Players: array of UTF8String;
    J: integer;
  begin
    if (Num > High(Party.Teams)) or (Num < 0) then
      exit;

    //Create Players array
    SetLength(Players, Length(Party.Teams[Num].Players));
    For J := 0 to High(Party.Teams[Num].Players) do
      Players[J] := UTF8String(Party.Teams[Num].Players[J].Name);

    //Implode and Return
    Result := Language.Implode(Players);
  end;
begin
  inherited;

  if not Help.SetHelpID(ID) then
    Log.LogWarn('No Entry for Help-ID ' + ID, 'ScreenPartyNewRound');

  if (Party.CurrentRound > 0) then
  begin
    if (Party.CurrentRound > 1) then
      VisibleRound := Party.CurrentRound - 2
    else
      VisibleRound := Party.CurrentRound - 1;
  end;

  Refresh;

  //Display Scores
  if (Length(Party.Teams) >= 1) then
  begin
    Text[TextScoreTeam1].Text := InttoStr(Party.Teams[0].Score);
    Text[TextNameTeam1].Text := UTF8String(Party.Teams[0].Name);
    Text[TextTeam1Players].Text := GetTeamPlayers(0);

    Text[TextScoreTeam1].Visible := true;
    Text[TextNameTeam1].Visible := true;
    Text[TextTeam1Players].Visible := true;
    Statics[StaticTeam1].Visible := true;
    Statics[StaticNextPlayer1].Visible := true;
  end
  else
  begin
    Text[TextScoreTeam1].Visible := false;
    Text[TextNameTeam1].Visible := false;
    Text[TextTeam1Players].Visible := false;
    Statics[StaticTeam1].Visible := false;
    Statics[StaticNextPlayer1].Visible := false;
  end;

  if (Length(Party.Teams) >= 2) then
  begin
    Text[TextScoreTeam2].Text := InttoStr(Party.Teams[1].Score);
    Text[TextNameTeam2].Text := UTF8String(Party.Teams[1].Name);
    Text[TextTeam2Players].Text := GetTeamPlayers(1);

    Text[TextScoreTeam2].Visible := true;
    Text[TextNameTeam2].Visible := true;
    Text[TextTeam2Players].Visible := true;
    Statics[StaticTeam2].Visible := true;
    Statics[StaticNextPlayer2].Visible := true;
  end
  else
  begin
    Text[TextScoreTeam2].Visible := false;
    Text[TextNameTeam2].Visible := false;
    Text[TextTeam2Players].Visible := false;
    Statics[StaticTeam2].Visible := false;
    Statics[StaticNextPlayer2].Visible := false;
  end;

  if (Length(Party.Teams) >= 3) then
  begin
    Text[TextScoreTeam3].Text := InttoStr(Party.Teams[2].Score);
    Text[TextNameTeam3].Text := UTF8String(Party.Teams[2].Name);
    Text[TextTeam3Players].Text := GetTeamPlayers(2);

    Text[TextScoreTeam3].Visible := true;
    Text[TextNameTeam3].Visible := true;
    Text[TextTeam3Players].Visible := true;
    Statics[StaticTeam3].Visible := true;
    Statics[StaticNextPlayer3].Visible := true;
  end
  else
  begin
    Text[TextScoreTeam3].Visible := false;
    Text[TextNameTeam3].Visible := false;
    Text[TextTeam3Players].Visible := false;
    Statics[StaticTeam3].Visible := false;
    Statics[StaticNextPlayer3].Visible := false;
  end;

  //nextRound Texts
  Text[TextNextRound].Text := Language.Translate('MODE_' + uppercase(Party.Modes[Party.Rounds[Party.CurrentRound].Mode].Name) + '_DESC');

  // the table below the subtitle shows the current standings; the round box
  // shows "Round X of Y: <round type>", so it is clear what comes next
  if (SubtitleText >= 0) then
    Text[SubtitleText].Text := Language.Translate('PARTY_ROUND_STANDINGS');

  Text[TextNextRoundNo].Text := Party.RoundCaption(Party.CurrentRound);
  if (Length(Party.Teams) >= 1) then
  begin
    Text[TextNextPlayer1].Text := Party.Teams[0].Players[Party.Teams[0].NextPlayer].Name;
    Text[TextNextPlayer1].Visible := true;
  end
  else
    Text[TextNextPlayer1].Visible := false;

  if (Length(Party.Teams) >= 2) then
  begin
    Text[TextNextPlayer2].Text := Party.Teams[1].Players[Party.Teams[1].NextPlayer].Name;
    Text[TextNextPlayer2].Visible := true;
  end
  else
    Text[TextNextPlayer2].Visible := false;

  if (Length(Party.Teams) >= 3) then
  begin
    Text[TextNextPlayer3].Text := Party.Teams[2].Players[Party.Teams[2].NextPlayer].Name;
    Text[TextNextPlayer3].Visible := true;
  end
  else
    Text[TextNextPlayer3].Visible := false;

  // normal size of the singer names (changed in duet rounds)
  Text[TextNextPlayer1].Size := Theme.PartyNewRound.TextNextPlayer1.Size;
  Text[TextNextPlayer2].Size := Theme.PartyNewRound.TextNextPlayer2.Size;
  Text[TextNextPlayer3].Size := Theme.PartyNewRound.TextNextPlayer3.Size;
  Text[TextNextPlayer1].Y := Theme.PartyNewRound.TextNextPlayer1.Y;
  Text[TextNextPlayer2].Y := Theme.PartyNewRound.TextNextPlayer2.Y;
  Text[TextNextPlayer3].Y := Theme.PartyNewRound.TextNextPlayer3.Y;

  SetDuetLayout(false);
  if Party.IsDuetRound then
    ShowDuet
  else if Party.IsPassMedleyRound then
    ShowPassMedleyOrder;
end;

{ Pass the Medley: the order of the singers of each team ("Anna, Toni") }
procedure TScreenPartyNewRound.ShowPassMedleyOrder;
var
  T, J, N: integer;
  Names: UTF8String;
  NameText: array[0..2] of cardinal;
begin
  NameText[0] := TextNextPlayer1;
  NameText[1] := TextNextPlayer2;
  NameText[2] := TextNextPlayer3;
  for T := 0 to High(Party.Teams) do
    if (T <= 2) then
    begin
      Names := '';
      N := Length(Party.Teams[T].Players);
      for J := 0 to N - 1 do
      begin
        if (Names <> '') then
          Names := Names + ', ';
        Names := Names + ShortenName(UTF8String(Party.Teams[T].Players[Party.PassMedleySinger(T, J)].Name), 8);
      end;
      Text[NameText[T]].Text := Names;
      Text[NameText[T]].Size := 18;
      Text[NameText[T]].Y := Text[NameText[T]].Y + 6;
    end;
end;

procedure TScreenPartyNewRound.SetDuetLayout(Announce: boolean);
var
  I: integer;
  Show: boolean;

  procedure PlaceStatic(Index: integer; X, Y, W, H: real);
  begin
    if (Index < 0) or (Index > High(Statics)) then
      Exit;
    Statics[Index].Texture.X := X;
    Statics[Index].Texture.Y := Y;
    Statics[Index].Texture.W := W;
    Statics[Index].Texture.H := H;
  end;

  procedure PlaceStaticTheme(Index: integer; const TS: TThemeStatic);
  begin
    PlaceStatic(Index, TS.X, TS.Y, TS.W, TS.H);
  end;

  procedure SetStaticVisible(Index: integer; V: boolean);
  begin
    if (Index >= 0) and (Index <= High(Statics)) then
      Statics[Index].Visible := V;
  end;

  procedure SetTextVisible(Index: integer; V: boolean);
  begin
    if (Index >= 0) and (Index <= High(Text)) then
      Text[Index].Visible := V;
  end;

  function ThemeStaticByTex(const Tex: string): TThemeStatic;
  var
    K: integer;
  begin
    Result := Theme.PartyNewRound.StaticNextPlayer1;
    for K := 0 to High(Theme.PartyNewRound.Statics) do
      if (Theme.PartyNewRound.Statics[K].Tex = Tex) then
        Result := Theme.PartyNewRound.Statics[K];
  end;

begin
  Show := not Announce;

  // standings, round table and "Singing:" only in the normal layout
  SetTextVisible(TextScoreTeam1, Show and (Length(Party.Teams) >= 1));
  SetTextVisible(TextScoreTeam2, Show and (Length(Party.Teams) >= 2));
  SetTextVisible(TextScoreTeam3, Show and (Length(Party.Teams) >= 3));
  SetTextVisible(TextNameTeam1, Show and (Length(Party.Teams) >= 1));
  SetTextVisible(TextNameTeam2, Show and (Length(Party.Teams) >= 2));
  SetTextVisible(TextNameTeam3, Show and (Length(Party.Teams) >= 3));
  SetTextVisible(TextTeam1Players, Show and (Length(Party.Teams) >= 1));
  SetTextVisible(TextTeam2Players, Show and (Length(Party.Teams) >= 2));
  SetTextVisible(TextTeam3Players, Show and (Length(Party.Teams) >= 3));
  SetStaticVisible(StaticTeam1, Show and (Length(Party.Teams) >= 1));
  SetStaticVisible(StaticTeam2, Show and (Length(Party.Teams) >= 2));
  SetStaticVisible(StaticTeam3, Show and (Length(Party.Teams) >= 3));
  SetStaticVisible(StaticTableHead, Show);
  SetTextVisible(TextTableRound, Show);
  SetTextVisible(TextTableWinner, Show);
  SetTextVisible(TextSingers, Show);
  if Announce then
    for I := 0 to High(TextRound) do
    begin
      Text[TextRound[I]].Visible := false;
      Text[TextWinner[I]].Visible := false;
      Statics[StaticRound[I]].Visible := false;
    end;

  Text[TextDuetTeam].Visible := Announce;
  Text[TextDuetVoice[0]].Visible := Announce;
  Text[TextDuetVoice[1]].Visible := Announce;
  Text[TextDuetMic[0]].Visible := Announce;
  Text[TextDuetMic[1]].Visible := Announce;
  // no reflection under the singer boxes in the announcement
  Statics[StaticNextPlayer1].Reflection := not Announce and Theme.PartyNewRound.StaticNextPlayer1.Reflection;
  Statics[StaticNextPlayer2].Reflection := not Announce and Theme.PartyNewRound.StaticNextPlayer2.Reflection;

  if Announce then
  begin
    // everything in the middle of the screen
    // round, song, team; "Mic 1"/"Mic 2" above the boxes, in each box the
    // singer and below the name the voice
    PlaceStatic(StaticRoundBox, 160, 120, 480, 46);
    Text[TextNextRoundNo].Y := 126;
    PlaceStatic(StaticRuleBox, 50, 172, 700, 36);
    Text[TextNextRound].Y := 177;
    Text[TextDuetTeam].Y := 220;
    PlaceStatic(StaticNextPlayer1, 135, 304, 260, 84);
    PlaceStatic(StaticNextPlayer2, 405, 304, 260, 84);
    Text[TextNextPlayer1].X := 265;
    Text[TextNextPlayer2].X := 535;
    Text[TextNextPlayer1].Y := 310;
    Text[TextNextPlayer2].Y := 310;
    Text[TextDuetVoice[0]].X := 265;
    Text[TextDuetVoice[1]].X := 535;
    Text[TextDuetVoice[0]].Y := 354;
    Text[TextDuetVoice[1]].Y := 354;
    Text[TextNextPlayer1].Visible := true;
    Text[TextNextPlayer2].Visible := true;
    Text[TextNextPlayer3].Visible := false;
    Statics[StaticNextPlayer1].Visible := true;
    Statics[StaticNextPlayer2].Visible := true;
    Statics[StaticNextPlayer3].Visible := false;
  end
  else
  begin
    PlaceStaticTheme(StaticRoundBox, ThemeStaticByTex('PartyRoundBG3'));
    PlaceStaticTheme(StaticRuleBox, ThemeStaticByTex('PartyRoundBG4'));
    Text[TextNextRoundNo].Y := Theme.PartyNewRound.TextNextRoundNo.Y;
    Text[TextNextRound].Y := Theme.PartyNewRound.TextNextRound.Y;
    PlaceStaticTheme(StaticNextPlayer1, Theme.PartyNewRound.StaticNextPlayer1);
    PlaceStaticTheme(StaticNextPlayer2, Theme.PartyNewRound.StaticNextPlayer2);
    PlaceStaticTheme(StaticNextPlayer3, Theme.PartyNewRound.StaticNextPlayer3);
    Text[TextNextPlayer1].X := Theme.PartyNewRound.TextNextPlayer1.X;
    Text[TextNextPlayer2].X := Theme.PartyNewRound.TextNextPlayer2.X;
    Text[TextNextPlayer3].X := Theme.PartyNewRound.TextNextPlayer3.X;
  end;
end;

function TScreenPartyNewRound.DuetAnnouncement: boolean;
begin
  Result := Party.IsDuetRound and (Party.DuetSong >= 0) and Party.DuetPassesLeft;
end;

procedure TScreenPartyNewRound.ShowDuet;
const
  DUET_NAME_SIZE = 20;
  DUET_NAME_MAXLEN = 9;
var
  T, Team: integer;
  Voice1, Voice2, SongName: UTF8String;
  NameText: array[0..2] of cardinal;
begin
  NameText[0] := TextNextPlayer1;
  NameText[1] := TextNextPlayer2;
  NameText[2] := TextNextPlayer3;

  if DuetAnnouncement then
  begin
    // announcement: simplified screen with the team that sings next;
    // box 1 (blue) = mic 1 = P1, box 2 (red) = mic 2 = P2
    Team := Party.DuetNextTeam;
    SetDuetLayout(true);

    // the voices by the names in the song file (e.g. "Beyonce"), else P1/P2
    Voice1 := 'P1';
    Voice2 := 'P2';
    SongName := '';
    if (Party.DuetSong >= 0) and (Party.DuetSong <= High(CatSongs.Song)) then
    begin
      SongName := CatSongs.Song[Party.DuetSong].Artist + ' - ' + CatSongs.Song[Party.DuetSong].Title;
      if (Length(CatSongs.Song[Party.DuetSong].DuetNames) >= 2) then
      begin
        if (Trim(CatSongs.Song[Party.DuetSong].DuetNames[0]) <> '') then
          Voice1 := Trim(CatSongs.Song[Party.DuetSong].DuetNames[0]);
        if (Trim(CatSongs.Song[Party.DuetSong].DuetNames[1]) <> '') then
          Voice2 := Trim(CatSongs.Song[Party.DuetSong].DuetNames[1]);
      end;
    end;

    if (SubtitleText >= 0) then
      Text[SubtitleText].Text := Format(Language.Translate('PARTY_DUET_PASS'),
        [Party.DuetPassesDone + 1, Length(Party.Teams)]);
    Text[TextNextRound].Text := Format(Language.Translate('PARTY_DUET_SONG'), [SongName]);
    Text[TextDuetTeam].Text := Format(Language.Translate('PARTY_DUET_TURN'),
      [UTF8String(Party.Teams[Team].Name)]);
    Text[TextDuetVoice[0]].Text := Format(Language.Translate('PARTY_DUET_VOICE'), [ShortenName(Voice1, 22)]);
    Text[TextDuetVoice[1]].Text := Format(Language.Translate('PARTY_DUET_VOICE'), [ShortenName(Voice2, 22)]);
    Text[TextDuetMic[0]].Text := Format(Language.Translate('PARTY_DUET_MIC'), [1]);
    Text[TextDuetMic[1]].Text := Format(Language.Translate('PARTY_DUET_MIC'), [2]);

    Text[NameText[0]].Text := Party.DuetSingerName(Team, 0);
    Text[NameText[1]].Text := Party.DuetSingerName(Team, 1);

    // the background music plays while the singers get ready (stopped
    // before singing, see ParseInput)
    SoundLib.StartBgMusic;
  end
  else
  begin
    // overview: the pair of every team ("Anna & Toni") and which team starts
    Text[TextNextRound].Text := Format(Language.Translate('PARTY_DUET_OVERVIEW'),
      [UTF8String(Party.Teams[Party.DuetNextTeam].Name)]);
    for T := 0 to High(Party.Teams) do
      if (T <= 2) then
      begin
        Text[NameText[T]].Text := ShortenName(Party.DuetSingerName(T, 0), DUET_NAME_MAXLEN) +
          ' & ' + ShortenName(Party.DuetSingerName(T, 1), DUET_NAME_MAXLEN);
        Text[NameText[T]].Size := DUET_NAME_SIZE;
        // smaller text: keep it in the middle of the box
        Text[NameText[T]].Y := Text[NameText[T]].Y + 5;
      end;
  end;
end;

end.
