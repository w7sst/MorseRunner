//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit ArrlDx.Reader;

interface

uses
  System.Classes,
  ContestFileFormat,
  ContestFileReader,
  ArrlDx.Types;

type
  TArrlDxColumns = record
    Call: Integer;
    State: Integer;
    Power: Integer;
    UserText: Integer;
  end;

  TArrlDxContestFileReader = class(TContestFileReader<TArrlDxCallRec>)
  private
    FHomeCallIsLocal: boolean; // user's callsign is local to this contest
    FCols: TArrlDxColumns;

    procedure ResetColumns;

  protected
    procedure ParseSectionHeader(
      const Format: TContestFileFormat;
      const Fields: TStrings); override;

    procedure ParseRow(
      const Fields: TStrings;
      Rec: TArrlDxCallRec); override;

    function KeepRecord(const Rec: TArrlDxCallRec): Boolean; override;

  public
    constructor Create(AHomeCallIsLocal: Boolean);
  end;

implementation

uses
  System.SysUtils;

constructor TArrlDxContestFileReader.Create(AHomeCallIsLocal: Boolean);
begin
  inherited Create([cffN1MMCsv]);

  FHomeCallIsLocal := AHomeCallIsLocal;
  ResetColumns;
end;


procedure TArrlDxContestFileReader.ResetColumns;
begin
  FCols.Call := -1;
  FCols.State := -1;
  FCols.Power := -1;
  FCols.UserText := -1;
end;


procedure TArrlDxContestFileReader.ParseSectionHeader(
  const Format: TContestFileFormat;
  const Fields: TStrings);
begin
  inherited ParseSectionHeader(Format, Fields);

  ResetColumns;

  assert(Format = cffN1MMCsv);
  assert(Fields[0] <> '!!Order!!', 'removed by NormalizeHeaderFields');

  // !!Order!!,Call,Name,State,Power,UserText,  // Dx Stations
  // !!Order!!,Call,Name,State,                 // US Stations
  // DX sends Call,Power
  // W/VE sends Call,State
  FCols.Call := RequireField('Call');
  FCols.State := OptionalField('State');
  FCols.Power := OptionalField('Power');
  FCols.UserText := OptionalField('UserText');
end;

procedure TArrlDxContestFileReader.ParseRow(
  const Fields: TStrings;
  Rec: TArrlDxCallRec);
begin
  Rec.Call := GetValue(Fields, FCols.Call).ToUpper;
  Rec.State := GetValue(Fields, FCols.State).ToUpper;
  Rec.Power := GetValue(Fields, FCols.Power).ToUpper;
  Rec.UserText := GetValue(Fields, FCols.UserText);
end;

function TArrlDxContestFileReader.KeepRecord(const Rec: TArrlDxCallRec): Boolean;
begin
  if Rec.Call.IsEmpty then
    Exit(False);

  // W/VE stations work only DX stations (those with non-empty Power field);
  // DX Stations work only W/VE stations (those with non-empty State field)
  Result := (    FHomeCallIsLocal and not Rec.Power.IsEmpty) or
            (not FHomeCallIsLocal and not Rec.State.IsEmpty);
end;

end.
