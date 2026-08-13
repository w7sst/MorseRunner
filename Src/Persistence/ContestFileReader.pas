//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit ContestFileReader;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  ContestFileFormat;

type
  {
    Consumes a record produced by TContestFileReader.
    Ownership of Rec is transferred to the consumer.

    The consumer may:
      - Store the record
      - Process the record immediately
      - Free the record

    If the consumer retains the record, it becomes responsible
    for eventually freeing it.
    If the consumer doesn't retain the record, it must immediately free it.
  }
  TRecordConsumer<TCallRec> = reference to procedure(Rec: TCallRec);

{
  Generic contest data file reader.

  Responsibilities:
    - Detect file format and parse input files.
    - Iterate files, sections, and data rows.
    - Maintain file/line context for diagnostics.
    - Build column maps from section headers.
    - Support optional field bindings.
    - Create, populate, and filter call records.
    - Deliver accepted call records via consumer.

  Derived classes typically implement one of two approaches:

    1) Explicit parsing
       - Override ParseSectionHeader() to extract column indexes.
         When overriding, be sure to call the base class to populate FColumnMap.
       - Override ParseRow() to populate row fields manually.

    2) Binding-based parsing
       - Override ConfigureBindings() and call AddBinding().
       - Use the default ParseRow() implementation.

  Record ownership:
    Records are created by the reader and passed to the consumer.
    Ownership transfers to the consumer, which is responsible for
    storing or freeing the record as appropriate.

  Example:
    Reader.ReadFile(FileName,
      procedure(Rec: TCallRec)
      begin
        CallList.Add(Rec);   // consumer now owns the record
      end);

  Developed with the assistance of OpenAI/ChatGPT.
}
TContestFileReader<TCallRec: class, constructor> = class
  protected type
    TValueBinder<TCallRec> = reference to procedure(const Value: string; Rec: TCallRec);

    TBindingDefinition<TCallRec> = record
      ColumnName: string;
      Required: Boolean;
      Apply: TValueBinder<TCallRec>;
    end;

    TCompiledBinding<TCallRec> = record
      ColumnIndex: Integer;
      Apply: TValueBinder<TCallRec>;
    end;

    TColumnMap = class
    private
      FMap: TDictionary<string, Integer>;
    public
      constructor Create(const Fields: TStrings);
      destructor Destroy; override;
      function IndexOf(const ColumnName: string): Integer;
      function Contains(const ColumnName: string): Boolean;
    end;

  private
    FSupportedFormats: TContestFileFormats;
    FFileName: string;    // name of current file being read
    FIndex: Integer;      // 0-based index of the current line within the file
    FLine: string;        // copy of current line being processed by ReadFile()
    FStopReading: Boolean;

    {
      Master set of bindings supplied through AddDefaultBinding.

      Active bindings are rebuilt from this list whenever a header
      is encountered. This allows readers to support multiple
      !!Order!! directives and changing column layouts.
    }
    FDefaultBindings: TList<TBindingDefinition<TCallRec>>;
    FBindingDefinitions: TList<TBindingDefinition<TCallRec>>;
    FCompiledBindings: TList<TCompiledBinding<TCallRec>>;

    function GetLineNumber: Integer;
    procedure CompileBindings;
    procedure ValidateFormat(const FormatInfo: TContestFileFormatInfo);
    function FindField(const FieldName: string; RequiredField: Boolean): Integer;

  protected
    FColumnMap: TColumnMap;

    { Infrastructure... }

    function RequireField(const FieldName: string): Integer;
    function OptionalField(const FieldName: string): Integer;

    { Normalize header fields (e.g. remove !!Order!!, for N1MM formats }
    procedure NormalizeHeaderFields(
          const Format: TContestFileFormat;
          const Fields: TStrings);

    procedure BuildColumnMap(const Fields: TStrings);

    procedure ClearBindings;

    procedure AddBinding(
      const ColumnName: string;
      Required: Boolean;
      const Binder: TValueBinder<TCallRec>);

    procedure ExecuteBindings(const Fields: TStrings; Rec: TCallRec);

    property FileName: string read FFileName;
    property LineNumber: Integer read GetLineNumber;
    property Line: string read FLine;

    { Extension Points... }

    function CreateRecord: TCallRec; virtual;

    procedure StopReading;

    {
      Handle non-data lines.

      Return True if the line was consumed and normal row
      processing should not occur.

      Typical uses include:
        - Blank lines
        - Comments
        - Reader directives
        - Debugging commands
    }
    function HandleLine(const Line: string): Boolean; virtual;

    { Return True if Fields represents a section header. }
    function IsHeaderDirective(
      const Format: TContestFileFormat;
      const Fields: TStrings): Boolean; virtual;

    { Configure optional column bindings. }
    procedure ConfigureBindings; virtual;

    {
      Called whenever a new header directive is encountered.

      Base implementation:
        1) Builds FColumnMap from the normalized header fields.
        2) Clears any previous bindings.
        3) Calls ConfigureBindings().
        4) Compiles bindings against the current header.

      Derived classes may override to:
        * Cache contest-specific column indexes.
        * Validate required columns.
        * Configure section-specific behavior.

      For N1MM files this method may be called multiple times as
      additional !!Order!! directives are encountered.

      IMPORTANT:
      Derived implementations MUST call inherited FIRST.

      The base implementation initializes:
        - FColumnMap
        - binding state
        - compiled bindings

      Calling RequireField/OptionalField before inherited is invalid
      and will raise an exception.

      IMPORTANT:
        Override without calling inherited only when intentionally
        replacing the entire header-processing pipeline.

      Example:
        inherited ParseSectionHeader(Format, Fields);

        FCallInx := RequireField('Call');
        FStateInx := OptionalField('State');
        FPowerInx := OptionalField('Power');
    }
    procedure ParseSectionHeader(
      const Format: TContestFileFormat;
      const Fields: TStrings); virtual;

    { Populate Record from Fields. }
    procedure ParseRow(const Fields: TStrings; Rec: TCallRec); virtual;

    { Normalize data record }
    procedure NormalizeRecord(Rec: TCallRec); virtual;

    { Return True if call Record should be emitted. }
    function KeepRecord(const Rec: TCallRec): Boolean; virtual;

  public
    constructor Create(SupportedFormats: TContestFileFormats);
    destructor Destroy; override;

    {
      Registers a binding that will be applied whenever a header
      is encountered.

      Default bindings are intended for simple readers that do not
      derive from TContestFileReader and therefore do not override
      ConfigureBindings.

      When a new header is processed, the active bindings are rebuilt
      from the current set of default bindings.

      Derived readers typically override ConfigureBindings and use
      AddBinding instead.
    }
    procedure AddDefaultBinding(
      const ColumnName: string;
      Required: Boolean;
      const Binder: TValueBinder<TCallRec>);

    { File processing... }

    procedure ReadFile(
      const FileName: string;
      Consumer: TRecordConsumer<TCallRec>);

    procedure ReadFiles(
      const FileNames: array of string;
      Consumer: TRecordConsumer<TCallRec>);

    property SupportedFormats: TContestFileFormats read FSupportedFormats;
  end;

implementation

{ TContestFileReader<TCallRec>.THeaderMap }

constructor TContestFileReader<TCallRec>.TColumnMap.Create(const Fields: TStrings);
var
  i: Integer;
begin
  FMap := TDictionary<String, Integer>.Create;
  for i := 0 to Fields.Count-1 do
    FMap.AddOrSetValue(UpperCase(Fields[i]), i);
end;

destructor TContestFileReader<TCallRec>.TColumnMap.Destroy;
begin
  FMap.Free;
  inherited;
end;

function TContestFileReader<TCallRec>.TColumnMap.IndexOf(const ColumnName: string): Integer;
begin
  if not FMap.TryGetValue(UpperCase(ColumnName), Result) then
    Result := -1;
end;

function TContestFileReader<TCallRec>.TColumnMap.Contains(const ColumnName: string): Boolean;
begin
  Result := FMap.ContainsKey(UpperCase(ColumnName));
end;


{ TContestFileReader<TCallRec> }

constructor TContestFileReader<TCallRec>.Create(
  SupportedFormats: TContestFileFormats);
begin
  inherited Create;

  FSupportedFormats := SupportedFormats;
  FColumnMap := nil;
  FDefaultBindings := TList<TBindingDefinition<TCallRec>>.Create;
  FBindingDefinitions := TList<TBindingDefinition<TCallRec>>.Create;
  FCompiledBindings := TList<TCompiledBinding<TCallRec>>.Create;
end;

destructor TContestFileReader<TCallRec>.Destroy;
begin
  FCompiledBindings.Free;
  FDefaultBindings.Free;
  FBindingDefinitions.Free;
  FColumnMap.Free;

  inherited;
end;

function TContestFileReader<TCallRec>.GetLineNumber: Integer;
begin
  Result := FIndex + 1;
end;


procedure TContestFileReader<TCallRec>.AddDefaultBinding(
  const ColumnName: string;
  Required: Boolean;
  const Binder: TValueBinder<TCallRec>);
var
  B: TBindingDefinition<TCallRec>;
begin
  B.ColumnName := ColumnName;
  B.Required := Required;
  B.Apply := Binder;

  FDefaultBindings.Add(B);
end;


function TContestFileReader<TCallRec>.IsHeaderDirective(
  const Format: TContestFileFormat;
  const Fields: TStrings): Boolean;
begin
  Result := ContestFileFormat.IsFormatHeaderDirective(Format, Fields);
end;


{ Normalize headers by removing '!!Order!!' from N1MM call history files }
procedure TContestFileReader<TCallRec>.NormalizeHeaderFields(
  const Format: TContestFileFormat;
  const Fields: TStrings);
begin
  case Format of
    cffN1MMCsv:
      if (Fields.Count > 0) and SameText(Fields[0], '!!Order!!') then
        Fields.Delete(0);
  end;
end;


procedure TContestFileReader<TCallRec>.BuildColumnMap(const Fields: TStrings);
begin
  if Assigned(FColumnMap) then
    FreeAndNil(FColumnMap);

  FColumnMap := TColumnMap.Create(Fields);
end;


procedure TContestFileReader<TCallRec>.ClearBindings;
begin
  FCompiledBindings.Clear;
  FBindingDefinitions.Clear;
end;

{
  Registers a column binding.

  Example:

    AddBinding('Call', True,
      procedure(const Value: string; Rec: TMyCallRec)
      begin
        Rec.Call := Value;
      end);
}
procedure TContestFileReader<TCallRec>.AddBinding(
  const ColumnName: string;
  Required: Boolean;
  const Binder: TValueBinder<TCallRec>);
var
  B: TBindingDefinition<TCallRec>;
begin
  B.ColumnName := ColumnName;
  B.Required := Required;
  B.Apply := Binder;

  FBindingDefinitions.Add(B);
end;

{
  Builds the active binding set for the current header.

  The default implementation uses bindings previously registered
  through AddDefaultBinding. Derived readers may override and
  populate bindings using AddBinding.
}
procedure TContestFileReader<TCallRec>.ConfigureBindings;
begin
  // Default implementation uses externally supplied bindings.
  FBindingDefinitions.Clear;
  FBindingDefinitions.AddRange(FDefaultBindings);
end;


procedure TContestFileReader<TCallRec>.CompileBindings;
var
  Def: TBindingDefinition<TCallRec>;
  Compiled: TCompiledBinding<TCallRec>;
begin
  FCompiledBindings.Clear;

  for Def in FBindingDefinitions do
  begin
    Compiled.ColumnIndex := FColumnMap.IndexOf(Def.ColumnName);

    if Def.Required and (Compiled.ColumnIndex = -1) then
    begin
      raise Exception.CreateFmt(
        'Missing required field "%s". Line %d, File "%s"',
        [Def.ColumnName, LineNumber, FileName]);
    end;

    Compiled.Apply := Def.Apply;
    FCompiledBindings.Add(Compiled);
  end;
end;

procedure TContestFileReader<TCallRec>.ExecuteBindings(
  const Fields: TStrings;
  Rec: TCallRec);
var
  B: TCompiledBinding<TCallRec>;
begin
  for B in FCompiledBindings do
    B.Apply(GetValue(Fields, B.ColumnIndex), Rec);
end;


procedure TContestFileReader<TCallRec>.ParseSectionHeader(
  const Format: TContestFileFormat;
  const Fields: TStrings);
begin
  // Rebuild column map for the current section.
  BuildColumnMap(Fields);

  // Recompile bindings against the current header.
  ClearBindings;
  ConfigureBindings;
  CompileBindings;
end;


function TContestFileReader<TCallRec>.RequireField(
  const FieldName: string): Integer;
begin
  Result := FindField(FieldName, True);
end;


function TContestFileReader<TCallRec>.OptionalField(
  const FieldName: string): Integer;
begin
  Result := FindField(FieldName, False);
end;

{
  Returns the column index for FieldName in the current section header.

  RequiredField = True
    Missing columns raise an exception.

  RequiredField = False
    Missing columns return -1.

  Used internally by RequireField() and OptionalField().

  Requires ParseSectionHeader() infrastructure to have been initialized.
}
function TContestFileReader<TCallRec>.FindField(
  const FieldName: string;
  RequiredField: Boolean): Integer;
begin
  Assert(Assigned(FColumnMap),
    'FColumnMap not initialized. ' +
    'Did you forget inherited ParseSectionHeader()?');

  Result := FColumnMap.IndexOf(FieldName);

  if RequiredField and (Result = -1) then
    raise Exception.CreateFmt(
      'Invalid call history file: missing required field "%s". Line %d, File "%s"',
      [FieldName, LineNumber, FileName]);
end;

procedure TContestFileReader<TCallRec>.StopReading;
begin
  FStopReading := True;
end;

function TContestFileReader<TCallRec>.HandleLine(const Line: string): Boolean;
begin
  Result := Line.IsEmpty or Line.StartsWith('#');
end;

function TContestFileReader<TCallRec>.CreateRecord: TCallRec;
begin
  Result := TCallRec.Create;
end;

procedure TContestFileReader<TCallRec>.ParseRow(const Fields: TStrings; Rec: TCallRec);
begin
  assert(FCompiledBindings.Count > 0,
    Format('%s has no compiled bindings. ' +
      'Override ParseRow() or call AddBinding() from ConfigureBindings().',
      [ClassName]));

  ExecuteBindings(Fields, Rec);
end;

procedure TContestFileReader<TCallRec>.NormalizeRecord(Rec: TCallRec);
begin
end;

function TContestFileReader<TCallRec>.KeepRecord(const Rec: TCallRec): Boolean;
begin
  Result := True;
end;

{
  Read multiple files in sequence.

  ReadFile() is called for each filename using the same
  callback instance.

  This is useful for merging call history data from
  multiple sources into a single destination.
}
procedure TContestFileReader<TCallRec>.ReadFiles(
  const FileNames: array of string;
  Consumer: TRecordConsumer<TCallRec>);
var
  FileName: string;
begin
  for FileName in FileNames do
    ReadFile(FileName, Consumer);
end;

{
  Read a single call history file.

  For each accepted row:
    1) CreateRecord() creates a new record instance.
    2) ParseRow() populates the record.
    3) NormalizeRecord() fixes up the record.
    3) KeepRecord() determines whether the record is accepted.
    4) Callback(Rec) is invoked.

  Ownership of the record is transferred to the callback.

  If the callback wishes to retain the record, it should store the
  record in an owning container (such as TObjectList).

  If the callback does not retain the record, it is responsible for
  freeing it before returning.

  Example:
    Reader.ReadFile(FileName,
      procedure(Rec: TArrl10mCallRec)
      begin
        CallList.Add(Rec);  // ownership transferred
      end);
}
procedure TContestFileReader<TCallRec>.ReadFile(
  const FileName: string;
  Consumer: TRecordConsumer<TCallRec>);
var
  Lines: TStringList;
  Fields: TStringList;
  FormatInfo: TContestFileFormatInfo;
  Rec: TCallRec;
  i: Integer;
begin
  Lines := TStringList.Create;
  Fields := TStringList.Create;
  try
    FFileName := FileName;
    Lines.LoadFromFile(FileName);

    FormatInfo := DetectFormat(Lines);
    ValidateFormat(FormatInfo);

    FStopReading := False;
    for i := 0 to Lines.Count - 1 do
    begin
      if FStopReading then
        Break;

      FIndex := i;
      FLine := Lines[i].Trim;

      // skip empty or comment lines, handle debug hooks
      if HandleLine(FLine) then
        Continue;

      // parse Line into Fields
      ParseFields(FLine, FormatInfo, Fields);

      if Fields.Count = 0 then
        Continue;

      // schema/header directive
      if IsHeaderDirective(FormatInfo.Format, Fields) then
      begin
        NormalizeHeaderFields(FormatInfo.Format, Fields);

        ParseSectionHeader(FormatInfo.Format, Fields);
        Continue;
      end;

      Rec := CreateRecord;
      try
        // Populate Rec from Fields
        ParseRow(Fields, Rec);

        NormalizeRecord(Rec);

        // Derived contests can filter records as needed
        if not KeepRecord(Rec) then
          Continue;

        // Transfer ownership of Rec to the consumer.
        Consumer(Rec);

        // Ownership transferred.
        Rec := nil;
      finally
        Rec.Free;
      end;
    end;
  finally
    FFileName := '';
    FIndex := -1;
    Fields.Free;
    Lines.Free;
  end;
end;

procedure TContestFileReader<TCallRec>.ValidateFormat(
  const FormatInfo: TContestFileFormatInfo);
begin
  if FormatInfo.Format = cffUnknown then
    raise Exception.CreateFmt(
      'Unknown call history file format: "%s"',
      [FileName]);

  if not (FormatInfo.Format in FSupportedFormats) then
    raise Exception.CreateFmt(
      'File "%s" is in %s format, which is not supported by %s.',
      [FileName, FormatInfo.Description, ClassName]);
end;

end.
