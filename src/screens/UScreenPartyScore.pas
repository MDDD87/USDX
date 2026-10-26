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
 * $URL: https://ultrastardx.svn.sourceforge.net/svnroot/ultrastardx/trunk/src/screens/UScreenPartyScore.pas $
 * $Id: UScreenPartyScore.pas 2654 2010-10-10 11:46:53Z b_krueger $
 *}

unit UScreenPartyScore;

interface

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

{$I switches.inc}

uses
  UDisplay,
  UIni,
  UMenu,
  UMusic,
  URenderer,
  UThemes,
  sdl2,
  SysUtils;

type
  TScreenPartyScore = class(TMenu)
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

      // "+1" etc. right of each team: party points of this round
      TextRoundPoints:   array[0..2] of cardinal;
      // index of the subtitle text ("Points of the last round"), -1 if not found
      SubtitleText:      integer;

      // the team scores first show the old total; after a short time they
      // switch to the new total including this round (with a "ding")
      ShowTime:          cardinal;
      PointsCounted:     boolean;

      DecoTex:          array[0..UIni.IMaxPlayerCount-1] of TTexture;
      DecoColor:        array[0..UIni.IMaxPlayerCount-1] of Record
                                        R, G, B: real;
                        end;

      MaxScore:          word;

      procedure ShowNewTotals;
      constructor Create; override;
      destructor Destroy; override;
      function ParseInput(PressedKey: cardinal; CharCode: UCS4Char; PressedDown: boolean): boolean; override;
      procedure OnShow; override;
      function Draw: boolean; override;
  end;

const
  ID='ID_034';   //for help system

implementation

uses
  UGraphic,
  UHelp,
  ULanguage,
  ULog,
  UMain,
  UParty,
  USkins,
  USong,
  UUnicodeUtils;

function TScreenPartyScore.ParseInput(PressedKey: cardinal; CharCode: UCS4Char; PressedDown: boolean): boolean;
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

          Party.NextRound; //< go to next round

          if (not Party.GameFinished) then
          begin
            FadeTo(@ScreenPartyNewRound);
          end
          else
          begin
            FadeTo(@ScreenPartyWin);
          end;
        end;
      SDLK_TAB:
        begin
          ScreenPopupHelp.ShowPopup();
        end;
    end;
  end;
end;

constructor TScreenPartyScore.Create;
var
  R, G, B: real;
  Color: integer;
  I: integer;
begin
  inherited Create;

  TextScoreTeam1 := AddText (Theme.PartyScore.TextScoreTeam1);
  TextScoreTeam2 := AddText (Theme.PartyScore.TextScoreTeam2);
  TextScoreTeam3 := AddText (Theme.PartyScore.TextScoreTeam3);
  TextNameTeam1 := AddText (Theme.PartyScore.TextNameTeam1);
  TextNameTeam2 := AddText (Theme.PartyScore.TextNameTeam2);
  TextNameTeam3 := AddText (Theme.PartyScore.TextNameTeam3);

  StaticTeam1 := AddStatic (Theme.PartyScore.StaticTeam1);
  StaticTeam1BG := AddStatic (Theme.PartyScore.StaticTeam1BG);
  StaticTeam1Deco := AddStatic (Theme.PartyScore.StaticTeam1Deco);
  StaticTeam2 := AddStatic (Theme.PartyScore.StaticTeam2);
  StaticTeam2BG := AddStatic (Theme.PartyScore.StaticTeam2BG);
  StaticTeam2Deco := AddStatic (Theme.PartyScore.StaticTeam2Deco);
  StaticTeam3 := AddStatic (Theme.PartyScore.StaticTeam3);
  StaticTeam3BG := AddStatic (Theme.PartyScore.StaticTeam3BG);
  StaticTeam3Deco := AddStatic (Theme.PartyScore.StaticTeam3Deco);

  TextWinner := AddText (Theme.PartyScore.TextWinner);

  //Load Deco Textures
  if Theme.PartyScore.DecoTextures.ChangeTextures then
  begin
    //Get Color
    LoadColor(R, G, B, Theme.PartyScore.DecoTextures.FirstColor);
    Color := $10000 * Round(R*255) + $100 * Round(G*255) + Round(B*255);
    DecoColor[0].R := R;
    DecoColor[0].G := G;
    DecoColor[0].B := B;

    //Load Texture
    DecoTex[0] := Renderer.LoadTexture(Skin.GetTextureFileName(Theme.PartyScore.DecoTextures.FirstTexture), Theme.PartyScore.DecoTextures.FirstTyp, Color);

    //Get Second Color
    LoadColor(R, G, B, Theme.PartyScore.DecoTextures.SecondColor);
    Color := $10000 * Round(R*255) + $100 * Round(G*255) + Round(B*255);
    DecoColor[1].R := R;
    DecoColor[1].G := G;
    DecoColor[1].B := B;

    //Load Second Texture
    DecoTex[1] := Renderer.LoadTexture(Skin.GetTextureFileName(Theme.PartyScore.DecoTextures.SecondTexture), Theme.PartyScore.DecoTextures.SecondTyp, Color);

    //Get Third Color
    LoadColor(R, G, B, Theme.PartyScore.DecoTextures.ThirdColor);
    Color := $10000 * Round(R*255) + $100 * Round(G*255) + Round(B*255);
    DecoColor[2].R := R;
    DecoColor[2].G := G;
    DecoColor[2].B := B;

    //Load Third Texture
    DecoTex[2] := Renderer.LoadTexture(Skin.GetTextureFileName(Theme.PartyScore.DecoTextures.ThirdTexture), Theme.PartyScore.DecoTextures.ThirdTyp, Color);
  end;

  LoadFromTheme(Theme.PartyScore);

  // round points ("+1") right of the deco medal of each team
  TextRoundPoints[0] := AddText(Theme.PartyScore.TextScoreTeam1.X + 72, Theme.PartyScore.TextScoreTeam1.Y, 0, 0,
    Theme.PartyScore.TextScoreTeam1.Font, Theme.PartyScore.TextScoreTeam1.Style, Theme.PartyScore.TextScoreTeam1.Size,
    1, 0.85, 0.3, 0, '', false, 0, 0, false);
  TextRoundPoints[1] := AddText(Theme.PartyScore.TextScoreTeam2.X + 72, Theme.PartyScore.TextScoreTeam2.Y, 0, 0,
    Theme.PartyScore.TextScoreTeam2.Font, Theme.PartyScore.TextScoreTeam2.Style, Theme.PartyScore.TextScoreTeam2.Size,
    1, 0.85, 0.3, 0, '', false, 0, 0, false);
  TextRoundPoints[2] := AddText(Theme.PartyScore.TextScoreTeam3.X + 72, Theme.PartyScore.TextScoreTeam3.Y, 0, 0,
    Theme.PartyScore.TextScoreTeam3.Font, Theme.PartyScore.TextScoreTeam3.Style, Theme.PartyScore.TextScoreTeam3.Size,
    1, 0.85, 0.3, 0, '', false, 0, 0, false);

  // the subtitle from the theme is replaced by "Round X of Y: <round type>"
  SubtitleText := -1;
  for I := 0 to High(Text) do
    if (Text[I].Text = Language.Translate('PARTY_SCORE_DESC')) then
    begin
      SubtitleText := I;
      Break;
    end;
end;

destructor TScreenPartyScore.Destroy();
begin
  DecoTex[0].Free;
  DecoTex[1].Free;
  Decotex[2].Free;
  inherited;
end;

const
  PARTY_SCORE_COUNT_DELAY = 2500; // ms after the screen appears (after the applause)

{ the points of this round are added by Party.NextRound (GenScores) after this
  screen. First the old total and "+1" are shown, then the new total. }
procedure TScreenPartyScore.ShowNewTotals;
var
  Points: integer;
begin
  PointsCounted := true;
  Points := 0;
  if (Length(Party.Teams) >= 1) then
  begin
    Text[TextScoreTeam1].Text := IntToStr(Party.Teams[0].Score + Party.RoundPoints(0));
    Inc(Points, Party.RoundPoints(0));
  end;
  if (Length(Party.Teams) >= 2) then
  begin
    Text[TextScoreTeam2].Text := IntToStr(Party.Teams[1].Score + Party.RoundPoints(1));
    Inc(Points, Party.RoundPoints(1));
  end;
  if (Length(Party.Teams) >= 3) then
  begin
    Text[TextScoreTeam3].Text := IntToStr(Party.Teams[2].Score + Party.RoundPoints(2));
    Inc(Points, Party.RoundPoints(2));
  end;

  // the "+N" has been added to the total now; hide it (shown again in OnShow)
  Text[TextRoundPoints[0]].Visible := false;
  Text[TextRoundPoints[1]].Visible := false;
  Text[TextRoundPoints[2]].Visible := false;

  if (Points > 0) then
    AudioPlayback.PlaySound(SoundLib.ScoreNotes);
end;

function TScreenPartyScore.Draw: boolean;
begin
  if not PointsCounted and (SDL_GetTicks() - ShowTime >= PARTY_SCORE_COUNT_DELAY) then
    ShowNewTotals;
  Result := inherited Draw;
end;

procedure TScreenPartyScore.OnShow;
var
  Ranking: AParty_TeamRanking;
  I: integer;
begin
  inherited;

  if not Help.SetHelpID(ID) then
    Log.LogWarn('No Entry for Help-ID ' + ID, 'ScreenPartyScore');

  // restart time
  //if (ScreenSong.Mode = smPartyTournament) then
  //  ScreenSong.CurrentPartyTime := 0;

  // indicate that round is finished
  Party.RoundPlayed;

  // get rankings for current round
  Ranking := Party.Rounds[Party.CurrentRound].Ranking;

  // "Round X of Y: <round type>" instead of "Points of the last round."
  if (SubtitleText >= 0) then
    Text[SubtitleText].Text := Party.RoundCaption(Party.CurrentRound);

  // the points of this round are added by Party.NextRound (GenScores) after
  // this screen; show the new total and the points of this round now
  for I := 0 to 2 do
  begin
    Text[TextRoundPoints[I]].Visible := (I <= High(Party.Teams));
    if (I <= High(Party.Teams)) then
    begin
      Text[TextRoundPoints[I]].Text := '+' + IntToStr(Party.RoundPoints(I));
      if (Party.RoundPoints(I) > 0) then
        Text[TextRoundPoints[I]].Alpha := 1
      else
        Text[TextRoundPoints[I]].Alpha := 0.5;
    end;
  end;

  //Set Winnertext
  Text[TextWinner].Text := Format(Language.Translate('PARTY_SCORE_WINS'), [Party.GetWinnerString(Party.CurrentRound)]);

  if (Length(Party.Teams) >= 1) then
  begin
    Text[TextScoreTeam1].Text := InttoStr(Party.Teams[0].Score); // new total follows in ShowNewTotals
    Text[TextNameTeam1].Text := Utf8String(Party.Teams[0].Name);

    //Set Deco Texture
    if Theme.PartyScore.DecoTextures.ChangeTextures then
    begin
      if (Length(Ranking) >= 1) and (Ranking[0].Rank >= 1) and (Ranking[0].Rank <= Length(DecoTex)) then
      begin
        DecoTex[Ranking[0].Rank-1].X := Statics[StaticTeam1Deco].Texture.X;
        DecoTex[Ranking[0].Rank-1].Y := Statics[StaticTeam1Deco].Texture.Y;
        DecoTex[Ranking[0].Rank-1].W := Statics[StaticTeam1Deco].Texture.W;
        DecoTex[Ranking[0].Rank-1].H := Statics[StaticTeam1Deco].Texture.H;
        Statics[StaticTeam1Deco].Texture.Free;
        Statics[StaticTeam1Deco].Texture := DecoTex[Ranking[0].Rank-1].Clone;
        Statics[StaticTeam1Deco].Texture.ColR := DecoColor[Ranking[0].Rank-1].R;
        Statics[StaticTeam1Deco].Texture.ColG := DecoColor[Ranking[0].Rank-1].G;
        Statics[StaticTeam1Deco].Texture.ColB := DecoColor[Ranking[0].Rank-1].B;
      end;
    end;

    Text[TextScoreTeam1].Visible := true;
    Text[TextNameTeam1].Visible := true;
    Statics[StaticTeam1].Visible := true;
    Statics[StaticTeam1BG].Visible := true;
    Statics[StaticTeam1Deco].Visible := true;
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
    Text[TextScoreTeam2].Text := InttoStr(Party.Teams[1].Score); // new total follows in ShowNewTotals
    Text[TextNameTeam2].Text := UTF8String(Party.Teams[1].Name);

    //Set Deco Texture
    if Theme.PartyScore.DecoTextures.ChangeTextures then
    begin
      if (Length(Ranking) >= 2) and (Ranking[1].Rank >= 1) and (Ranking[1].Rank <= Length(DecoTex)) then
      begin
        DecoTex[Ranking[1].Rank-1].X := Statics[StaticTeam2Deco].Texture.X;
        DecoTex[Ranking[1].Rank-1].Y := Statics[StaticTeam2Deco].Texture.Y;
        DecoTex[Ranking[1].Rank-1].W := Statics[StaticTeam2Deco].Texture.W;
        DecoTex[Ranking[1].Rank-1].H := Statics[StaticTeam2Deco].Texture.H;
        Statics[StaticTeam2Deco].Texture.Free;
        Statics[StaticTeam2Deco].Texture := DecoTex[Ranking[1].Rank-1].Clone;
        Statics[StaticTeam2Deco].Texture.ColR := DecoColor[Ranking[1].Rank-1].R;
        Statics[StaticTeam2Deco].Texture.ColG := DecoColor[Ranking[1].Rank-1].G;
        Statics[StaticTeam2Deco].Texture.ColB := DecoColor[Ranking[1].Rank-1].B;

      end;
    end;

    Text[TextScoreTeam2].Visible := true;
    Text[TextNameTeam2].Visible := true;
    Statics[StaticTeam2].Visible := true;
    Statics[StaticTeam2BG].Visible := true;
    Statics[StaticTeam2Deco].Visible := true;
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
    Text[TextScoreTeam3].Text := InttoStr(Party.Teams[2].Score); // new total follows in ShowNewTotals
    Text[TextNameTeam3].Text := UTF8String(Party.Teams[2].Name);

    //Set Deco Texture
    if Theme.PartyScore.DecoTextures.ChangeTextures then
    begin
      if (Length(Ranking) >= 3) and (Ranking[2].Rank >= 1) and (Ranking[2].Rank <= Length(DecoTex)) then
      begin
        DecoTex[Ranking[2].Rank-1].X := Statics[StaticTeam3Deco].Texture.X;
        DecoTex[Ranking[2].Rank-1].Y := Statics[StaticTeam3Deco].Texture.Y;
        DecoTex[Ranking[2].Rank-1].W := Statics[StaticTeam3Deco].Texture.W;
        DecoTex[Ranking[2].Rank-1].H := Statics[StaticTeam3Deco].Texture.H;
        Statics[StaticTeam3Deco].Texture.Free;
        Statics[StaticTeam3Deco].Texture := DecoTex[Ranking[2].Rank-1].Clone;
        Statics[StaticTeam3Deco].Texture.ColR := DecoColor[Ranking[2].Rank-1].R;
        Statics[StaticTeam3Deco].Texture.ColG := DecoColor[Ranking[2].Rank-1].G;
        Statics[StaticTeam3Deco].Texture.ColB := DecoColor[Ranking[2].Rank-1].B;
      end;
    end;

    Text[TextScoreTeam3].Visible := true;
    Text[TextNameTeam3].Visible := true;
    Statics[StaticTeam3].Visible := true;
    Statics[StaticTeam3BG].Visible := true;
    Statics[StaticTeam3Deco].Visible := true;
  end
  else
  begin
    Text[TextScoreTeam3].Visible := false;
    Text[TextNameTeam3].Visible := false;
    Statics[StaticTeam3].Visible := false;
    Statics[StaticTeam3BG].Visible := false;
    Statics[StaticTeam3Deco].Visible := false;
  end;

  ShowTime := SDL_GetTicks();
  PointsCounted := false;
  // applause for the winner first, the points are added afterwards (Draw)
  AudioPlayback.PlaySound(SoundLib.Applause);

  // the score and highscore screens play the sung song (Feature 1b);
  // stop it, the party score screen only plays the background music
  AudioPlayback.Stop;

  //start Background-Music
  SoundLib.StartBgMusic;
end;

end.
