unit ContestFileFormat;

interface

uses
  System.Classes;

type
  TContestFileFormat = (
    cffUnknown,
    cffN1MMCsv,
    cffArrlTsv
  );

  TContestFileFormats = set of TContestFileFormat;

  TContestFileFormatInfo = record
    Format: TContestFileFormat;
    Description: String;
    Delimiter: Char;
    SupportsDynamicHeaders: Boolean;
  end;

  function DetectFormat(const Lines: TStrings): TContestFileFormatInfo;

  { Does this row represent a format-defined header/directive? }
  function IsFormatHeaderDirective(
    const Format: TContestFileFormat;
    const Fields: TStrings): Boolean;

  procedure ParseFields(
    const Line: string;
    const FormatInfo: TContestFileFormatInfo;
    Fields: TStrings);

  function GetValue(const Fields: TStrings; ColumnInx: Integer): string;

implementation

uses
  System.SysUtils;

function DetectFormat(const Lines: TStrings): TContestFileFormatInfo;
var
  i: Integer;
  S: string;
begin
  Result.Format := cffUnknown;
  Result.Description := 'an Unknown';
  Result.Delimiter := #0;
  Result.SupportsDynamicHeaders := False;

  for i := 0 to Lines.Count - 1 do
  begin
    S := Lines[i].Trim;

    // skip blank lines
    if S.IsEmpty then
      Continue;

    // skip comments
    if S.StartsWith('#') then
      Continue;

    // N1MM CSV format
    if S.StartsWith('!!Order!!,') then
    begin
      Result.Format := cffN1MMCsv;
      Result.Description := 'N1MM Call History';
      Result.Delimiter := ',';
      Result.SupportsDynamicHeaders := True;
      Exit;
    end;

    // ARRL TSV format
    if S.StartsWith('cabrillo_id'#9) then
    begin
      Result.Format := cffArrlTsv;
      Result.Description := 'ARRL Score Summary';
      Result.Delimiter := #9;
      Result.SupportsDynamicHeaders := False;
      Exit;
    end;

    // unknown first data line
    Break;
  end;
end;


function IsFormatHeaderDirective(
  const Format: TContestFileFormat;
  const Fields: TStrings): Boolean;
begin
  Result := False;

  if Fields.Count = 0 then
    Exit;

  case Format of
    cffN1MMCsv:
      Result := SameText(Fields[0], '!!Order!!');

    cffArrlTsv:
      Result := SameText(Fields[0], 'cabrillo_id');
  end;
end;


procedure ParseFields(
  const Line: string;
  const FormatInfo: TContestFileFormatInfo;
  Fields: TStrings);
begin
  Fields.Clear;

  // CSV and TSV use different delimiters.
  Fields.StrictDelimiter := True;
  Fields.Delimiter := FormatInfo.Delimiter;

  Fields.DelimitedText := Line;
end;


{ Returns the field value for the specified column index.
  If the index is invalid or the column is missing, an empty string is returned.
  Leading and trailing whitespace is removed.
}
function GetValue(
  const Fields: TStrings;
  ColumnInx: Integer): string;
begin
  if Cardinal(ColumnInx) < Cardinal(Fields.Count) then
    Result := Fields[ColumnInx].Trim
  else
    Result := '';
end;

end.
