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
 * $URL: https://ultrastardx.svn.sourceforge.net/svnroot/ultrastardx/trunk/src/screens/UScreenPartyOptions.pas $
 * $Id: UScreenPartyOptions.pas 2146 2010-02-22 18:27:15Z k-m_schindler $
 *}

unit UScreenPartyOptions;

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
  UNote,
  URenderer,
  sdl2,
  SysUtils,
  UThemes;

type
  TScreenPartyOptions = class(TMenu)
    private
      SelectMode:     cardinal;
      SelectLevel:     cardinal;
      SelectPlayList:  cardinal;
      SelectPlayList2: cardinal;

      ILevel:     array of UTF8String;
      IPlaylist:  array of UTF8String;
      IPlaylist2: array of UTF8String;

      Level:     integer;
      PlayList:  integer;
      PlayList2: integer;
      Mode:      integer;

      // playlist carousel (cover = image with the same name as the .upl file)
      CoverTex:   array of TTexture;
      CarouselPos: real;
      LastDrawTicks: cardinal;

      procedure FillLevel;
      procedure FillPlaylist;
      procedure FillPlaylistJukebox;
      procedure SetPlaylists;
      procedure SetPlaylist2;
      function ApplyPlaylistRestriction: boolean;

      procedure LoadPlaylistCovers;
      procedure FreePlaylistCovers;
      procedure DrawCarousel;
      procedure DrawCover(Index: integer; CX, CY, Size, Alpha: real);
    public
      constructor Create; override;
      function ParseInput(PressedKey: cardinal; CharCode: UCS4Char; PressedDown: boolean): boolean; override;
      procedure OnShow; override;
      procedure OnHide; override;
      function Draw: boolean; override;

      procedure InitClassic;
      procedure InitFree;
      procedure InitTournament;
  end;

const
  ID='ID_030';   //for help system

implementation

uses
  UGraphic,
  UHelp,
  UIni,
  ULanguage,
  ULog,
  UMain,
  UParty,
  UPath,
  UPathUtils,
  UPlaylist,
  UText,
  USong,
  USongs,
  UUnicodeUtils;

function TScreenPartyOptions.ParseInput(PressedKey: cardinal; CharCode: UCS4Char; PressedDown: boolean): boolean;
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
          FadeTo(@ScreenMain);
        end;

      SDLK_TAB:
        begin
          ScreenPopupHelp.ShowPopup();
        end;

      SDLK_RETURN:
        begin
          // restart time
          //if (ScreenSong.Mode = smPartyTournament) then
          //  ScreenSong.CurrentPartyTime := 0;

          //Don't start when Playlist is Selected and there are no Playlists
          if (Playlist = 2) and (Length(PlaylistMan.Playlists) = 0) then
            Exit;

          //Save Difficulty
          Ini.Difficulty := SelectsS[SelectLevel].SelectedOption;
          Ini.SaveLevel;

          case Mode of
            0: InitClassic;
            1: InitFree;
            2: InitTournament;
          end;

        end;
      // Up and Down could be done at the same time,
      // but I don't want to declare variables inside
      // functions like this one, called so many times
      SDLK_DOWN:    InteractNext;
      SDLK_UP:      InteractPrev;
      SDLK_RIGHT:
        begin
          AudioPlayback.PlaySound(SoundLib.Option);
          InteractInc;

          //Change Playlist2 if Playlist is Changed
          if (Interaction = SelectPlayList) then
          begin
            SetPlaylist2;
          end;

          //Change Playlists if Mode is Changed
          if (Interaction = SelectMode) then
          begin
            SetPlaylists;
          end;
        end;
      SDLK_LEFT:
        begin
          AudioPlayback.PlaySound(SoundLib.Option);
          InteractDec;

          //Change Playlist2 if Playlist is Changed
          if (Interaction = SelectPlayList) then
          begin
            SetPlaylist2;
          end;

          //Change Playlists if Mode is Changed
          if (Interaction = SelectMode) then
          begin
            SetPlaylists;
          end;
        end;
    end;
  end;
end;

constructor TScreenPartyOptions.Create;
begin
  inherited Create;

  //Fill ILevel
  FillLevel;

  //Fill IPlaylist
  FillPlaylist;

  //Fill IPlaylist2
  SetLength(IPlaylist2, 1);
  IPlaylist2[0] := '---';

  //Clear all Selects
  PlayList := 0;
  PlayList2 := 0;
  Mode := 0;

  //Load Screen From Theme
  LoadFromTheme(Theme.PartyOptions);

  Theme.PartyOptions.SelectMode.oneItemOnly := true;
  Theme.PartyOptions.SelectMode.showArrows := true;
  SelectMode     := AddSelectSlide(Theme.PartyOptions.SelectMode, Mode, Theme.IMode);

  Theme.PartyOptions.SelectLevel.oneItemOnly := true;
  Theme.PartyOptions.SelectLevel.showArrows := true;
  SelectLevel     := AddSelectSlide(Theme.PartyOptions.SelectLevel, Ini.Difficulty, Theme.ILevel);

  Theme.PartyOptions.SelectPlayList.oneItemOnly := true;
  Theme.PartyOptions.SelectPlayList.showArrows := true;
  SelectPlayList  := AddSelectSlide(Theme.PartyOptions.SelectPlayList, PlayList, IPlaylist);

  Theme.PartyOptions.SelectPlayList2.oneItemOnly := true;
  Theme.PartyOptions.SelectPlayList2.showArrows := true;
  SelectPlayList2 := AddSelectSlide(Theme.PartyOptions.SelectPlayList2, PlayList2, IPlaylist2);

  FillLevel;

  Interaction := 0;
end;

procedure TScreenPartyOptions.FillPlaylist;
begin
  SetLength(IPlaylist, 3);

  IPlaylist[0] := Language.Translate('PARTY_PLAYLIST_ALL');
  IPlaylist[1] := Language.Translate('PARTY_PLAYLIST_CATEGORY');
  IPlaylist[2] := Language.Translate('PARTY_PLAYLIST_PLAYLIST');
end;

procedure TScreenPartyOptions.FillPlaylistJukebox;
begin
  SetLength(IPlaylist, 3);

  IPlaylist[0] := Language.Translate('PARTY_PLAYLIST_ALL');
  IPlaylist[1] := Language.Translate('PARTY_PLAYLIST_CATEGORY');
  IPlaylist[2] := Language.Translate('PARTY_PLAYLIST_PLAYLIST');
end;

procedure TScreenPartyOptions.FillLevel;
begin
  SetLength(ILevel, 3);

  ILevel[0] := Language.Translate('SING_EASY');
  ILevel[1] := Language.Translate('SING_MEDIUM');
  ILevel[2] := Language.Translate('SING_HARD');
end;

procedure TScreenPartyOptions.SetPlaylists;
begin
  UpdateSelectSlideOptions(SelectLevel, ILevel, Level);

  FillPlaylist;

  UpdateSelectSlideOptions(SelectPlayList, IPlaylist, Playlist);

  SetPlaylist2;
end;

procedure TScreenPartyOptions.SetPlaylist2;
var
  I: integer;
begin
  case Playlist of
    0:
      begin
        SetLength(IPlaylist2, 1);
        IPlaylist2[0] := '---';
      end;
    1:
      begin
        SetLength(IPlaylist2, 0);
        for I := 0 to high(CatSongs.Song) do
        begin
          if (CatSongs.Song[I].Main) then
          begin
            SetLength(IPlaylist2, Length(IPlaylist2) + 1);
            IPlaylist2[high(IPlaylist2)] := CatSongs.Song[I].Artist;
          end;
        end;

        if (Length(IPlaylist2) = 0) then
        begin
          SetLength(IPlaylist2, 1);
          IPlaylist2[0] := 'No Categories found';
        end;
      end;
    2:
      begin
        if (Length(PlaylistMan.Playlists) > 0) then
        begin
          SetLength(IPlaylist2, Length(PlaylistMan.Playlists));
          PlaylistMan.GetNames(IPlaylist2);
        end
        else
        begin
          SetLength(IPlaylist2, 1);
          IPlaylist2[0] := 'No Playlists found';
        end;
      end;
    3:
      begin
        SetLength(IPlaylist2, 1);
        IPlaylist2[0] := '---';
      end;
  end;

  Playlist2 := 0;
  UpdateSelectSlideOptions(SelectPlayList2, IPlaylist2, Playlist2);
end;

procedure TScreenPartyOptions.OnShow;
begin
  inherited;

  if not Help.SetHelpID(ID) then
    Log.LogWarn('No Entry for Help-ID ' + ID, 'ScreenPartyOptions');

  Party.Clear;

  SetPlaylists;

  LoadPlaylistCovers;
  CarouselPos := 0;
  LastDrawTicks := 0;

  // check if there are loaded modes
  if Party.ModesAvailable then
  begin
    // modes are loaded
    Randomize;
  end
  else
  begin // no modes found
    ScreenPopupError.ShowPopup(Language.Translate('ERROR_NO_PLUGINS'));
    Display.AbortScreenChange;
  end;
end;

procedure TScreenPartyOptions.OnHide;
begin
  inherited;
  FreePlaylistCovers;
end;

{ loads <name>.jpg / .png / .jpeg next to each <name>.upl; nil = placeholder }
procedure TScreenPartyOptions.LoadPlaylistCovers;
const
  Exts: array[0..3] of RawByteString = ('.jpg', '.png', '.jpeg', '.JPG');
var
  I, E: integer;
  CoverFile: IPath;
begin
  FreePlaylistCovers;
  SetLength(CoverTex, Length(PlaylistMan.Playlists));
  for I := 0 to High(CoverTex) do
  begin
    CoverTex[I] := nil;
    for E := 0 to High(Exts) do
    begin
      CoverFile := PlaylistPath.Append(PlaylistMan.Playlists[I].Filename.SetExtension(Exts[E]));
      if CoverFile.IsFile then
      begin
        CoverTex[I] := Renderer.LoadTexture(CoverFile, TEXTURE_TYPE_PLAIN, 0);
        if (CoverTex[I] <> nil) and CoverTex[I].IsEmpty then
        begin
          CoverTex[I].Free;
          CoverTex[I] := nil;
        end;
        if (CoverTex[I] <> nil) then
          Break;
      end;
    end;
  end;
end;

procedure TScreenPartyOptions.FreePlaylistCovers;
var
  I: integer;
begin
  for I := 0 to High(CoverTex) do
    if (CoverTex[I] <> nil) then
      CoverTex[I].Free;
  SetLength(CoverTex, 0);
end;

{ draws one cover (or the placeholder) centered at CX, top at CY }
procedure TScreenPartyOptions.DrawCover(Index: integer; CX, CY, Size, Alpha: real);
var
  X: real;
  Name, Line, Wd: UTF8String;
  Lines: array of UTF8String;
  I, MaxChars, L: integer;
  FontSz, TY: real;

  function CharCount(const S: UTF8String): integer;
  var
    C: integer;
  begin
    Result := 0;
    for C := 1 to Length(S) do
      if (Ord(S[C]) and $C0) <> $80 then
        Inc(Result);
  end;

begin
  X := CX - Size / 2;
  // light frame
  Renderer.DrawQuad(X - 3, CY - 3, 0, Size + 6, Size + 6, 1, 1, 1, Alpha * 0.85);

  if (Index <= High(CoverTex)) and (CoverTex[Index] <> nil) then
  begin
    CoverTex[Index].X := X;
    CoverTex[Index].Y := CY;
    CoverTex[Index].Z := 0;
    CoverTex[Index].W := Size;
    CoverTex[Index].H := Size;
    CoverTex[Index].ColR := 1;
    CoverTex[Index].ColG := 1;
    CoverTex[Index].ColB := 1;
    CoverTex[Index].Alpha := Alpha;
    CoverTex[Index].Reflection := false;
    Renderer.DrawTexture(CoverTex[Index]);
    Exit;
  end;

  // placeholder: dark theme blue with the playlist name
  Renderer.DrawQuad(X, CY, 0, Size, Size, 0.06, 0.22, 0.45, Alpha);
  Renderer.DrawQuad(X, CY, 0, Size, Size * 0.18, 0.15, 0.45, 0.80, Alpha);

  Name := PlaylistMan.Playlists[Index].Name;
  FontSz := Size / 7;
  MaxChars := Trunc((Size - 12) / (FontSz * 0.6));
  if MaxChars < 4 then
    MaxChars := 4;

  // word wrap (estimated by number of characters)
  SetLength(Lines, 0);
  Line := '';
  Name := Name + ' ';
  Wd := '';
  for I := 1 to Length(Name) do
  begin
    if Name[I] = ' ' then
    begin
      if (Line <> '') and (CharCount(Line) + 1 + CharCount(Wd) > MaxChars) then
      begin
        SetLength(Lines, Length(Lines) + 1);
        Lines[High(Lines)] := Line;
        Line := Wd;
      end
      else if Line = '' then
        Line := Wd
      else
        Line := Line + ' ' + Wd;
      Wd := '';
    end
    else
      Wd := Wd + Name[I];
  end;
  if Line <> '' then
  begin
    SetLength(Lines, Length(Lines) + 1);
    Lines[High(Lines)] := Line;
  end;
  if Length(Lines) > 5 then
    SetLength(Lines, 5);

  SetFontFamily(0);
  SetFontStyle(ftBoldHighRes);
  SetFontItalic(false);
  SetFontSize(FontSz);
  SetFontColor(1, 1, 1, Alpha);
  TY := CY + Size * 0.18 + (Size * 0.82 - Length(Lines) * FontSz * 1.15) / 2;
  for L := 0 to High(Lines) do
  begin
    SetFontPos(CX - CharCount(Lines[L]) * FontSz * 0.3, TY + L * FontSz * 1.15);
    PrintText(Lines[L]);
  end;
end;

procedure TScreenPartyOptions.DrawCarousel;
const
  CENTER_X = 400;
  TOP_Y    = 335;
  BIG      = 175;
var
  Count, I, Off: integer;
  TicksNow: cardinal;
  Dt, D, Size, Alpha, CX, CY: real;
  Order: array[0..4] of integer;
begin
  Count := Length(PlaylistMan.Playlists);
  if (Playlist <> 2) or (Count = 0) or (Length(CoverTex) <> Count) then
    Exit;

  // smooth movement towards the selected playlist
  TicksNow := SDL_GetTicks();
  if LastDrawTicks = 0 then
    CarouselPos := Playlist2;
  Dt := (TicksNow - LastDrawTicks) / 1000;
  if Dt > 0.1 then
    Dt := 0.1;
  LastDrawTicks := TicksNow;
  CarouselPos := CarouselPos + (Playlist2 - CarouselPos) * (1 - Exp(-Dt * 12));
  if Abs(Playlist2 - CarouselPos) < 0.002 then
    CarouselPos := Playlist2;

  // draw the outer covers first, the selected one last (on top)
  Order[0] := -2; Order[1] := 2; Order[2] := -1; Order[3] := 1; Order[4] := 0;
  for Off := 0 to 4 do
  begin
    I := Round(CarouselPos) + Order[Off];
    if (I < 0) or (I >= Count) then
      Continue;
    D := I - CarouselPos;            // distance from the center (-2.5 .. 2.5)
    if Abs(D) > 2.6 then
      Continue;
    Size := BIG - 50 * Abs(D);
    if Abs(D) > 1 then
      Size := 125 - 30 * (Abs(D) - 1);
    if Size < 60 then
      Size := 60;
    CX := CENTER_X + D * 150;
    if Abs(D) > 1 then
      if D < 0 then
        CX := CENTER_X - (150 + (Abs(D) - 1) * 115)
      else
        CX := CENTER_X + (150 + (Abs(D) - 1) * 115);
    CY := TOP_Y + (BIG - Size) / 2;
    Alpha := 1 - 0.3 * Abs(D);
    if Alpha < 0.25 then
      Alpha := 0.25;
    DrawCover(I, CX, CY, Size, Alpha);
  end;
end;

function TScreenPartyOptions.Draw: boolean;
begin
  Result := inherited Draw;
  DrawCarousel;
end;

function TScreenPartyOptions.ApplyPlaylistRestriction: boolean;
var
  I, J: integer;
begin
  Result := false;

  PlaylistMan.Mode := TSongMode(Playlist);
  PlaylistMan.CurPlayList := -1;

  if Playlist = 1 then
  begin
    J := -1;
    for I := 0 to high(CatSongs.Song) do
    begin
      if CatSongs.Song[I].Main then
        Inc(J);

      if J = Playlist2 then
      begin
        PlaylistMan.CurPlayList := I;
        Break;
      end;
    end;

    if PlaylistMan.CurPlayList = -1 then
      Exit;
  end
  else if Playlist = 2 then
  begin
    if (Length(PlaylistMan.Playlists) = 0) or (Playlist2 < 0) or (Playlist2 > High(PlaylistMan.Playlists)) then
      Exit
    else
      PlaylistMan.CurPlayList := Playlist2;
  end;

  Result := true;
end;

procedure TScreenPartyOptions.InitClassic;
begin
  if not ApplyPlaylistRestriction then
    Exit;

  ScreenSong.Mode := smPartyClassic;

  AudioPlayback.PlaySound(SoundLib.Start);
  //Go to Player Screen
  FadeTo(@ScreenPartyPlayer);
end;

procedure TScreenPartyOptions.InitFree;
begin
  if not ApplyPlaylistRestriction then
    Exit;

  ScreenSong.Mode := smPartyFree;
  AudioPlayback.PlaySound(SoundLib.Start);
  FadeTo(@ScreenPartyPlayer);
end;

procedure TScreenPartyOptions.InitTournament;
begin
  if not ApplyPlaylistRestriction then
    Exit;

  ScreenSong.Mode := smPartyTournament;
  AudioPlayback.PlaySound(SoundLib.Start);
  FadeTo(@ScreenPartyTournamentPlayer);
end;

end.
