//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit Arrl10m.Reader;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  DXCC,
  ContestFileFormat,
  ContestFileReader,
  Arrl10m.Types,
  CallCorrections;

type
  TArrl10mColumns = record
    Call: Integer;
    State: Integer;
    Section: Integer;
    UserText: Integer;
  end;

  TArrl10mContestFileReader = class(TContestFileReader<TArrl10mCallRec>)
  private
    FCols: TArrl10mColumns;
    FCorrections: TCallCorrections;

    // Temporary value parsed from the input row that are
    // needed during NormalizeRecord but are not stored in
    // the final TArrl10mCallRec.
    FTemp: record
      Section: string;
      dxcc: TDxCCRec;
    end;

    FMdcCounter: Integer;

{$ifdef DEBUG}
    SelectDx, DxccTest, SelectHi, SelectAk, SelectXe, SelectNa, Select: boolean;
    Keep50, Skip: Integer;
{$endif}

    procedure ResetColumns;

  protected
    function HandleLine(const Line: String): Boolean; override;

    procedure ParseSectionHeader(
      const Format: TContestFileFormat;
      const Fields: TStrings); override;

    procedure ParseRow(
      const Fields: TStrings;
      Rec: TArrl10mCallRec); override;

    procedure NormalizeRecord(Rec: TArrl10mCallRec); override;
    function KeepRecord(const Rec: TArrl10mCallRec): Boolean; override;

  public
    constructor Create;
    destructor Destroy; override;
  end;

implementation

uses
  AppPaths,
  Arrl10m.Policy,
  ArrlSections;   // for SectionToState

constructor TArrl10mContestFileReader.Create;
begin
  inherited Create([cffN1MMCsv, cffARRLTsv]);

  FCorrections := TCallCorrections.Create;
  FCorrections.LoadFromFile(TAppPaths.ContestDataFile('Arrl10m-corrections.txt'));

  ResetColumns;
  FMdcCounter := 0;
end;

destructor TArrl10mContestFileReader.Destroy;
begin
  FCorrections.Free;

  inherited;
end;


procedure TArrl10mContestFileReader.ResetColumns;
begin
  FCols.Call := -1;
  FCols.State := -1;
  FCols.Section := -1;
  FCols.UserText := -1;

{$ifdef DEBUG}
  DxccTest := False;
  SelectDx := False;
  SelectHi := False;
  SelectAk := False;
  SelectXe := False;
  SelectNa := False;
  Keep50 := -1; //50;
  Skip := 0;
{$endif}
end;

function TArrl10mContestFileReader.HandleLine(const Line: String): Boolean;
begin
  if inherited HandleLine(Line) then
    Exit(True);

{$ifdef DEBUG}
  Result := True;
  if SameText(Line, 'Break') then StopReading
  else if SameText(Line, 'DxccTest') then DxccTest := True
  else if SameText(Line, 'SelectDx') then SelectDx := True
  else if SameText(Line, 'SelectHi') then SelectHi := True
  else if SameText(Line, 'SelectAk') then SelectAk := True
  else if SameText(Line, 'SelectXe') then SelectXe := True
  else if SameText(Line, 'Keep50'  ) then Keep50 := 20
  else if SameText(Line, 'SelectNa') then SelectNa := True
  else
    Result := False;
{$else}
  Result := False;
{$endif}
end;

procedure TArrl10mContestFileReader.ParseSectionHeader(
  const Format: TContestFileFormat;
  const Fields: TStrings);
begin
  inherited ParseSectionHeader(Format, Fields);

  ResetColumns;

  case Format of
    cffN1MMCsv:
      begin
        assert(Fields[0] <> '!!Order!!', 'removed by NormalizeHeaderFields');

        FCols.Call := RequireField('Call');
        FCols.State := OptionalField('State');
        FCols.Section := OptionalField('Section');
        FCols.UserText := OptionalField('UserText');

        if (FCols.State = -1) and (FCols.Section = -1) then
        begin
          raise Exception.CreateFmt(
            'Invalid call history file: header must contain either "State" or "Section". Line %d, File "%s"',
            [LineNumber, FileName]);
        end;
      end;

    cffArrlTsv:
      begin
        FCols.Call := RequireField('call');
        FCols.State := -1;
        FCols.Section := RequireField('section');
        FCols.UserText := OptionalField('club');
      end;
  end;
end;

procedure TArrl10mContestFileReader.ParseRow(
  const Fields: TStrings;
  Rec: TArrl10mCallRec);
begin
  Rec.Call := GetValue(Fields, FCols.Call).ToUpper;
  Rec.State := GetValue(Fields, FCols.State).ToUpper;
  FTemp.Section := GetValue(Fields, FCols.Section).ToUpper;
  Rec.UserText := GetValue(Fields, FCols.UserText);
  FTemp.dxcc := nil;
end;

procedure TArrl10mContestFileReader.NormalizeRecord(Rec: TArrl10mCallRec);
const
  MM_RATE = TArrl10mPolicy.MaritimeMobileProbability;
var
  State: String;
begin
  inherited NormalizeRecord(Rec);

  // Normalize in dependency order:
  //
  // 1. Correct callsigns first.
  // 2. Convert contest sections to canonical states
  //    (MDC alternates MD/DC using FMdcCounter).
  // 3. Apply remaining field normalization.
  if Rec.Call = '4U1WB' then
    Rec.State := 'DC'
  else if not Rec.Call.Contains('/') and (random < MM_RATE) then
  begin
    // convert 0.5% of callsigns to Maritime Mobile
    Rec.Call := Rec.Call + '/MM';
    Rec.State := IntToStr(1 + random(3));
  end
  else if Rec.State.IsEmpty then
  begin
    // importing from Arrl Contest Summary (no State field)
    if FTemp.Section = 'MDC' then
    begin
      // apply callsign-based corrections for 'MD' or'DC'
      if FCorrections.TryGetStateOverride(Rec.Call, State) then
        Rec.State := State
      else
        // otherwise, equally distribute between DC and MD
        Rec.State := SectionToState(FTemp.Section, FMdcCounter);
    end
    else
      Rec.State := SectionToState(FTemp.Section);
  end;

  // if State is empty, confirm DX
  if Rec.State.IsEmpty then
  begin
    if not gDXCCList.FindRec(FTemp.dxcc, Rec.Call) then
      Exit;

    if FTemp.dxcc.Entity = 'Alaska' then
      Rec.State := 'AK'
    else if FTemp.dxcc.Entity = 'Hawaii' then
      Rec.State := 'HI';
  end;
end;

function TArrl10mContestFileReader.KeepRecord(const Rec: TArrl10mCallRec): Boolean;
begin
  if Rec.State.IsEmpty and (FTemp.dxcc = nil) then
    Exit(False);

  Result := True;
{$IFDEF DEBUG}
  // debug hook to force each call to look up DXCC Record
  if DxccTest and (FTemp.dxcc = nil) and not gDXCCList.FindRec(FTemp.dxcc, Rec.Call) then
  begin
    assert(false);
    Exit(False);
  end;

  // debug hooks provide ability to load subset of call history
  Select := not (SelectDx or SelectHi or SelectAk or SelectXe or SelectNa);
  Select := Select or (SelectDx and not TArrl10mPolicy.IsCallLocalToContest(Rec.Call));
  Select := Select or (SelectNA and TArrl10mPolicy.IsCallLocalToContest(Rec.Call));
  if not Select and (SelectHi or SelectAk or SelectXe) then
  begin
    if (FTemp.dxcc = nil) and not gDXCCList.FindRec(FTemp.dxcc, Rec.Call) then
      Exit(False);
    Select := Select or (SelectHi and FTemp.dxcc.Entity.Equals('Hawaii'));
    Select := Select or (SelectAk and FTemp.dxcc.Entity.Equals('Alaska'));
    Select := Select or (SelectXe and FTemp.dxcc.Entity.Equals('Mexico'));
  end;

  // if not already selected, add Keep50 local calls to the contest
  if not Select and (Keep50>0) and
    TArrl10mPolicy.IsCallLocalToContest(Rec.Call) then
  begin
    if Skip > 0 then
      begin
        Dec(Skip);
        Exit(False);
      end;
    Dec(Keep50);
    if Keep50>0 then Skip := 100;
    Select := True;
  end;

  Result := Select;
{$endif}
end;

end.
