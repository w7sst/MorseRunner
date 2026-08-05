//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
//
// Minimal dynamic binding to the PulseAudio "simple" API, used by the Linux
// build of SndCustm/SndOut in place of the Win32 waveOut API. The library is
// loaded on demand so that the executable has no link-time dependency on
// PulseAudio; on Fedora the calls are serviced by pipewire-pulse.
//
unit SndPulse;

{$MODE DELPHI}
{$PACKRECORDS C}

interface

uses
  SysUtils, ctypes, dynlibs;

const
  PulseSimpleLibName = 'libpulse-simple.so.0';
  PulseLibName       = 'libpulse.so.0';

  //pa_stream_direction_t
  PA_STREAM_NODIRECTION = 0;
  PA_STREAM_PLAYBACK    = 1;
  PA_STREAM_RECORD      = 2;

  //pa_sample_format_t
  PA_SAMPLE_S16LE = 3;

type
  Ppa_simple = Pointer;

  Ppa_sample_spec = ^Tpa_sample_spec;
  Tpa_sample_spec = record
    format:   cint;      // pa_sample_format_t
    rate:     cuint32;
    channels: cuint8;
  end;

  Ppa_buffer_attr = ^Tpa_buffer_attr;
  Tpa_buffer_attr = record
    maxlength: cuint32;
    tlength:   cuint32;
    prebuf:    cuint32;
    minreq:    cuint32;
    fragsize:  cuint32;
  end;

var
  pa_simple_new: function(const server: PAnsiChar; const name: PAnsiChar;
    dir: cint; const dev: PAnsiChar; const stream_name: PAnsiChar;
    const ss: Ppa_sample_spec; const map: Pointer;
    const attr: Ppa_buffer_attr; error: pcint): Ppa_simple; cdecl;

  pa_simple_free:  procedure(s: Ppa_simple); cdecl;
  pa_simple_write: function(s: Ppa_simple; const data: Pointer;
                            bytes: csize_t; error: pcint): cint; cdecl;
  pa_simple_drain: function(s: Ppa_simple; error: pcint): cint; cdecl;
  pa_simple_flush: function(s: Ppa_simple; error: pcint): cint; cdecl;
  pa_strerror:     function(error: cint): PAnsiChar; cdecl;

//Loads libpulse-simple/libpulse on first call. Returns false if unavailable.
function  LoadPulse: boolean;
procedure UnloadPulse;
function  IsPulseLoaded: boolean;

//Human-readable text for a PulseAudio error code.
function  PulseErrorText(AError: cint): string;

implementation

var
  hPulseSimple: TLibHandle = NilHandle;
  hPulse:       TLibHandle = NilHandle;

function IsPulseLoaded: boolean;
begin
  Result := hPulseSimple <> NilHandle;
end;


procedure UnloadPulse;
begin
  if hPulseSimple <> NilHandle then
    begin
    UnloadLibrary(hPulseSimple);
    hPulseSimple := NilHandle;
    end;
  if hPulse <> NilHandle then
    begin
    UnloadLibrary(hPulse);
    hPulse := NilHandle;
    end;

  pa_simple_new := nil;
  pa_simple_free := nil;
  pa_simple_write := nil;
  pa_simple_drain := nil;
  pa_simple_flush := nil;
  pa_strerror := nil;
end;


function LoadPulse: boolean;
begin
  Result := IsPulseLoaded;
  if Result then Exit;

  hPulseSimple := LoadLibrary(PulseSimpleLibName);
  if hPulseSimple = NilHandle then Exit(false);

  //pa_strerror lives in the main library, not the "simple" wrapper
  hPulse := LoadLibrary(PulseLibName);

  pa_simple_new   := GetProcedureAddress(hPulseSimple, 'pa_simple_new');
  pa_simple_free  := GetProcedureAddress(hPulseSimple, 'pa_simple_free');
  pa_simple_write := GetProcedureAddress(hPulseSimple, 'pa_simple_write');
  pa_simple_drain := GetProcedureAddress(hPulseSimple, 'pa_simple_drain');
  pa_simple_flush := GetProcedureAddress(hPulseSimple, 'pa_simple_flush');
  if hPulse <> NilHandle then
    pa_strerror := GetProcedureAddress(hPulse, 'pa_strerror');

  Result := Assigned(pa_simple_new) and Assigned(pa_simple_free) and
            Assigned(pa_simple_write);
  if not Result then UnloadPulse;
end;


function PulseErrorText(AError: cint): string;
begin
  if Assigned(pa_strerror)
    then Result := string(AnsiString(pa_strerror(AError)))
    else Result := 'PulseAudio error ' + IntToStr(AError);
end;


finalization
  UnloadPulse;
end.
