unit ArrlDx.Types;

interface

type
  TArrlDxCallRec = class
  public
    Call: string;     // call sign
    State: string;    // State/Province (US/Canada)
    Power: string;    // Power (DX Stations)
    UserText: string; // club name
    function GetString: string; // returns <State>|<Power> [UserText]
    class function compareCall(const left, right: TArrlDxCallRec) : integer; static;
  end;

implementation

uses
  System.SysUtils;

class function TArrlDxCallRec.compareCall(const left, right: TArrlDxCallRec) : integer;
begin
  Result := CompareStr(left.Call, right.Call);
end;


function TArrlDxCallRec.GetString: string; // returns <State>|<Power> [UserText]
begin
  Result := Format(' - %s%s', [State, Power]);
  if UserText <> '' then
    Result := Result + ' ' + UserText;
end;


end.
