{ Reminds me how to work with SDL under Free Pascal                       }
{                                                                         }
{ Portions (C) Zach Metzinger are under BSD license:                      }
{                                                                         }
{ Redistribution and use in source and binary forms, with or without      }
{ modification, are permitted provided that the following conditions      }
{ are met:                                                                }
{ 1. Redistributions of source code must retain the above copyright       }
{    notice, this list of conditions and the following disclaimer.        }
{ 2. Redistributions in binary form must reproduce the above copyright    }
{    notice, this list of conditions and the following disclaimer in the  }
{    documentation and/or other materials provided with the distribution. }
{                                                                            }
{ THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND     }
{ ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE      }
{ IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE }
{ ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE    }
{ FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL } 
{ DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS    }
{ OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)      }
{ HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT }
{ LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY  }
{ OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF     }
{ SUCH DAMAGE.                                                               }

{ I am not a Pascal programmer, bur, rather, a C programmer..               }
{  .. so this will be fast and loose. Don't take this as best practices.    }

program sdltest;
{$linklib gcc}
{$linklib SDLmain}
uses sdl, strings;

var
   abuf	: PUInt8;
   alen	: UInt32;
   acur	: UInt32;
   
procedure AudioFeed(userdata : Pointer; stream : PUInt8; len : LongInt); cdecl;
var
   i : Integer;
   j : UInt32;
begin
   j := UInt32(userdata^);
   WriteLn('acur = ', j, ' userdata^ = ', UInt32(userdata^));
   for i := 0 to len-1 do
      begin
	 stream[i] := abuf[j];
	 j := j + 1;
      end;
   UInt32(userdata^) := UInt32(userdata^) + len;
   if UInt32(userdata^) > alen then
      begin
	 UInt32(userdata^) := 0;
      end;
end;

var 
   scr		    : PSDL_Surface; // Our main screen
   sdlKeyboardState : PUInt8;
   Run		    : Boolean = True;
   des, got	    : PSDL_AudioSpec;
   err		    : String;
   evt		    : PSDL_Event;
   fname	    : PChar;
begin
   if SDL_Init(SDL_INIT_VIDEO or SDL_INIT_AUDIO) < 0 then Exit;
   // Create a software window of 640x480x8 and assign to scr
   scr := SDL_SetVideoMode(640, 480, 8, SDL_SWSURFACE);
   des := New(PSDL_AudioSpec);
   got := New(PSDL_AudioSpec);
   evt := New(PSDL_Event);
   fname := StrAlloc (255+1);
   with des^ do
      begin
	 freq := 44100;
	 format := AUDIO_S16LSB;
	 channels := 2;
	 samples := 8192;
	 callback := @AudioFeed;
	 userdata := @acur;
      end;
   if SDL_OpenAudio(des, got) < 0 then
      begin
	 err := SDL_GetError();
	 WriteLn('OpenAudio failed: ', err);
	 Exit;
      end;

   WriteLn('OpenAudio got ', got^.freq, ' ', got^.format, ' ', got^.channels, ' ', got^.samples);

   got^.freq := 0;

   if ParamCount() < 1 then
      begin
	 WriteLn('usage: ', ParamStr(0), ' <something.wav>');
	 Exit;
      end;

   StrPCopy(fname, ParamStr(1));
   
   if SDL_LoadWAV(fname, got, @abuf, @alen) = nil then
      begin
	 WriteLn('Unable to load WAV file: ', fname);
	 Exit;
      end;
   
   WriteLn('LoadWAV got ', got^.freq, ' ', got^.format, ' ', got^.channels, ' ', got^.samples,
	   ' length: ', alen);
   
   if alen < (des^.samples * des^.channels * 2) then
      begin
	 WriteLn('Not enough samples in WAV file: ', des^.samples);
	 Exit;
      end;
   
   acur := 0;
   while Run = True do
      begin
	 SDL_WaitEvent(evt);
	 sdlKeyboardState := SDL_GetKeyState(nil);

	 // ESC pressed
	 if sdlKeyboardState[SDLK_ESCAPE] = 1 then
	    Run := False;
	 if sdlKeyboardState[SDLK_0] = 1 then
	    SDL_PauseAudio(0);
	 if sdlKeyboardState[SDLK_1] = 1 then
	    SDL_PauseAudio(1);
      end;
   SDL_Quit; // close the subsystems and SDL
end.
