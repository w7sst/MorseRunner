unit ACAG;

{$ifdef FPC}
{$MODE Delphi}
{$endif}

{
  JARL All Cluster Get Contest (ACAG). All of the behaviour lives in TJarlContest (JarlContest.pas);
  this unit only names the call-history file.
}

interface

uses
  JarlContest;

type
  TAcagCallRec = TJarlCallRec;

  TACAG = class(TJarlContest)
  protected
    function CallHistoryFileName: string; override;
  end;

implementation

function TACAG.CallHistoryFileName: string;
begin
  Result := 'JARL_ACAG.TXT';
end;

end.
