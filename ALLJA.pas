unit ALLJA;

{$ifdef FPC}
{$MODE Delphi}
{$endif}

{
  JARL ALL JA Contest. All of the behaviour lives in TJarlContest (JarlContest.pas);
  this unit only names the call-history file.
}

interface

uses
  JarlContest;

type
  TAllJaCallRec = TJarlCallRec;

  TALLJA = class(TJarlContest)
  protected
    function CallHistoryFileName: string; override;
  end;

implementation

function TALLJA.CallHistoryFileName: string;
begin
  Result := 'JARL_ALLJA.TXT';
end;

end.
