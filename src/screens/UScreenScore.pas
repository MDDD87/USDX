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
 * $URL: https://ultrastardx.svn.sourceforge.net/svnroot/ultrastardx/trunk/src/screens/UScreenScore.pas $
 * $Id: UScreenScore.pas 2246 2010-04-18 13:43:36Z tobigun $
 *}

unit UScreenScore;

interface
{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}
{$I switches.inc}

uses
  UCommon,
  UDataBase,
  UDisplay,
  UDLLManager,
  UIni,
  UMenu,
  UMusic,
  URenderer,
  USongs,
  UThemes,
  UWebSDK,
  math,
  sdl2,
  SysUtils;

const
  ZBars:            real = 0.8;   // Z value for the bars
  ZRatingPic:       real = 0.8;   // Z value for the rating pictures

  EaseOut_MaxSteps: real = 10;    // that's the speed of the bars (10 is fast | 100 is slower)

  // Time for raising the bar one step higher (in ms). Each of the three parts
  // (notes, line bonus, golden notes) has 100 steps, so 17 ms gives about
  // 5 seconds for the whole bar, matching the drum roll (SingStar style)
  BarRaiseSpeed:    cardinal = 17;

  // SingStar style sounds: applause after the bar is complete, then the
  // background music fades in (times in ms after the bar is complete)
  ScoreApplauseDelay: cardinal = 300;
  ScoreBgMusicDelay:  cardinal = 2000;
  ScoreBgMusicFade:   real     = 3.0;   // seconds
  // if the bar is completed earlier than this after the drum roll started
  // (key pressed), the drum roll is stopped instead of ringing out
  ScoreDrumRollMinTime: cardinal = 4500;

type
  TScoreBarType = (sbtScore, sbtLine, sbtGolden);
  TPlayerScoreScreenTexture = record            // holds all colorized textures for up to 6 players
    //Bar textures
    Score_NoteBarLevel_Dark:     TTexture;      // Note
    Score_NoteBarRound_Dark:     TTexture;      // that's the round thing on top

    Score_NoteBarLevel_Light:    TTexture;      // LineBonus | Phrasebonus
    Score_NoteBarRound_Light:    TTexture;

    Score_NoteBarLevel_Lightest: TTexture;      // GoldenNotes
    Score_NoteBarRound_Lightest: TTexture;
  end;

  TPlayerScoreScreenData = record               // holds the positions and other data
    Bar_Y:                  real;
    Bar_Actual_Height:      real;               // this one holds the actual height of the bar, while we animate it
    BarScore_ActualHeight:  real;
    BarLine_ActualHeight:   real;
    BarGolden_ActualHeight: real;
  end;

  TPlayerScoreRatingPics = record               // a fine array of the rating pictures
    RateEaseStep:  integer;
    RateEaseValue: real;
  end;

  { hold maps of players to the different positions }
  TPlayerPositionMap = record
    Position: byte; // 1..6: Position of Player; 0: no position (e.g. too little screens)
    Screen: byte;   // 0 - Screen 1; 1 - Screen 2
    BothScreens: boolean; // true if player is drawn on both screens
  end;
  APlayerPositionMap = array of TPlayerPositionMap;

  { textures for playerstatics of seconds screen players }
  TPlayerStaticTexture = record
    Tex: TTexture;
  end;

  TScreenScore = class(TMenu)
    private
      { holds position and screen of players(index)
        set by calling MapPlayerstoPosition() }
      PlayerPositionMap: APlayerPositionMap;

      BarTime:            cardinal;
      FinishScreenDraw:   boolean;
      PreviewEnd:         real;

      aPlayerScoreScreenTextures: array[1..UIni.IMaxPlayerCount] of TPlayerScoreScreenTexture;
      aPlayerScoreScreenDatas:    array[1..UIni.IMaxPlayerCount] of TPlayerScoreScreenData;
      aPlayerScoreScreenRatings:  array[1..UIni.IMaxPlayerCount] of TPlayerScoreRatingPics;

      BarScore_EaseOut_Step:  real;
      BarPhrase_EaseOut_Step: real;
      BarGolden_EaseOut_Step: real;

      TextArtist:             integer;
      TextTitle:              integer;

      TextArtistTitle:        integer;

      TextName:             array[1..UIni.IMaxPlayerCount] of integer;
      TextScore:            array[1..UIni.IMaxPlayerCount] of integer;

      TextNotes:            array[1..UIni.IMaxPlayerCount] of integer;
      TextNotesScore:       array[1..UIni.IMaxPlayerCount] of integer;
      TextLineBonus:        array[1..UIni.IMaxPlayerCount] of integer;
      TextLineBonusScore:   array[1..UIni.IMaxPlayerCount] of integer;
      TextGoldenNotes:      array[1..UIni.IMaxPlayerCount] of integer;
      TextGoldenNotesScore: array[1..UIni.IMaxPlayerCount] of integer;
      TextTotal:            array[1..UIni.IMaxPlayerCount] of integer;
      TextTotalScore:       array[1..UIni.IMaxPlayerCount] of integer;

      PlayerStatic:         array[1..UIni.IMaxPlayerCount] of array of integer;
      AvatarStatic:         array[1..UIni.IMaxPlayerCount] of integer;
      AvatarStaticRef:      array[1..UIni.IMaxPlayerCount] of Integer;
      { texture pairs for swapping when screens = 2
        first array level: index of player ( actually this is a position
          1    - Player 1 if PlayersPlay = 1 <- we don't need swapping here
          2..3 - Player 1 and 2 or 3 and 4 if PlayersPlay = 2 or 4
          4..6 - Player 1 - 3 or 4 - 6 if PlayersPlay = 3 or 6 )
        second array level: different playerstatics for positions
        third array level: texture for screen 1 or 2 }
      PlayerStaticTextures: array[1..UIni.IMaxPlayerCount] of array of array [1..2] of TPlayerStaticTexture;
      PlayerTexts:          array[1..UIni.IMaxPlayerCount] of array of integer;

      StaticBoxLightest:    array[1..UIni.IMaxPlayerCount] of integer;
      StaticBoxLight:       array[1..UIni.IMaxPlayerCount] of integer;
      StaticBoxDark:        array[1..UIni.IMaxPlayerCount] of integer;
      { texture pairs for swapping when screens = 2
        for boxes
        first array level: index of player ( actually this is a position
          1    - Player 1 if PlayersPlay = 1 <- we don't need swapping here
          2..3 - Player 1 and 2 or 3 and 4 if PlayersPlay = 2 or 4
          4..6 - Player 1 - 3 or 4 - 6 if PlayersPlay = 3 or 6 )
        second array level: different boxes for positions (0: lightest; 1: light; 2: dark)
        third array level: texture for screen 1 or 2 }
      PlayerBoxTextures: array[1..UIni.IMaxPlayerCount] of array[0..2] of array [1..2] of TPlayerStaticTexture;

      StaticBackLevel:      array[1..UIni.IMaxPlayerCount] of integer;
      StaticBackLevelRound: array[1..UIni.IMaxPlayerCount] of integer;
      StaticLevel:          array[1..UIni.IMaxPlayerCount] of integer;
      StaticLevelRound:     array[1..UIni.IMaxPlayerCount] of integer;

      Voice:                integer;

      TextScore_ActualValue:  array[1..UIni.IMaxPlayerCount] of integer;
      TextPhrase_ActualValue: array[1..UIni.IMaxPlayerCount] of integer;
      TextGolden_ActualValue: array[1..UIni.IMaxPlayerCount] of integer;

      ButtonSend: array[1..UIni.IMaxPlayerCount] of integer;
      CurrentRound:          integer;
      StaticNavigate:       integer;

      // SingStar style sounds: 0 = not started, 1 = drum roll (notes),
      // 2 = line bonus, 3 = golden notes, 4 = bar complete
      ScoreSoundStage:      integer;
      DrumRollStartTime:    cardinal;
      BarCompleteTime:      cardinal;
      ApplausePlayed:       boolean;
      BgMusicStarted:       boolean;
      MedleyBrowsed:        boolean; // medley: user browses the single songs
      TextNavigate:         integer;

      procedure RefreshTexts;
      procedure ResetScores;

      procedure StartPreview;
      procedure StartVoice;

      procedure MapPlayersToPosition;

      procedure FillPlayerItems(PlayerNumber: integer);
      function  IsPartyRound: boolean;
      procedure HideAvatarFrames(AvatarStatic: integer);
      function  GetPlayerDisplayName(PlayerIndex: integer): UTF8String;
      procedure LeaveScreen;

      procedure UpdateAnimation;

      // SingStar style sounds (drum roll, accents, applause, background music)
      procedure UpdateScoreSounds;
      procedure FinishScoreSounds;
      {****
       * helpers for bar easing
       *}
      procedure EaseBarIn(PlayerNumber: integer; BarType: TScoreBarType);
      procedure EaseScoreIn(PlayerNumber: integer; ScoreType: TScoreBarType);

      procedure DrawPlayerBars;

      procedure DrawBar(BarType: TScoreBarType; PlayerNumber: integer; BarStartPosY: single; NewHeight: real);

      {****
       * helpers for rating picture
       *}
      procedure ShowRating(PlayerNumber: integer);
      function  CalculateBouncing(PlayerNumber: integer): real;
      procedure DrawRating(PlayerNumber: integer; Rating: integer);

      { for player static texture swapping }
      procedure LoadSwapTextures;
      procedure SwapToScreen(Screen: integer);
    public
      constructor Create; override;
      destructor Destroy; override;
      function ParseInput(PressedKey: cardinal; CharCode: UCS4Char; PressedDown: boolean): boolean; override;
      function ParseMouse(MouseButton: Integer; BtnDown: Boolean; X, Y: integer): boolean; override;
      procedure OnShow; override;
      procedure OnHide; override;
      procedure OnShowFinish; override;
      function Draw: boolean; override;
  end;

const
  ID='ID_023';   //for help system

implementation

uses
  UAvatars,
  UGraphic,
  UHelp,
  ULanguage,
  ULog,
  UMenuStatic,
  UNote,
  UParty,
  UPathUtils,
  UScreenPopup,
  UScreenSong,
  USkins,
  USong,
  UTime,
  UUnicodeUtils;

{
 *****************************
 ** 100: NOT A VALID DLL :p
 ** 0: ERROR_CONNECT -> WEBSITE_NO_CONNECTION
 ** 1: OK_LOGIN
 ** 2: ERROR_LOGIN -> WEBSITE_LOGIN_ERROR
 ** 3: OK_SCORE -> WEBSITE_OK_SEND
 ** 4: ERROR_SCORE -> WEBSITE_ERROR_SCORE
 ** 5: ERROR_SCORE_DUPLICATED
 ** 6: OK_SONG
 ** 7: ERROR_SONG
 *****************************
}

procedure SendScore(SendInfo: TSendInfo; Website: integer);
var
  LoginInfo: TLoginInfo;
  SendStatus: integer;
  EncryptPassword: widestring;
begin

  // Encrypt Password (with username and password)
  LoginInfo.Username := SendInfo.Username;
  LoginInfo.Password := SendInfo.Password;

  DllMan.LoadWebsite(Website);

  if (ScreenPopUpSendScore.SelectValueU = High(ScreenPopUpSendScore.IUsername)) then
  begin
    EncryptPassword := DllMan.WebsiteEncryptPassword(LoginInfo);
    SendInfo.Password := EncryptPassword;
  end;

  SendStatus := DllMan.WebsiteSendScore(SendInfo);
  
  case SendStatus of
    0: ScreenPopupError.ShowPopup(Language.Translate('WEBSITE_NO_CONNECTION'));
    2: ScreenPopupError.ShowPopup(Language.Translate('WEBSITE_LOGIN_ERROR'));
    3: ScreenPopupInfo.ShowPopup(Language.Translate('WEBSITE_OK_SEND'));
    4: ScreenPopupError.ShowPopup(Language.Translate('WEBSITE_ERROR_SCORE'));
    5: ScreenPopupError.ShowPopup(Language.Translate('WEBSITE_ERROR_SCORE_DUPLICATED'));
    7: ScreenPopupError.ShowPopup(Language.Translate('WEBSITE_ERROR_SONG'));
  end;

  ScreenScore.Interaction := -1;
end;

procedure SaveScore(SendInfo: TSendInfo; Website: integer);
var
  LoginInfo: TLoginInfo;
  EncryptPassword: widestring;
  ScoreFile: TextFile;
  EncryptText: string;
  WebName: UTF8String;
begin
  // Encrypt Password (with username and password)
  LoginInfo.Username := SendInfo.Username;
  LoginInfo.Password := SendInfo.Password;

  DllMan.LoadWebsite(Website);

  if (ScreenPopUpSendScore.SelectValueU = High(ScreenPopUpSendScore.IUsername)) then
  begin
    EncryptPassword := DllMan.WebsiteEncryptPassword(LoginInfo);
    SendInfo.Password := EncryptPassword;
  end;

  WebName := UDataBase.DataBase.NetworkUser[Website].Website;

  EncryptText := DllMan.WebsiteEncryptScore(SendInfo);

  AssignFile(ScoreFile, WebScoresPath.Append(WebName + ' [Save Scores].txt').ToNative);

  if FileExists(WebScoresPath.Append(WebName + ' [Save Scores].txt').ToNative) then
    Append(ScoreFile)
  else
    Rewrite(ScoreFile);

  WriteLn(ScoreFile, DatetoStr(Now) + '|' + TimetoStr(Now) + '|' + EncryptText);

  Flush(ScoreFile);
  Close(ScoreFile);

  ScreenPopupInfo.ShowPopup(Language.Translate('WEBSITE_SAVE_SCORE'));

  ScreenScore.Interaction := -1;
end;

procedure OnSendScore(Value: integer; Data: Pointer);
var
  SendInfo: TSendInfo;
  Website, index: integer;
begin
  if CurrentSong.isDuet then
    Exit;

  if (Value = 1) or (Value = 2) then
  begin
    Website := ScreenPopUpSendScore.SelectValueW;

    if (ScreenPopUpSendScore.SelectValueU = High(ScreenPopUpSendScore.IUsername)) then
    begin
      SendInfo.Username := ScreenPopUpSendScore.Username;
      SendInfo.Password := ScreenPopUpSendScore.Password;
    end
    else
    begin
      SendInfo.Username := UDataBase.DataBase.NetworkUser[ScreenPopupSendScore.SelectValueW].UserList[ScreenPopupSendScore.SelectValueU].Username;
      SendInfo.Password := UDataBase.DataBase.NetworkUser[ScreenPopupSendScore.SelectValueW].UserList[ScreenPopupSendScore.SelectValueU].Password;
    end;

    index := ScreenPopupSendScore.SelectValueP;
    SendInfo.ScoreInt := player[index].ScoreInt;
    SendInfo.ScoreLineInt := player[index].ScoreLineInt;
    SendInfo.ScoreGoldenInt := player[index].ScoreGoldenInt;
    SendInfo.MD5Song := ScreenSing.Act_MD5Song;
    SendInfo.Level := player[index].Level;

    if (Value = 1) then
      SendScore(SendInfo, Website);

    if (Value = 2) then
      SaveScore(SendInfo, Website);
  end;
end;

function TScreenScore.ParseInput(PressedKey: cardinal; CharCode: UCS4Char; PressedDown: boolean): boolean;
begin
  Result := true;
  if (PressedDown) then
  begin
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
      SDLK_BACKSPACE:
        begin
          if (FinishScreenDraw = true) then
          begin
            LeaveScreen;
            Exit;
          end
          else
            BarTime := 0;
        end;

      SDLK_TAB:
        begin
          ScreenPopupHelp.ShowPopup();
        end;

      SDLK_RETURN:
        begin
         if (Interaction <> -1) then
            ScreenPopupSendScore.ShowPopup(Language.Translate('SCORE_SEND_DESC'), @OnSendScore, nil)
         else
         begin
           if (FinishScreenDraw = true) then
           begin

             LeaveScreen;

          	 Exit;
           end
           else
             BarTime := 0;
          end;
        end;

      // Up and Down could be done at the same time,
      // but I don't want to declare variables inside
      // functions like this one, called so many times
      SDLK_DOWN, SDLK_UP: Interaction := -1;

      SDLK_RIGHT:
        begin
          if ScreenSong.MedleyActive then
          begin
            if (CurrentRound < Length(PlaylistMedley.Stats)-1) then
              inc(CurrentRound)
            else
              CurrentRound := 0;

            AudioPlayback.PlaySound(SoundLib.Change);
            MedleyBrowsed := true;
            RefreshTexts;

            // SingStar style: no song preview on the score screen
            if (Ini.SavePlayback=1) then
              StartVoice;

          end
          else
          begin
            if (ScreenSing.SungToEnd) and (Length(DllMan.Websites) > 0) then
              InteractNext;
          end;
        end;

      SDLK_LEFT:
        begin
          if ScreenSong.MedleyActive then
          begin
            if (CurrentRound > 0) then
              dec(CurrentRound)
            else
              CurrentRound := Length(PlaylistMedley.Stats)-1;

            AudioPlayback.PlaySound(SoundLib.Change);
            MedleyBrowsed := true;
            RefreshTexts;

            // SingStar style: no song preview on the score screen
            if (Ini.SavePlayback=1) then
              StartVoice;

          end
          else
          begin
            if (ScreenSing.SungToEnd) and (Length(DllMan.Websites) > 0) then
              InteractPrev;
          end;

        end;

    end;
  end;
end;

function TScreenScore.ParseMouse(MouseButton: Integer; BtnDown: Boolean; X, Y: integer): boolean;
var
  button_s: integer;
begin
  Result := True;

  //TODO: adapt for players 7 to 12
  case PlayersPlay of
    1 : button_s := ButtonSend[1];
    2, 4: button_s := ButtonSend[2];
    3, 6: button_s := ButtonSend[3];
  else
    button_s := ButtonSend[3];
  end;

  // transfer mousecords to the 800x600 raster we use to draw
  X := Round((X / (ScreenW / Screens)) * RenderW);
  if (X > RenderW) then
    X := X - RenderW;
  Y := Round((Y / ScreenH) * RenderH);

  if (Button[button_s].Visible) and (InRegion(X, Y, Button[button_s].GetMouseOverArea)) then
    SetInteraction(button_s)
  else
    SetInteraction(-1);

  if (MouseButton = SDL_BUTTON_LEFT) and BtnDown then
    ParseInput(SDLK_RETURN, 0, true);

end;

procedure TScreenScore.RefreshTexts;
var
  P:    integer;

begin
  if (CurrentRound < Length(PlaylistMedley.Stats)-1) then
  begin
    Text[TextArtist].Text      := IntToStr(CurrentRound+1) + '/' +
      IntToStr(Length(PlaylistMedley.Stats)-1) + ': ' +
      PlaylistMedley.Stats[CurrentRound].SongArtist;
    Text[TextTitle].Text       := PlaylistMedley.Stats[CurrentRound].SongTitle;
    Text[TextTitle].Visible    := true;
    Text[TextArtistTitle].Text := IntToStr(CurrentRound+1) + '/' +
      IntToStr(Length(PlaylistMedley.Stats)-1) + ': ' +
      PlaylistMedley.Stats[CurrentRound].SongArtist +
      ' - ' + PlaylistMedley.Stats[CurrentRound].SongTitle;
  end else
  begin
    if ScreenSong.MedleyActive then
    begin
      Text[TextArtist].Text      := Language.Translate('SING_TOTAL');
      Text[TextTitle].Visible    := false;
      Text[TextArtistTitle].Text := Language.Translate('SING_TOTAL');
    end else
    begin
      Text[TextArtist].Text      := PlaylistMedley.Stats[CurrentRound].SongArtist;
      Text[TextTitle].Text       := PlaylistMedley.Stats[CurrentRound].SongTitle;
      Text[TextTitle].Visible    := true;
      Text[TextArtistTitle].Text := PlaylistMedley.Stats[CurrentRound].SongArtist + ' - ' +
        PlaylistMedley.Stats[CurrentRound].SongTitle;
    end;
  end;

  if ScreenSong.MedleyActive then
  begin

    for P := 0 to PlayersPlay - 1 do
      Player[P] := PlaylistMedley.Stats[CurrentRound].Player[P];
  end;

  ResetScores;
end;

//TODO: adapt for players 7 to 12
procedure TScreenScore.LoadSwapTextures;
  var
    P, I: integer;
    PlayerNum, PlayerNum2: integer;
    Color: string;
    R, G, B: real;
    StaticNum: integer;
    ThemeStatic: TThemeStatic;
begin
  { we only need to load swapping textures if in dualscreen mode }
  if Screens = 2 then
  begin
    { load swapping textures for custom statics }
    for P := low(PlayerStatic) to High(PlayerStatic) do
    begin
      SetLength(PlayerStaticTextures[P], Length(PlayerStatic[P]));

      { get the players that actually are on this position }
      case P of
        1: begin
          PlayerNum := 1;
          PlayerNum2 := 1;
        end;

        2, 3: begin
          PlayerNum := P - 1;
          PlayerNum2 := PlayerNum + 2;
        end;

        4..6: begin
          PlayerNum := P - 3;
          PlayerNum2 := PlayerNum + 3;
        end;
      end;

      for I := 0 to High(PlayerStatic[P]) do
      begin
        // copy current statics texture to texture for screen 1
        PlayerStaticTextures[P, I, 1].Tex := Statics[PlayerStatic[P, I]].Texture;

        // fallback to first screen texture for 2nd screen
        PlayerStaticTextures[P, I, 2].Tex := PlayerStaticTextures[P, I, 1].Tex.Clone;

        { texture for second screen }
        { we only change color for statics with playercolor
          and with Texture type colorized
          also we don't need to swap for one player position }
        if (P <> 1) and
           (Length(Theme.Score.PlayerStatic[P, I].Color) >= 2) and
           (copy(Theme.Score.PlayerStatic[P, I].Color, 1, 2) = 'P' + IntToStr(PlayerNum)) then
        begin
          // get the color
          Color := Theme.Score.PlayerStatic[P, I].Color;
          Color[2] := IntToStr(PlayerNum2)[1];
          LoadColor(R, G, B, Color);

          with Theme.Score.PlayerStatic[P, I] do
          begin
            PlayerStaticTextures[P, I, 2].Tex.Free;
            PlayerStaticTextures[P, I, 2].Tex := Renderer.GetTexture(Skin.GetTextureFileName(Tex), Typ, RGBFloatToInt(R, G, B));
          end;

          PlayerStaticTextures[P, I, 2].Tex.X := Statics[PlayerStatic[P, I]].Texture.X;
          PlayerStaticTextures[P, I, 2].Tex.Y := Statics[PlayerStatic[P, I]].Texture.Y;
          PlayerStaticTextures[P, I, 2].Tex.W := Statics[PlayerStatic[P, I]].Texture.W;
          PlayerStaticTextures[P, I, 2].Tex.H := Statics[PlayerStatic[P, I]].Texture.H;
          if (Theme.Score.PlayerStatic[P, I].Typ <> TEXTURE_TYPE_COLORIZED) then
          begin
            PlayerStaticTextures[P, I, 2].Tex.ColR := R;
            PlayerStaticTextures[P, I, 2].Tex.ColG := G;
            PlayerStaticTextures[P, I, 2].Tex.ColB := B;
          end;
        end;
      end;
    end;

    { load swap textures for boxes }
    for P := low(PlayerBoxTextures) to High(PlayerBoxTextures) do
    begin
      { get the players that actually are on this position }
      case P of
        1: begin
          PlayerNum := 1;
          PlayerNum2 := 1;
        end;

        2, 3: begin
          PlayerNum := P - 1;
          PlayerNum2 := PlayerNum + 2;
        end;

        4..6: begin
          PlayerNum := P - 3;
          PlayerNum2 := PlayerNum + 3;
        end;
      end;

      for I := 0 to High(PlayerBoxTextures[P]) do
      begin
        case I of
          0: begin
            StaticNum := StaticBoxLightest[P];
            ThemeStatic := Theme.Score.StaticBoxLightest[P];
          end;
          1: begin
            StaticNum := StaticBoxLight[P];
            ThemeStatic := Theme.Score.StaticBoxLight[P];
          end;
          2: begin
            StaticNum := StaticBoxDark[P];
            ThemeStatic := Theme.Score.StaticBoxDark[P];
          end;
        end;
        // copy current statics texture to texture for screen 1
        PlayerBoxTextures[P, I, 1].Tex := Statics[StaticNum].Texture;

        // fallback to first screen texture for 2nd screen
        PlayerBoxTextures[P, I, 2].Tex := PlayerBoxTextures[P, I, 1].Tex.Clone;

        { texture for second screen }
        { we only change color for statics with playercolor
          and with Texture type colorized
          also we don't need to swap for one player position }
        if (P <> 1) and
           (ThemeStatic.Typ = Texture_Type_Colorized) and
           (Length(ThemeStatic.Color) >= 2) and
           (copy(ThemeStatic.Color, 1, 2) = 'P' + IntToStr(PlayerNum)) then
        begin
          // get the color
          Color := ThemeStatic.Color;
          Color[2] := IntToStr(PlayerNum2)[1];
          LoadColor(R, G, B, Color);

          with ThemeStatic do
            PlayerBoxTextures[P, I, 2].Tex.Free;
            PlayerBoxTextures[P, I, 2].Tex := Renderer.GetTexture(Skin.GetTextureFileName(ThemeStatic.Tex), ThemeStatic.Typ, RGBFloatToInt(R, G, B));

            PlayerBoxTextures[P, I, 2].Tex.X := Statics[StaticNum].Texture.X;
            PlayerBoxTextures[P, I, 2].Tex.Y := Statics[StaticNum].Texture.Y;
            PlayerBoxTextures[P, I, 2].Tex.W := Statics[StaticNum].Texture.W;
            PlayerBoxTextures[P, I, 2].Tex.H := Statics[StaticNum].Texture.H;
        end;
      end;
    end;
  end;
end;

//TODO: adapt for players 7 to 12
procedure TScreenScore.SwapToScreen(Screen: integer);
var
  P, I, Max: integer;
  Col: TRGB;
begin

  case PlayersPlay of
    1:    Max := 1;
    2, 4: Max := 2;
    3, 6: Max := 3;
    8:    Max := 4;
    12:   Max := 6;
  else
    Max := 0; //this should never happen
  end;

  { if screens = 2 and playerplay <= 3 the 2nd screen shows the
    textures of screen 1 }
  if (PlayersPlay <= 3) and (Screen = 2) then
    Screen := 1;

  { set correct box textures }
  if (Screens = 2) then
  begin

    for I:= 0 to Max - 1 do
    begin

      if (Screen = 2) then
        Col := GetPlayerColor(Ini.PlayerColor[I + Max])
      else
        Col := GetPlayerColor(Ini.PlayerColor[I]);

      if (copy(Theme.Score.TextName[I + 1 + Max].Color, 1, 2) = 'P' + IntToStr(I + 1)) then
      begin
        Text[TextName[I + 1 + Max]].ColR := Col.R;
        Text[TextName[I + 1 + Max]].ColG := Col.G;
        Text[TextName[I + 1 + Max]].ColB := Col.B;
      end;

      if (copy(Theme.Score.TextScore[I + 1 + Max].Color, 1, 2) = 'P' + IntToStr(I + 1)) then
      begin
        Text[TextScore[I + 1 + Max]].ColR := Col.R;
        Text[TextScore[I + 1 + Max]].ColG := Col.G;
        Text[TextScore[I + 1 + Max]].ColB := Col.B;
      end;

      if (copy(Theme.Score.TextNotes[I + 1 + Max].Color, 1, 2) = 'P' + IntToStr(I + 1)) then
      begin
        Text[TextNotes[I + 1 + Max]].ColR := Col.R;
        Text[TextNotes[I + 1 + Max]].ColG := Col.G;
        Text[TextNotes[I + 1 + Max]].ColB := Col.B;
      end;

      if (copy(Theme.Score.TextNotesScore[I + 1 + Max].Color, 1, 2) = 'P' + IntToStr(I + 1)) then
      begin
        Text[TextNotesScore[I + 1 + Max]].ColR := Col.R;
        Text[TextNotesScore[I + 1 + Max]].ColG := Col.G;
        Text[TextNotesScore[I + 1 + Max]].ColB := Col.B;
      end;

      if (copy(Theme.Score.TextLineBonus[I + 1 + Max].Color, 1, 2) = 'P' + IntToStr(I + 1)) then
      begin
        Text[TextLineBonus[I + 1 + Max]].ColR := Col.R;
        Text[TextLineBonus[I + 1 + Max]].ColG := Col.G;
        Text[TextLineBonus[I + 1 + Max]].ColB := Col.B;
      end;

      if (copy(Theme.Score.TextLineBonusScore[I + 1 + Max].Color, 1, 2) = 'P' + IntToStr(I + 1)) then
      begin
        Text[TextLineBonusScore[I + 1 + Max]].ColR := Col.R;
        Text[TextLineBonusScore[I + 1 + Max]].ColG := Col.G;
        Text[TextLineBonusScore[I + 1 + Max]].ColB := Col.B;
      end;

      if (copy(Theme.Score.TextGoldenNotes[I + 1 + Max].Color, 1, 2) = 'P' + IntToStr(I + 1)) then
      begin
        Text[TextGoldenNotes[I + 1 + Max]].ColR := Col.R;
        Text[TextGoldenNotes[I + 1 + Max]].ColG := Col.G;
        Text[TextGoldenNotes[I + 1 + Max]].ColB := Col.B;
      end;

      if (copy(Theme.Score.TextGoldenNotesScore[I + 1 + Max].Color, 1, 2) = 'P' + IntToStr(I + 1)) then
      begin
        Text[TextGoldenNotesScore[I + 1 + Max]].ColR := Col.R;
        Text[TextGoldenNotesScore[I + 1 + Max]].ColG := Col.G;
        Text[TextGoldenNotesScore[I + 1 + Max]].ColB := Col.B;
      end;

      if (copy(Theme.Score.TextTotal[I + 1 + Max].Color, 1, 2) = 'P' + IntToStr(I + 1)) then
      begin
        Text[TextTotal[I + 1 + Max]].ColR := Col.R;
        Text[TextTotal[I + 1 + Max]].ColG := Col.G;
        Text[TextTotal[I + 1 + Max]].ColB := Col.B;
      end;

      if (copy(Theme.Score.TextTotalScore[I + 1 + Max].Color, 1, 2) = 'P' + IntToStr(I + 1)) then
      begin
        Text[TextTotalScore[I + 1 + Max]].ColR := Col.R;
        Text[TextTotalScore[I + 1 + Max]].ColG := Col.G;
        Text[TextTotalScore[I + 1 + Max]].ColB := Col.B;
      end;
      if((PlayersPlay > Max) and (Screen = 2)) then
      begin
        Statics[AvatarStaticRef[PlayersPlay-Max+I+1]].Visible:=true;
      end
      else if((PlayersPlay > Max) and (Screen = 1)) then
      begin
        Statics[AvatarStaticRef[PlayersPlay-Max+I+1]].Visible:=false;
      end;
    end;

    { to keep it simple we just swap all statics, not just the shown ones }
    for P := Low(PlayerStatic) to High(PlayerStatic) do
      for I := 0 to High(PlayerStatic[P]) do
      begin
        Statics[PlayerStatic[P, I]].Texture := PlayerStaticTextures[P, I, Screen].Tex;
      end;

    { box statics }
    for P := Low(PlayerStatic) to High(PlayerStatic) do
    begin
      Statics[StaticBoxLightest[P]].Texture := PlayerBoxTextures[P, 0, Screen].Tex;
      Statics[StaticBoxLight[P]].Texture := PlayerBoxTextures[P, 1, Screen].Tex;
      Statics[StaticBoxDark[P]].Texture := PlayerBoxTextures[P, 2, Screen].Tex;
    end;
  end;
end;

constructor TScreenScore.Create;
var
  Player:  integer;
  Counter: integer;
  I: integer;
  R, G, B: real;
  Col2: integer;
  ArrayStartModifier: integer;
begin
  inherited Create;

  LoadFromTheme(Theme.Score);

  // These two texts arn't used in the deluxe skin
  TextArtist      := AddText(Theme.Score.TextArtist);
  TextTitle       := AddText(Theme.Score.TextTitle);

  TextArtistTitle := AddText(Theme.Score.TextArtistTitle);

  for Player := 1 to UIni.IMaxPlayerCount do
  begin
    SetLength(PlayerStatic[Player], Length(Theme.Score.PlayerStatic[Player]));
    SetLength(PlayerTexts[Player],  Length(Theme.Score.PlayerTexts[Player]));

    for Counter := 0 to High(Theme.Score.PlayerStatic[Player]) do
      PlayerStatic[Player, Counter]      := AddStatic(Theme.Score.PlayerStatic[Player, Counter]);

    for Counter := 0 to High(Theme.Score.PlayerTexts[Player]) do
      PlayerTexts[Player, Counter]       := AddText(Theme.Score.PlayerTexts[Player, Counter]);

    TextName[Player]             := AddText(Theme.Score.TextName[Player]);
    TextScore[Player]            := AddText(Theme.Score.TextScore[Player]);

    TextNotes[Player]            := AddText(Theme.Score.TextNotes[Player]);
    TextNotesScore[Player]       := AddText(Theme.Score.TextNotesScore[Player]);
    TextLineBonus[Player]        := AddText(Theme.Score.TextLineBonus[Player]);
    TextLineBonusScore[Player]   := AddText(Theme.Score.TextLineBonusScore[Player]);
    TextGoldenNotes[Player]      := AddText(Theme.Score.TextGoldenNotes[Player]);
    TextGoldenNotesScore[Player] := AddText(Theme.Score.TextGoldenNotesScore[Player]);
    TextTotal[Player]            := AddText(Theme.Score.TextTotal[Player]);
    TextTotalScore[Player]       := AddText(Theme.Score.TextTotalScore[Player]);

    StaticBoxLightest[Player]    := AddStatic(Theme.Score.StaticBoxLightest[Player]);
    StaticBoxLight[Player]       := AddStatic(Theme.Score.StaticBoxLight[Player]);
    StaticBoxDark[Player]        := AddStatic(Theme.Score.StaticBoxDark[Player]);

    StaticBackLevel[Player]      := AddStatic(Theme.Score.StaticBackLevel[Player]);
    StaticBackLevelRound[Player] := AddStatic(Theme.Score.StaticBackLevelRound[Player]);
    StaticLevel[Player]          := AddStatic(Theme.Score.StaticLevel[Player]);
    StaticLevelRound[Player]     := AddStatic(Theme.Score.StaticLevelRound[Player]);

    // ######################
    // Score screen textures
    // ######################

    //## the bars that visualize the score ##

    //NoteBar ScoreBar
    LoadColor(R, G, B, 'P' + IntToStr(Player) + 'Dark');
    Col2 := $10000 * Round(R*255) + $100 * Round(G*255) + Round(B*255);
    Tex_Score_NoteBarLevel_Dark[Player] := Renderer.LoadTexture(Skin.GetTextureFileName('ScoreLevel_Dark'), TEXTURE_TYPE_COLORIZED, Col2);
    Tex_Score_NoteBarRound_Dark[Player] := Renderer.LoadTexture(Skin.GetTextureFileName('ScoreLevel_Dark_Round'), TEXTURE_TYPE_COLORIZED, Col2);

    //LineBonus ScoreBar
    LoadColor(R, G, B, 'P' + IntToStr(Player) + 'Light');
    Col2 := $10000 * Round(R*255) + $100 * Round(G*255) + Round(B*255);
    Tex_Score_NoteBarLevel_Light[Player] := Renderer.LoadTexture(Skin.GetTextureFileName('ScoreLevel_Light'), TEXTURE_TYPE_COLORIZED, Col2);
    Tex_Score_NoteBarRound_Light[Player] := Renderer.LoadTexture(Skin.GetTextureFileName('ScoreLevel_Light_Round'), TEXTURE_TYPE_COLORIZED, Col2);

    //GoldenNotes ScoreBar
    LoadColor(R, G, B, 'P' + IntToStr(Player) + 'Lightest');
    Col2 := $10000 * Round(R*255) + $100 * Round(G*255) + Round(B*255);
    Tex_Score_NoteBarLevel_Lightest[Player] := Renderer.LoadTexture(Skin.GetTextureFileName('ScoreLevel_Lightest'), TEXTURE_TYPE_COLORIZED, Col2);
    Tex_Score_NoteBarRound_Lightest[Player] := Renderer.LoadTexture(Skin.GetTextureFileName('ScoreLevel_Lightest_Round'), TEXTURE_TYPE_COLORIZED, Col2);

    //textures
    aPlayerScoreScreenTextures[Player].Score_NoteBarLevel_Dark     := Tex_Score_NoteBarLevel_Dark[Player];
    aPlayerScoreScreenTextures[Player].Score_NoteBarRound_Dark     := Tex_Score_NoteBarRound_Dark[Player];

    aPlayerScoreScreenTextures[Player].Score_NoteBarLevel_Light    := Tex_Score_NoteBarLevel_Light[Player];
    aPlayerScoreScreenTextures[Player].Score_NoteBarRound_Light    := Tex_Score_NoteBarRound_Light[Player];

    aPlayerScoreScreenTextures[Player].Score_NoteBarLevel_Lightest := Tex_Score_NoteBarLevel_Lightest[Player];
    aPlayerScoreScreenTextures[Player].Score_NoteBarRound_Lightest := Tex_Score_NoteBarRound_Lightest[Player];
  end;

  //TODO: adapt for players 7 to 12
  // avatars
  case PlayersPlay of
    1: ArrayStartModifier := 0;
    2: ArrayStartModifier := 1;
    3: ArrayStartModifier := 3;
    4: begin
          if (Screens = 1) then
            ArrayStartModifier := 0
          else
            ArrayStartModifier := 1;
       end;
    6: begin
          if (Screens = 1) then
            ArrayStartModifier := 0
          else
            ArrayStartModifier := 3;
       end;
    else
      ArrayStartModifier := 0; //this should never happen
  end;

  for I := 1 to PlayersPlay do
  begin
    if((Screens = 2) and (PlayersPlay > 3) and (I > Trunc(PlayersPlay/2))) then
    begin
      AvatarStatic[I + ArrayStartModifier] := AddStatic(Theme.Score.AvatarStatic[I-Trunc(PlayersPlay/2) + ArrayStartModifier]);
      Statics[AvatarStatic[I + ArrayStartModifier]].Texture.Free;
      Statics[AvatarStatic[I + ArrayStartModifier]].Texture := AvatarPlayerTextures[I].Clone();
      Statics[AvatarStatic[I + ArrayStartModifier]].Texture.X := Theme.Score.AvatarStatic[I-Trunc(PlayersPlay/2) + ArrayStartModifier].X;
      Statics[AvatarStatic[I + ArrayStartModifier]].Texture.Y := Theme.Score.AvatarStatic[I-Trunc(PlayersPlay/2) + ArrayStartModifier].Y;
      Statics[AvatarStatic[I + ArrayStartModifier]].Texture.H := Theme.Score.AvatarStatic[I-Trunc(PlayersPlay/2) + ArrayStartModifier].H;
      Statics[AvatarStatic[I + ArrayStartModifier]].Texture.W := Theme.Score.AvatarStatic[I-Trunc(PlayersPlay/2) + ArrayStartModifier].W;
      Statics[AvatarStatic[I + ArrayStartModifier]].Texture.Z := Theme.Score.AvatarStatic[I-Trunc(PlayersPlay/2) + ArrayStartModifier].Z;
      Statics[AvatarStatic[I + ArrayStartModifier]].Texture.Alpha := Theme.Score.AvatarStatic[I-Trunc(PlayersPlay/2) + ArrayStartModifier].Alpha;
    end
    else
    begin
      AvatarStatic[I + ArrayStartModifier] := AddStatic(Theme.Score.AvatarStatic[I + ArrayStartModifier]);
      Statics[AvatarStatic[I + ArrayStartModifier]].Texture.Free;
      Statics[AvatarStatic[I + ArrayStartModifier]].Texture := AvatarPlayerTextures[I].Clone();
      Statics[AvatarStatic[I + ArrayStartModifier]].Texture.X := Theme.Score.AvatarStatic[I + ArrayStartModifier].X;
      Statics[AvatarStatic[I + ArrayStartModifier]].Texture.Y := Theme.Score.AvatarStatic[I + ArrayStartModifier].Y;
      Statics[AvatarStatic[I + ArrayStartModifier]].Texture.H := Theme.Score.AvatarStatic[I + ArrayStartModifier].H;
      Statics[AvatarStatic[I + ArrayStartModifier]].Texture.W := Theme.Score.AvatarStatic[I + ArrayStartModifier].W;
      Statics[AvatarStatic[I + ArrayStartModifier]].Texture.Z := Theme.Score.AvatarStatic[I + ArrayStartModifier].Z;
      Statics[AvatarStatic[I + ArrayStartModifier]].Texture.Alpha := Theme.Score.AvatarStatic[I + ArrayStartModifier].Alpha;
    end;
    Statics[AvatarStatic[I + ArrayStartModifier]].Visible := true;
    AvatarStaticRef[I]:=AvatarStatic[I + ArrayStartModifier];
  end;

  StaticNavigate := AddStatic(Theme.Score.StaticNavigate);
  TextNavigate := AddText(Theme.Score.TextNavigate);

  if (PlayersPlay <= 3) or (Screens = 2) then
    LoadSwapTextures;

  //TODO: adapt for players 4 to 12
  //Send Buttons
  for I := 1 to 3 do
    ButtonSend[I] := AddButton(Theme.Score.ButtonSend[I]);

end;

destructor TScreenScore.Destroy;
var
  P, I, S: integer;
begin
  for I := 1 to UIni.IMaxPlayerCount do
  begin
    Tex_Score_NoteBarLevel_Dark[I].Free;
    Tex_Score_NoteBarRound_Dark[I].Free;
    Tex_Score_NoteBarLevel_Light[I].Free;
    Tex_Score_NoteBarRound_Light[I].Free;
    Tex_Score_NoteBarLevel_Lightest[I].Free;
    Tex_Score_NoteBarRound_Lightest[I].Free;
  end;

  // Use the texture address stored in PlayerStaticTextures and PlayerBoxTexture to free the memory, then
  // set the texture adddress in the TStatic object to nil so we avoid a double free in the destructor of TStatic
  for P := Low(PlayerStaticTextures) to High(PlayerStaticTextures) do
  begin
    for I := Low(PlayerStaticTextures[P]) to High(PlayerStaticTextures[P]) do
    begin
      for S := Low(PlayerStaticTextures[P][I]) to High(PlayerStaticTextures[P][I]) do
        PlayerStaticTextures[P, I, S].Tex.Free;
      Statics[PlayerStatic[P, I]].Texture := nil;
    end;
  end;
  for P := Low(PlayerBoxTextures) to High(PlayerBoxTextures) do
  begin
    for I := Low(PlayerBoxTextures[P]) to High(PlayerBoxTextures[P]) do
    begin
      for S := Low(PlayerBoxTextures[P][I]) to High(PlayerBoxTextures[P][I]) do
        PlayerBoxTextures[P, I, S].Tex.Free;
      Statics[StaticBoxLightest[P]].Texture := nil;
      Statics[StaticBoxLight[P]].Texture := nil;
      Statics[StaticBoxDark[P]].Texture := nil;
    end;
  end;
  inherited;
end;

//TODO: adapt for players 7 to 12
procedure TScreenScore.MapPlayersToPosition;
  var
    ArrayStartModifier: integer;
    PlayersPerScreen: integer;
    I: integer;
begin
  // all statics / texts are loaded at start - so that we have them all even if we change the amount of players
  // To show the corrects statics / text from the them, we simply modify the start of the according arrays
  // 1 Player -> Player[0].Score         (The score for one player starts at 0)
  //          -> Statics[1]              (The statics for the one player screen start at 1)
  // 2 Player -> Player[0..1].Score
  //          -> Statics[2..3]
  // 3 Player -> Player[0..5].Score
  //          -> Statics[4..6]
  case PlayersPlay of
    1:    ArrayStartModifier := 1;
    2, 4: ArrayStartModifier := 2;
    3, 6: ArrayStartModifier := 4;
  else
    ArrayStartModifier := 0; //this should never happen
  end;

  if (PlayersPlay <= 3) or ((PlayersPlay > 3) and (Screens = 1)) then
    PlayersPerScreen := PlayersPlay
  else
    PlayersPerScreen := PlayersPlay div 2;

  SetLength(PlayerPositionMap, PlayersPlay);

  // actually map players to positions
  if (PlayersPlay <= 3) or (Screens = 2) then
  begin
    for I := 0 to PlayersPlay - 1 do
    begin
      PlayerPositionMap[I].Screen := (I div PlayersPerScreen) + 1;
      if (PlayerPositionMap[I].Screen > Screens) then
        PlayerPositionMap[I].Position := 0
      else
        PlayerPositionMap[I].Position := ArrayStartModifier + (I mod PlayersPerScreen);
      PlayerPositionMap[I].BothScreens := (PlayersPlay <= 3) and (Screens > 1);
    end;
  end
  else
  begin
    for I := 0 to PlayersPlay - 1 do
    begin
      PlayerPositionMap[I].Screen := 0;
      PlayerPositionMap[I].Position := I + 1;
      PlayerPositionMap[I].BothScreens := true;
    end;
  end;

end;

{ SingStar style sounds on the score screen:
  drum roll while the bars rise, a short accent when each part of the bar
  (notes, line bonus, golden notes) is complete, applause when the whole bar
  is complete, then the background music fades in. Missing sound files are
  simply not played. }
procedure TScreenScore.UpdateScoreSounds;
var
  NewStage: integer;
  Now_: cardinal;
begin
  if not ShowFinish then
    Exit;

  Now_ := SDL_GetTicks();

  if (ScoreSoundStage < 4) then
  begin
    // the animation has started: drum roll
    if (ScoreSoundStage = 0) then
    begin
      ScoreSoundStage := 1;
      DrumRollStartTime := Now_;
      AudioPlayback.PlaySound(SoundLib.ScoreDrumRoll);
    end;

    // which part of the bar is rising now?
    if (BarScore_EaseOut_Step < EaseOut_MaxSteps * 10) then
      NewStage := 1
    else if (BarPhrase_EaseOut_Step < EaseOut_MaxSteps * 10) then
      NewStage := 2
    else if (BarGolden_EaseOut_Step < EaseOut_MaxSteps * 10) then
      NewStage := 3
    else
      NewStage := 4;

    if (NewStage > ScoreSoundStage) then
    begin
      // accents only if the parts were completed one after the other (not
      // when the animation was skipped with a key press)
      if (NewStage = ScoreSoundStage + 1) then
        case NewStage of
          2: AudioPlayback.PlaySound(SoundLib.ScoreNotes);
          3: AudioPlayback.PlaySound(SoundLib.ScoreLineBonus);
          4: AudioPlayback.PlaySound(SoundLib.ScoreGolden);
        end;

      ScoreSoundStage := NewStage;
      if (ScoreSoundStage = 4) then
      begin
        BarCompleteTime := Now_;
        // skipped: stop the drum roll, otherwise let its final hit ring out
        if (Now_ - DrumRollStartTime < ScoreDrumRollMinTime) then
          AudioPlayback.StopSound(SoundLib.ScoreDrumRoll);
      end;
    end;
  end
  else
  begin
    if not ApplausePlayed and (Now_ - BarCompleteTime >= ScoreApplauseDelay) then
    begin
      ApplausePlayed := true;
      AudioPlayback.PlaySound(SoundLib.Applause);
    end;

    if not BgMusicStarted and (Now_ - BarCompleteTime >= ScoreBgMusicDelay) then
    begin
      BgMusicStarted := true;
      SoundLib.StartBgMusicFaded(ScoreBgMusicFade);
    end;
  end;
end;

{ leaving the score screen early: stop the drum roll and start the background
  music, so the following screens are not silent }
procedure TScreenScore.FinishScoreSounds;
begin
  AudioPlayback.StopSound(SoundLib.ScoreDrumRoll);
  if not BgMusicStarted then
  begin
    BgMusicStarted := true;
    SoundLib.StartBgMusicFaded(1.0);
  end;
end;

procedure TScreenScore.OnHide;
begin
  inherited;
  FinishScoreSounds;
end;

procedure TScreenScore.UpdateAnimation;
var
  CurrentTime: integer;
  I: integer;
begin
  CurrentTime := SDL_GetTicks();

  if (ScreenAct = 1) and ShowFinish then
    while (CurrentTime >= BarTime) do
    begin
      Inc(BarTime, BarRaiseSpeed);

      // We actually arise them in the right order, but we have to draw them in reverse order (golden -> phrase -> mainscore)
      if (BarScore_EaseOut_Step < EaseOut_MaxSteps * 10) then
        BarScore_EaseOut_Step:= BarScore_EaseOut_Step + 1

      // PhrasenBonus
      else if (BarPhrase_EaseOut_Step < EaseOut_MaxSteps * 10) then
        BarPhrase_EaseOut_Step := BarPhrase_EaseOut_Step + 1

      // GoldenNotebonus
      else if (BarGolden_EaseOut_Step < EaseOut_MaxSteps * 10) then
        BarGolden_EaseOut_Step := BarGolden_EaseOut_Step + 1

      // rating icon
      else
        for I := 1 to PlayersPlay do
          CalculateBouncing(I);
    end;
end;

procedure TScreenScore.DrawPlayerBars;
  var
    I: integer;
begin
  for I := 0 to PlayersPlay - 1 do
  begin
    if (PlayerPositionMap[I].Position > 0) and ((ScreenAct = PlayerPositionMap[I].Screen) or (PlayerPositionMap[I].BothScreens)) then
    begin
      if (BarScore_EaseOut_Step >= (EaseOut_MaxSteps * 10)) then
      begin
        if (BarPhrase_EaseOut_Step >= (EaseOut_MaxSteps * 10)) then
        begin
          // Draw golden score bar #
          EaseBarIn(I + 1, sbtGolden);
          EaseScoreIn(I + 1, sbtGolden);
        end;

        // Draw phrase score bar #
        EaseBarIn(I + 1, sbtLine);
        EaseScoreIn(I + 1, sbtLine);
      end;

      // Draw plain score bar #
      EaseBarIn(I + 1, sbtScore);
      EaseScoreIn(I + 1, sbtScore);
    end;
  end;
end;

procedure TScreenScore.OnShow;
var
  P: integer;  // player
  I: integer;
  V: array[1..UIni.IMaxPlayerCount] of boolean; // visibility array
begin
  if not Help.SetHelpID(ID) then
    Log.LogWarn('No Entry for Help-ID ' + ID, 'ScreenScore');

  FinishScreenDraw := false;
  PreviewEnd := 0;

  ScoreSoundStage := 0;
  ApplausePlayed := false;
  BgMusicStarted := false;
  MedleyBrowsed := false;

  {**
   * Turn backgroundmusic on
   *}
  //SoundLib.StartBgMusic; -- now play current song

  inherited;

  // intially show total score
  CurrentRound := Length(PlaylistMedley.Stats)-1;
  if ScreenSong.MedleyActive then
  begin
    // SingStar style: no song preview on the score screen
    for P := 0 to PlayersPlay - 1 do
      Player[P] := PlaylistMedley.Stats[CurrentRound].Player[P];

    Statics[StaticNavigate].Visible := true;
    Text[TextNavigate].Visible := true;
  end else
  begin
    Statics[StaticNavigate].Visible := false;
    Text[TextNavigate].Visible := false;
  end;

  MapPlayersToPosition;

  Text[TextArtist].Text      := CurrentSong.Artist;
  Text[TextTitle].Text       := CurrentSong.Title;
  Text[TextArtistTitle].Text := CurrentSong.Artist + ' - ' + CurrentSong.Title;

  //TODO: adapt for players 7 to 12
  // set visibility
  case PlayersPlay of
    1:  begin
          V[1] := true;
          V[2] := false;
          V[3] := false;
          V[4] := false;
          V[5] := false;
          V[6] := false;
        end;
    2, 4:  begin
          if (PlayersPlay = 2) or ((PlayersPlay = 4) and (Screens = 2)) then
          begin
            V[1] := false;
            V[2] := true;
            V[3] := true;
            V[4] := false;
            V[5] := false;
            V[6] := false;
          end
          else
          begin
            V[1] := true;
            V[2] := true;
            V[3] := true;
            V[4] := true;
            V[5] := false;
            V[6] := false;
          end;
        end;
    3, 6:  begin
          if (PlayersPlay = 3) or ((PlayersPlay = 6) and (Screens = 2)) then
          begin
            V[1] := false;
            V[2] := false;
            V[3] := false;
            V[4] := true;
            V[5] := true;
            V[6] := true;
          end
          else
          begin
            V[1] := true;
            V[2] := true;
            V[3] := true;
            V[4] := true;
            V[5] := true;
            V[6] := true;
          end;
        end;
  end;

  for P := 1 to UIni.IMaxPlayerCount do
  begin
    Text[TextName[P]].Visible               := V[P];
    Text[TextScore[P]].Visible              := V[P];

    Text[TextNotes[P]].Visible              := V[P];
    Text[TextNotesScore[P]].Visible         := V[P];
    Text[TextLineBonus[P]].Visible          := V[P];
    Text[TextLineBonusScore[P]].Visible     := V[P];
    Text[TextGoldenNotes[P]].Visible        := V[P];
    Text[TextGoldenNotesScore[P]].Visible   := V[P];
    Text[TextTotal[P]].Visible              := V[P];
    Text[TextTotalScore[P]].Visible         := V[P];

    for I := 0 to high(PlayerStatic[P]) do
      Statics[PlayerStatic[P, I]].Visible    := V[P];

    for I := 0 to high(PlayerTexts[P]) do
      Text[PlayerTexts[P, I]].Visible       := V[P];

    Statics[StaticBoxLightest[P]].Visible    := V[P];
    Statics[StaticBoxLight[P]].Visible       := V[P];
    Statics[StaticBoxDark[P]].Visible        := V[P];

    // we draw that on our own
    Statics[StaticBackLevel[P]].Visible      := false;
    Statics[StaticBackLevelRound[P]].Visible := false;
    Statics[StaticLevel[P]].Visible          := false;
    Statics[StaticLevelRound[P]].Visible     := false;
  end;

  for I := 0 to 2 do
  begin
    Button[I].Visible := false;
    Button[I].Selectable := false;
  end;

  // Show Send Score Buttons
  if ScreenSing.SungToEnd and not CurrentSong.isDuet and (Length(DllMan.Websites) > 0) then
  begin
    case PlayersPlay of
      1: begin
           Button[0].Visible := true;
           Button[0].Selectable := true;
         end;
      2,4: begin
             Button[1].Visible := true;
             Button[1].Selectable := true;
           end;
      3,6: begin
             Button[2].Visible := true;
             Button[2].Selectable := true;
           end;
    end;
  end;

  Interaction := -1;

  // party mode: players have no avatars, the avatar picture would only be an
  // empty placeholder (the team is shown by its color)
  if IsPartyRound then
    for I := 1 to PlayersPlay do
      if (I <= High(AvatarStaticRef)) and (AvatarStaticRef[I] >= 0) and
         (AvatarStaticRef[I] <= High(Statics)) then
      begin
        Statics[AvatarStaticRef[I]].Visible := false;
        HideAvatarFrames(AvatarStaticRef[I]);
      end;

  RefreshTexts;

  // SingStar style: the sung song is not played again on the score screen;
  // instead a drum roll is played while the bars rise (UpdateScoreSounds)
  if (Ini.SavePlayback = 1) then
  begin
    Voice := -1;
    StartVoice;
  end;

end;

procedure TScreenScore.ResetScores;
var
  P:    integer;

begin
  for P := 1 to PlayersPlay do
  begin
    // data
    aPlayerScoreScreenDatas[P].Bar_Y            := Theme.Score.StaticBackLevel[PlayerPositionMap[P-1].Position].Y;

    // ratings
    aPlayerScoreScreenRatings[P].RateEaseStep   := 1;
    aPlayerScoreScreenRatings[P].RateEaseValue  := 20;

    // actual values
    TextScore_ActualValue[P]  := 0;
    TextPhrase_ActualValue[P] := 0;
    TextGolden_ActualValue[P] := 0;
  end;

  for P := 1 to UIni.IMaxPlayerCount do
  begin
    // We set alpha to 0 , so we can nicely blend them in when we need them
    Text[TextScore[P]].Alpha                   := 0;
    Text[TextNotesScore[P]].Alpha              := 0;
    Text[TextNotes[P]].Alpha                   := 0;
    Text[TextLineBonus[P]].Alpha               := 0;
    Text[TextLineBonusScore[P]].Alpha          := 0;
    Text[TextGoldenNotes[P]].Alpha             := 0;
    Text[TextGoldenNotesScore[P]].Alpha        := 0;
    Text[TextTotal[P]].Alpha                   := 0;
    Text[TextTotalScore[P]].Alpha              := 0;
    Statics[StaticBoxLightest[P]].Texture.Alpha := 0;
    Statics[StaticBoxLight[P]].Texture.Alpha    := 0;
    Statics[StaticBoxDark[P]].Texture.Alpha     := 0;
  end;

  BarScore_EaseOut_Step  := 1;
  BarPhrase_EaseOut_Step := 1;
  BarGolden_EaseOut_Step := 1;

  BarTime := SDL_GetTicks();
end;

procedure TScreenScore.onShowFinish;
var
  index: integer;
begin
  for index := 1 to (PlayersPlay) do
  begin
    TextScore_ActualValue[index]  := 0;
    TextPhrase_ActualValue[index] := 0;
    TextGolden_ActualValue[index] := 0;
  end;

  BarTime := SDL_GetTicks();
end;

function TScreenScore.Draw: boolean;
var
  PlayerCounter: integer;
begin
  if (PreviewEnd > 0) and (AudioPlayback.Position >= PreviewEnd) then
  begin
    AudioPlayback.Stop;
    PreviewEnd := 0;
  end;

{
  player[0].ScoreInt       := 7000;
  player[0].ScoreLineInt   := 2000;
  player[0].ScoreGoldenInt := 1000;
  player[0].ScoreTotalInt  := 10000;

  player[1].ScoreInt       := 8500;
  player[1].ScoreLineInt   := 1000;
  player[1].ScoreGoldenInt :=  500;
  player[1].ScoreTotalInt  := 10000;

  player[2].ScoreInt       := 8000;
  player[2].ScoreLineInt   := 1000;
  player[2].ScoreGoldenInt := 1000;
  player[2].ScoreTotalInt  := 10000;

  player[3].ScoreInt       := 7000;
  player[3].ScoreLineInt   := 2000;
  player[3].ScoreGoldenInt := 1000;
  player[3].ScoreTotalInt  := 10000;

  player[4].ScoreInt       := 8500;
  player[4].ScoreLineInt   := 1000;
  player[4].ScoreGoldenInt :=  500;
  player[4].ScoreTotalInt  := 10000;

  player[5].ScoreInt       := 8000;
  player[5].ScoreLineInt   := 1000;
  player[5].ScoreGoldenInt := 1000;
  player[5].ScoreTotalInt  := 10000;

  }

  // medley: when browsing the single songs, the bars are shown at once
  if ScreenSong.MedleyActive and MedleyBrowsed then
    BarTime := 0;

  // swap static textures to current screen ones
  SwapToScreen(ScreenAct);

  //Draw the Background
  DrawBG;

  // Let's start to arise the bars
  UpdateAnimation;

  // drum roll, accents, applause and background music
  UpdateScoreSounds;

  if (ShowFinish) then
    DrawPlayerBars;



(*
    //todo: i need a clever method to draw statics with their z value
    for I := 0 to High(Statics) do
      Statics[I].Draw;
    for I := 0 to High(Text) do
      Text[I].Draw;
*)

  // we have to swap the themeobjects values on every draw
  // to support dual screen
  for PlayerCounter := 1 to PlayersPlay do       //TODO: adapt for players 7 to 12
  begin
    FillPlayerItems(PlayerCounter);
  end;
   //Draw Theme Objects
  DrawFG;
  Result := true;
end;

{ true if the score screen is shown after a round of the classic or free
  party mode (Feature 1b) }
function TScreenScore.IsPartyRound: boolean;
begin
  Result := Party.bPartyGame and (ScreenSong.Mode in [smPartyClassic, smPartyFree]);
end;

{ party mode: hides the frames around a (hidden) avatar picture. The frames
  are separate theme statics; they are found by position: a frame encloses
  the avatar box and is not much larger than it. }
procedure TScreenScore.HideAvatarFrames(AvatarStatic: integer);
var
  P, J, I: integer;
  AX, AY, AW, AH: single;
begin
  if (Statics[AvatarStatic].Texture = nil) then
    Exit;
  AX := Statics[AvatarStatic].Texture.X;
  AY := Statics[AvatarStatic].Texture.Y;
  AW := Statics[AvatarStatic].Texture.W;
  AH := Statics[AvatarStatic].Texture.H;
  if (AW <= 0) or (AH <= 0) then
    Exit;
  // only the player statics (their visibility is set again in every OnShow)
  for P := Low(PlayerStatic) to High(PlayerStatic) do
  for J := 0 to High(PlayerStatic[P]) do
  begin
    I := PlayerStatic[P, J];
    if (I < 0) or (I > High(Statics)) then
      Continue;
    if (I <> AvatarStatic) and (Statics[I].Texture <> nil) and
       (Statics[I].Texture.X <= AX + 1) and (Statics[I].Texture.Y <= AY + 1) and
       (Statics[I].Texture.X + Statics[I].Texture.W >= AX + AW - 1) and
       (Statics[I].Texture.Y + Statics[I].Texture.H >= AY + AH - 1) and
       (Statics[I].Texture.W <= AW * 1.5) and (Statics[I].Texture.H <= AH * 1.5) then
      Statics[I].Visible := false;
  end;
end;

{ party mode: the person who sang (the team is shown by its color);
  in Pass the Mic rounds the team name. Long names are shortened. }
function TScreenScore.GetPlayerDisplayName(PlayerIndex: integer): UTF8String;
begin
  Result := Player[PlayerIndex].Name;
  if IsPartyRound and (PlayerIndex <= High(Party.Teams)) then
  begin
    Result := Party.GetScoreName(PlayerIndex);
    if (Result = '') then
      Result := UTF8String(Party.Teams[PlayerIndex].Name);
    Result := ShortenName(Result, PARTY_SCORE_NAME_MAXLEN);
  end;
end;

{ leaves the score screen.
  Normal mode: highscores (or song selection).
  Party mode: highscores only for round types whose scores were saved, then
  always the party score screen, so the party goes on (Feature 1b). }
procedure TScreenScore.LeaveScreen;
var
  P: integer;
begin
  if IsPartyRound then
  begin
    // medley: after browsing the single songs Player[] holds the result of
    // one song; the party ranking needs the result of the whole medley
    if ScreenSong.MedleyActive and (Length(PlaylistMedley.Stats) > 0) then
      for P := 0 to PlayersPlay - 1 do
        if (P <= High(PlaylistMedley.Stats[High(PlaylistMedley.Stats)].Player)) then
          Player[P] := PlaylistMedley.Stats[High(PlaylistMedley.Stats)].Player[P];

    // same conditions as for saving (TScreenSingController.Finish/SaveLocalScores);
    // in party mode also songs that were stopped early are saved
    if Party.RoundSavesHighscores and
       not (CurrentSong.isDuet and (Ini.DuetScores = 0)) then
      FadeTo(@ScreenHighScores)
    else
      FadeTo(@ScreenPartyScore);
  end
  else if (CurrentSong.isDuet and (Ini.DuetScores = 0)) or (ScreenSong.RapToFreestyle) or (ScreenSong.Mode = smMedley) then
    FadeTo(@ScreenSong)
  else
    FadeTo(@ScreenHighScores);
end;

procedure TscreenScore.FillPlayerItems(PlayerNumber: integer);
var
  ThemeIndex: integer;
begin
  ThemeIndex := PlayerPositionMap[PlayerNumber-1].Position;
  if (ThemeIndex > 0) and ((ScreenAct = PlayerPositionMap[PlayerNumber-1].Screen) or (PlayerPositionMap[PlayerNumber-1].BothScreens)) then
  begin
    Text[TextName[ThemeIndex]].Text := GetPlayerDisplayName(PlayerNumber-1);
    // end todo

    //golden
    Text[TextGoldenNotesScore[ThemeIndex]].Text         := IntToStr(TextGolden_ActualValue[PlayerNumber]);
    Text[TextGoldenNotesScore[ThemeIndex]].Alpha        := (BarGolden_EaseOut_Step / 100);

    Statics[StaticBoxLightest[ThemeIndex]].Texture.Alpha := (BarGolden_EaseOut_Step / 100);
    Text[TextGoldenNotes[ThemeIndex]].Alpha             := (BarGolden_EaseOut_Step / 100);

    // line bonus
    Text[TextLineBonusScore[ThemeIndex]].Text           := IntToStr(TextPhrase_ActualValue[PlayerNumber]);
    Text[TextLineBonusScore[ThemeIndex]].Alpha          := (BarPhrase_EaseOut_Step / 100);

    Statics[StaticBoxLight[ThemeIndex]].Texture.Alpha    := (BarPhrase_EaseOut_Step / 100);
    Text[TextLineBonus[ThemeIndex]].Alpha               := (BarPhrase_EaseOut_Step / 100);

    // plain score
    Text[TextNotesScore[ThemeIndex]].Text               := IntToStr(TextScore_ActualValue[PlayerNumber]);
    Text[TextNotes[ThemeIndex]].Alpha                   := (BarScore_EaseOut_Step / 100);

    Statics[StaticBoxDark[ThemeIndex]].Texture.Alpha     := (BarScore_EaseOut_Step / 100);
    Text[TextNotesScore[ThemeIndex]].Alpha              := (BarScore_EaseOut_Step / 100);

    // total score
    Text[TextTotalScore[ThemeIndex]].Text               := IntToStr(TextScore_ActualValue[PlayerNumber] + TextPhrase_ActualValue[PlayerNumber] + TextGolden_ActualValue[PlayerNumber]);
    Text[TextTotalScore[ThemeIndex]].Alpha              := (BarScore_EaseOut_Step / 100);

    Text[TextTotal[ThemeIndex]].Alpha                   := (BarScore_EaseOut_Step / 100);

    if(BarGolden_EaseOut_Step = 100) then
    begin
      ShowRating(PlayerNumber);
    end;
  end;
end;

procedure TScreenScore.ShowRating(PlayerNumber: integer);
var
  Rating: integer;
  ThemeIndex: integer;
begin
  ThemeIndex := PlayerPositionMap[PlayerNumber-1].Position;
  if (ThemeIndex > 0) and ((ScreenAct = PlayerPositionMap[PlayerNumber-1].Screen) or (PlayerPositionMap[PlayerNumber-1].BothScreens)) then
  begin
    case (Player[PlayerNumber-1].ScoreTotalInt) of
     0..2009:
       begin
         Text[TextScore[ThemeIndex]].Text := Language.Translate('SING_SCORE_TONE_DEAF');
         Rating := 0;
       end;
     2010..4009:
       begin
         Text[TextScore[ThemeIndex]].Text := Language.Translate('SING_SCORE_AMATEUR');
         Rating := 1;
       end;
     4010..5009:
       begin
         Text[TextScore[ThemeIndex]].Text := Language.Translate('SING_SCORE_WANNABE');
         Rating := 2;
       end;
     5010..6009:
       begin
         Text[TextScore[ThemeIndex]].Text := Language.Translate('SING_SCORE_HOPEFUL');
         Rating := 3;
       end;
     6010..7509:
       begin
         Text[TextScore[ThemeIndex]].Text := Language.Translate('SING_SCORE_RISING_STAR');
         Rating := 4;
       end;
     7510..8509:
       begin
         Text[TextScore[ThemeIndex]].Text := Language.Translate('SING_SCORE_LEAD_SINGER');
         Rating := 5;
       end;
     8510..9009:
       begin
         Text[TextScore[ThemeIndex]].Text := Language.Translate('SING_SCORE_SUPERSTAR');
         Rating := 6;
       end;
     9010..10000:
       begin
         Text[TextScore[ThemeIndex]].Text := Language.Translate('SING_SCORE_ULTRASTAR');
         Rating := 7;
       end;
    else
      Rating := 0; // Cheata :P
    end;

    //todo: this could break if the width is not given, for instance when there's a skin with no picture for ratings
    if ( Theme.Score.StaticRatings[ThemeIndex].W > 0 ) and  ( aPlayerScoreScreenRatings[PlayerNumber].RateEaseValue > 0 ) then
    begin
      Text[TextScore[ThemeIndex]].Alpha := aPlayerScoreScreenRatings[PlayerNumber].RateEaseValue / Theme.Score.StaticRatings[ThemeIndex].W;
    end;
    // end todo

    DrawRating(PlayerNumber, Rating);
  end;
end;

procedure TscreenScore.DrawRating(PlayerNumber: integer; Rating: integer);
var
  Posx:  real;
  Posy:  real;
  Width: real;
  ThemeIndex: integer;
begin
  ThemeIndex := PlayerPositionMap[PlayerNumber-1].Position;

  if (Theme.Score.StaticRatings[ThemeIndex].W <> 0) and (Theme.Score.StaticRatings[ThemeIndex].H <> 0) then
  begin
    PosX := Theme.Score.StaticRatings[ThemeIndex].X + (Theme.Score.StaticRatings[ThemeIndex].W  * 0.5);
    PosY := Theme.Score.StaticRatings[ThemeIndex].Y + (Theme.Score.StaticRatings[ThemeIndex].H  * 0.5); ;

    Width := aPlayerScoreScreenRatings[PlayerNumber].RateEaseValue/2;

    with Tex_Score_Ratings[Rating] do
    begin
      X := PosX - Width;
      Y := PosY - Width;
      W := 2 * Width;
      H := 2 * Width;
    end;
    Renderer.DrawTexture(Tex_Score_Ratings[Rating]);
  end;
end;

function TscreenScore.CalculateBouncing(PlayerNumber: integer): real;
var
  p, s:              real;

  RaiseStep, MaxVal: real;
  EaseOut_Step:      integer;
  ThemeIndex: integer;
begin
  ThemeIndex := PlayerPositionMap[PlayerNumber-1].Position;

  EaseOut_Step  := aPlayerScoreScreenRatings[PlayerNumber].RateEaseStep;
  MaxVal        := Theme.Score.StaticRatings[ThemeIndex].W;

  RaiseStep     := EaseOut_Step;

  if (MaxVal > 0) and (RaiseStep > 0) then
    RaiseStep := RaiseStep / MaxVal;

  if (RaiseStep = 1) then
  begin
    Result := MaxVal;
    FinishScreenDraw := true;
  end
  else
  begin
    p := MaxVal * 0.4;

    s           := p/(2*PI) * arcsin (1);
    Result := MaxVal * power(2,-5 * RaiseStep) * sin( (RaiseStep * MaxVal - s) * (2 * PI) / p) + MaxVal;

    inc(aPlayerScoreScreenRatings[PlayerNumber].RateEaseStep);
    aPlayerScoreScreenRatings[PlayerNumber].RateEaseValue := Result;
  end;
end;

procedure TscreenScore.EaseBarIn(PlayerNumber: integer; BarType: TScoreBarType);
const
  RaiseSmoothness: integer = 100;
var
  MaxHeight:    real;
  NewHeight:    real;

  Height2Reach: real;
  RaiseStep:    real;
  BarStartPosY: single;

  lTmp:         real;
  Score:        integer;
  ThemeIndex: integer;
begin
  ThemeIndex := PlayerPositionMap[PlayerNumber-1].Position;
  MaxHeight    := Theme.Score.StaticBackLevel[ThemeIndex].H;

  // let's get the points according to the bar we draw
  // score array starts at 0, which means the score for player 1 is in score[0]
  // EaseOut_Step is the actual step in the raising process, like the 20iest step of EaseOut_MaxSteps
  if (BarType = sbtScore) then
  begin
    Score        := Player[PlayerNumber - 1].ScoreInt;
    RaiseStep    := BarScore_EaseOut_Step;
    BarStartPosY := Theme.Score.StaticBackLevel[ThemeIndex].Y + MaxHeight;
  end
  else if (BarType = sbtLine) then
  begin
    Score        := Player[PlayerNumber - 1].ScoreLineInt;
    RaiseStep    := BarPhrase_EaseOut_Step;
    BarStartPosY := Theme.Score.StaticBackLevel[ThemeIndex].Y - aPlayerScoreScreenDatas[PlayerNumber].BarScore_ActualHeight + MaxHeight;
  end
  else if (BarType = sbtGolden) then
  begin
    Score        := Player[PlayerNumber - 1].ScoreGoldenInt;
    RaiseStep    := BarGolden_EaseOut_Step;
    BarStartPosY := Theme.Score.StaticBackLevel[ThemeIndex].Y - aPlayerScoreScreenDatas[PlayerNumber].BarScore_ActualHeight - aPlayerScoreScreenDatas[PlayerNumber].BarLine_ActualHeight + MaxHeight;
  end;

  // the height dependend of the score
  Height2Reach := (Score / MAX_SONG_SCORE) * MaxHeight;

  if (aPlayerScoreScreenDatas[PlayerNumber].Bar_Actual_Height < Height2Reach) then
  begin
    // Check http://proto.layer51.com/d.aspx?f=400 for more info on easing functions
    // Calculate the actual step according to the maxsteps
    RaiseStep := RaiseStep / EaseOut_MaxSteps;

    // quadratic easing out - decelerating to zero velocity
    // -end_position * current_time * ( current_time - 2 ) + start_postion
    lTmp := (-Height2Reach * RaiseStep * (RaiseStep - 20) + BarStartPosY);

    if ( RaiseSmoothness > 0 ) and ( lTmp > 0 ) then
      NewHeight := lTmp / RaiseSmoothness;

  end
  else
    NewHeight := Height2Reach;

  DrawBar(BarType, PlayerNumber, BarStartPosY, NewHeight);

  if (BarType = sbtScore) then
    aPlayerScoreScreenDatas[PlayerNumber].BarScore_ActualHeight  := NewHeight
  else if (BarType = sbtLine) then
    aPlayerScoreScreenDatas[PlayerNumber].BarLine_ActualHeight   := NewHeight
  else if (BarType = sbtGolden) then
    aPlayerScoreScreenDatas[PlayerNumber].BarGolden_ActualHeight := NewHeight;
end;

procedure TscreenScore.DrawBar(BarType: TScoreBarType; PlayerNumber: integer; BarStartPosY: single; NewHeight: real);
var
  Width:        real;
  BarStartPosX: real;
  ThemeIndex: integer;
  Texture: TTexture;
begin
  ThemeIndex := PlayerPositionMap[PlayerNumber-1].Position;

  // this is solely for better readability of the drawing
  Width        := Theme.Score.StaticBackLevel[ThemeIndex].W;
  BarStartPosX := Theme.Score.StaticBackLevel[ThemeIndex].X;

  // set the texture for the bar
  if (BarType = sbtScore) then
    Texture := aPlayerScoreScreenTextures[PlayerNumber].Score_NoteBarLevel_Dark;
  if (BarType = sbtLine) then
    Texture := aPlayerScoreScreenTextures[PlayerNumber].Score_NoteBarLevel_Light;
  if (BarType = sbtGolden) then
    Texture := aPlayerScoreScreenTextures[PlayerNumber].Score_NoteBarLevel_Lightest;

  //draw it
  with Texture do
  begin
    X := BarStartPosX;
    Y := BarStartPosY - NewHeight;
    Z := ZBars;
    W := Width;
    H := NewHeight;
  end;
  Renderer.DrawTexture(Texture);

  //the round thing on top
  if (BarType = sbtScore) then
    Texture := aPlayerScoreScreenTextures[PlayerNumber].Score_NoteBarRound_Dark;
  if (BarType = sbtLine) then
    Texture := aPlayerScoreScreenTextures[PlayerNumber].Score_NoteBarRound_Light;
  if (BarType = sbtGolden) then
    Texture := aPlayerScoreScreenTextures[PlayerNumber].Score_NoteBarRound_Lightest;

  with Texture do
  begin
    X := BarStartPosX;
    Y := (BarStartPosY - Statics[StaticLevelRound[ThemeIndex]].Texture.h) - NewHeight;
    Z := ZBars;
    W := Width;
    H := Statics[StaticLevelRound[ThemeIndex]].Texture.h;
  end;
  Renderer.DrawTexture(Texture);
end;

procedure TScreenScore.EaseScoreIn(PlayerNumber: integer; ScoreType: TScoreBarType);
const
  RaiseSmoothness: integer = 100;
var
  RaiseStep:        real;
  lTmpA:            real;
  ScoreReached:     integer;
  EaseOut_Step:     real;
  ActualScoreValue: integer;
begin
  if (ScoreType = sbtScore) then
  begin
    EaseOut_Step     := BarScore_EaseOut_Step;
    ActualScoreValue := TextScore_ActualValue[PlayerNumber];
    ScoreReached     := Player[PlayerNumber-1].ScoreInt;
  end;
  if (ScoreType = sbtLine) then
  begin
    EaseOut_Step     := BarPhrase_EaseOut_Step;
    ActualScoreValue := TextPhrase_ActualValue[PlayerNumber];
    ScoreReached     := Player[PlayerNumber-1].ScoreLineInt;
  end;
  if (ScoreType = sbtGolden) then
  begin
    EaseOut_Step     := BarGolden_EaseOut_Step;
    ActualScoreValue := TextGolden_ActualValue[PlayerNumber];
    ScoreReached     := Player[PlayerNumber-1].ScoreGoldenInt;
  end;

  // EaseOut_Step is the actual step in the raising process, like the 20iest step of EaseOut_MaxSteps
  RaiseStep := EaseOut_Step;

  if (ActualScoreValue < ScoreReached) then
  begin
    // Calculate the actual step according to the maxsteps
    RaiseStep := RaiseStep / EaseOut_MaxSteps;

    // quadratic easing out - decelerating to zero velocity
    // -end_position * current_time * ( current_time - 2 ) + start_postion
    lTmpA := (-ScoreReached * RaiseStep * (RaiseStep - 20));
    if ( lTmpA           > 0 ) and
       ( RaiseSmoothness > 0 ) then
    begin
      if (ScoreType = sbtScore) then
        TextScore_ActualValue[PlayerNumber]  := floor( lTmpA / RaiseSmoothness);
      if (ScoreType = sbtLine) then
        TextPhrase_ActualValue[PlayerNumber] := floor( lTmpA / RaiseSmoothness);
      if (ScoreType = sbtGolden) then
        TextGolden_ActualValue[PlayerNumber] := floor( lTmpA / RaiseSmoothness);
    end;
  end
  else
  begin
    if (ScoreType = sbtScore) then
      TextScore_ActualValue[PlayerNumber]    := ScoreReached;
    if (ScoreType = sbtLine) then
      TextPhrase_ActualValue[PlayerNumber]   := ScoreReached;
    if (ScoreType = sbtGolden) then
      TextGolden_ActualValue[PlayerNumber]   := ScoreReached;
  end;
end;

//Procedure Change current played Preview
procedure TScreenSCore.StartPreview;
var
  select:   integer;
  changed:  boolean;
  PreviewPos: real;
  PreviewVolume: single;
begin
  //When Music Preview is activated -> then change music
  if (Ini.PreviewVolume <> 0) then
  begin
    changed := false;
    if ScreenSong.MedleyActive then
    begin
      if (CurrentRound < Length(PlaylistMedley.Stats) - 1) and (ScreenSong.SongIndex <> PlaylistMedley.Song[CurrentRound])  then
      begin
        select := PlaylistMedley.Song[CurrentRound];
        changed := true;
        ScreenSong.SongIndex := select;
      end;
      if (CurrentRound = Length(PlaylistMedley.Stats) - 1) then // Total Score --> play last song in medley
      begin
        select := PlaylistMedley.Song[CurrentRound-1];
        changed := true;
        ScreenSong.SongIndex := select;
      end
    end else
    begin
      select := ScreenSong.Interaction;
      ScreenSong.SongIndex := select;
      changed := true;
    end;

    if changed then
    begin
      AudioPlayback.Close;
      PreviewEnd := 0;

      if AudioPlayback.Open(CatSongs.Song[select].Path.Append(CatSongs.Song[select].Audio),nil) then
      begin
        CatSongs.Song[select].GetPreviewRange(AudioPlayback.Length, PreviewPos, PreviewEnd);
        AudioPlayback.Position := PreviewPos;

        // set preview volume
        PreviewVolume := EnsureRange(Ini.PreviewVolume, 0, 100) / 100;
        if (Ini.PreviewFading = 0) then
        begin
          // music fade disabled: start with full volume
          AudioPlayback.SetVolume(PreviewVolume);
          AudioPlayback.Play()
        end
        else
        begin
          // music fade enabled: start muted and fade-in
          AudioPlayback.SetVolume(0);
          AudioPlayback.FadeIn(Ini.PreviewFading, PreviewVolume);
        end;
      end;
    end;
  end;
end;

procedure TScreenScore.StartVoice;
begin
  //Music.Close;
  //ScreenSong.SongIndex := -1;
  //changed := false;

  // not implement voice yet
  {
  if ScreenSong.MedleyActive then
  begin
    if (CurrentRound<Length(PlaylistMedley.Stats)-1) and (Voice <> CurrentRound)  then
    begin
      Voice := CurrentRound;
      changed := true;
      SetLength(files, PlaylistMedley.NumPlayer);
      for I := 0 to High(files) do
        files[I] := PlaylistMedley.Stats[Voice].Player[I].VoiceFile;
    end;
  end else
  begin
    Voice := 0;
    changed := true;
    SetLength(files, PlayersPlay);
    for I := 0 to High(files) do
      files[I] := Player[I].VoiceFile;
  end;

  if changed then
  begin
    Music.VoicesClose;
    if (Music.VoicesOpen(files)>0) then
      Music.VoicesPlay;
  end;
  }

end;


end.
