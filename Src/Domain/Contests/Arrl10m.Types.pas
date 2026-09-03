//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit Arrl10m.Types;

interface

type
  TArrl10mCallRec = class
  public
    Call: string;     // call sign
    State: string;    // State/Province (US/Canada/Mexico)
    UserText: string; // optional UserText

    function GetString: string; // returns <State> [User Text]
    class function compareCall(const left, right: TArrl10mCallRec) : integer; static;
  end;

implementation

uses
  System.SysUtils;

class function TArrl10mCallRec.compareCall(const left, right: TArrl10mCallRec) : integer;
begin
  Result := CompareStr(left.Call, right.Call);
end;


function TArrl10mCallRec.GetString: string; // returns <State> [UserText]
begin
  Result := Format(' - %s', [State]);
  if UserText <> '' then
    Result := Result + ' ' + UserText;
end;

end.
