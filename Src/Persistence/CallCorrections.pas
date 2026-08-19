unit CallCorrections;

interface

uses
  System.Generics.Collections;

type
  {
    Maintains optional callsign-based corrections used to
    repair known errors in contest call history files.

    Corrections are loaded from an external file and applied
    by contest-specific readers during record normalization.

    Currently supported:
      - State overrides

    Future versions may support additional correction fields.
  }
  TCallCorrections = class
  private
    FStateOverrides: TDictionary<string,string>;
  public
    constructor Create;
    destructor Destroy; override;

    {
      Load corrections from FileName.

      Corrections are accumulated across multiple calls.
      If the same callsign appears more than once, the most
      recently loaded value replaces the previous value.
    }    procedure LoadFromFile(const FileName: string);

    {
      Lookup an optional state override.

      Returns True when a correction exists for Call.
    }
    function TryGetStateOverride(
      const Call: string;
      out State: string): Boolean;
  end;

implementation

uses
  System.SysUtils,
  ContestFileFormat,
  ContestFileReader;

type
  TCallCorrectionRec = class
    Call: string;
    State: string;
  end;

constructor TCallCorrections.Create;
begin
  inherited;

  FStateOverrides := TDictionary<string,string>.Create;
end;

destructor TCallCorrections.Destroy;
begin
  FStateOverrides.Free;

  inherited;
end;

procedure TCallCorrections.LoadFromFile(const FileName: string);
var
  Reader: TContestFileReader<TCallCorrectionRec>;
begin
  Reader := TContestFileReader<TCallCorrectionRec>.Create([cffN1MMCsv]);
  try
    Reader.AddDefaultBinding('Call', True,
      procedure(const Value: string; Rec: TCallCorrectionRec) begin
        Rec.Call := Value.ToUpper;
      end);
    Reader.AddDefaultBinding('State', True,
      procedure(const Value: string; Rec: TCallCorrectionRec) begin
        Rec.State := Value.ToUpper;
      end);

    Reader.ReadFile(FileName,
      procedure(Rec: TCallCorrectionRec)
      begin
        FStateOverrides.AddOrSetValue(Rec.Call, Rec.State);
        Rec.Free;
      end);

  finally
    Reader.Free;
  end;
end;

function TCallCorrections.TryGetStateOverride(
  const Call: string;
  out State: string): Boolean;
begin
  Result := FStateOverrides.TryGetValue(Call.ToUpper, State);
end;

end.
