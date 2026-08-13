unit Test.ContestFileFormat;

interface

uses
  DUnitX.TestFramework,
  System.Classes;

type
  [TestFixture]
  TContestFileFormatTests = class
  public

    [Test]
    procedure Detect_N1MM_Format;

    [Test]
    procedure Detect_ARRL_Format;

    [Test]
    procedure DetectFormat_Skips_BlankLines;

    [Test]
    procedure DetectFormat_Unknown;

    [Test]
    procedure Parse_CSV;

    [Test]
    procedure Parse_TSV;

    [Test]
    procedure ParseFields_Clears_Previous_Contents;

    [Test]
    procedure GetValue_ValidIndex;

    [Test]
    procedure GetValue_IndexPastEnd_ReturnsEmptyString;

    [Test]
    procedure GetValue_NegativeIndex_ReturnsEmptyString;

    [Test]
    procedure GetValue_TrimsWhitespace;

    [Test]
    procedure GetValue_EmptyField;

    [Test]
    procedure N1MM_Order_Is_Header_Directive;

    [Test]
    procedure Arrl_CabrilloId_Is_Header_Directive;

    [Test]
    procedure Data_Row_Is_Not_Header_Directive;

    [Test]
    procedure Empty_Fields_Is_Not_Header_Directive;

    [Test]
    procedure Whitespace_Field_Is_Not_Header_Directive;
  end;

implementation

uses
  ContestFileFormat;

procedure TContestFileFormatTests.Detect_N1MM_Format;
var
  Lines: TStringList;
  Info: TContestFileFormatInfo;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('# comment');
    Lines.Add('!!Order!!,Call,State');

    Info := DetectFormat(Lines);

    Assert.AreEqual(cffN1MMCsv, Info.Format);
    Assert.AreEqual('N1MM Call HIstory', Info.Description);
    Assert.AreEqual(',', Info.Delimiter);
  finally
    Lines.Free;
  end;
end;

procedure TContestFileFormatTests.Detect_ARRL_Format;
var
  Lines: TStringList;
  Info: TContestFileFormatInfo;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('# comment');
    Lines.Add('cabrillo_id'#9'year'#9'call');

    Info := DetectFormat(Lines);

    Assert.AreEqual(cffArrlTsv, Info.Format);
    Assert.AreEqual('ARRL Score Summary', Info.Description);
    Assert.AreEqual(#9, Info.Delimiter);
  finally
    Lines.Free;
  end;
end;

procedure TContestFileFormatTests.DetectFormat_Skips_BlankLines;
var
  Lines: TStringList;
  Info: TContestFileFormatInfo;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('');
    Lines.Add('   ');
    Lines.Add(#9#9);
    Lines.Add('!!Order!!,Call,State');

    Info := DetectFormat(Lines);

    Assert.AreEqual(cffN1MMCsv, Info.Format);
  finally
    Lines.Free;
  end;
end;

procedure TContestFileFormatTests.DetectFormat_Unknown;
var
  Lines: TStringList;
  Info: TContestFileFormatInfo;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('AA0A,MO');

    Info := DetectFormat(Lines);

    Assert.AreEqual(cffUnknown, Info.Format);
    Assert.AreEqual('an Unknown', Info.Description);
  finally
    Lines.Free;
  end;
end;

procedure TContestFileFormatTests.Parse_CSV;
var
  Fields: TStringList;
  FormatInfo: TContestFileFormatInfo;
begin
  Fields := TStringList.Create;
  try
    FormatInfo.Format := cffN1MMCsv;
    FormatInfo.Description := 'N1MM Call History';
    FormatInfo.Delimiter := ',';
    FormatInfo.SupportsDynamicHeaders := True;

    ParseFields(
      'AA0A,MO,',
      FormatInfo,
      Fields);

    Assert.AreEqual(3, Fields.Count);
    Assert.AreEqual('AA0A', Fields[0]);
    Assert.AreEqual('MO', Fields[1]);
    Assert.AreEqual('', Fields[2]);
  finally
    Fields.Free;
  end;
end;

procedure TContestFileFormatTests.Parse_TSV;
var
  Fields: TStringList;
  FormatInfo: TContestFileFormatInfo;
begin
  Fields := TStringList.Create;
  try
    FormatInfo.Format := cffArrlTsv;
    FormatInfo.Description := 'ARRL Score Summary';
    FormatInfo.Delimiter := #9;
    FormatInfo.SupportsDynamicHeaders := False;

    ParseFields(
      'ARRL-10'#9'2025'#9'2E0CVN',
      FormatInfo,
      Fields);

    Assert.AreEqual(3, Fields.Count);
    Assert.AreEqual('ARRL-10', Fields[0]);
    Assert.AreEqual('2025', Fields[1]);
    Assert.AreEqual('2E0CVN', Fields[2]);

    // add a trailing <tab>. should add an extra empty field value.
    ParseFields(
      'ARRL-10'#9'2025'#9'2E0CVN'#9,
      FormatInfo,
      Fields);

    Assert.AreEqual(4, Fields.Count);
    Assert.AreEqual('ARRL-10', Fields[0]);
    Assert.AreEqual('2025', Fields[1]);
    Assert.AreEqual('2E0CVN', Fields[2]);
    Assert.AreEqual('', Fields[3]);

  finally
    Fields.Free;
  end;
end;

procedure TContestFileFormatTests.ParseFields_Clears_Previous_Contents;
var
  Fields: TStringList;
  FormatInfo: TContestFileFormatInfo;
begin
  Fields := TStringList.Create;
  try
    FormatInfo.Format := cffN1MMCsv;
    FormatInfo.Description := 'N1MM Call History';
    FormatInfo.Delimiter := ',';

    ParseFields(
      'AA0A,MO,Club',
      FormatInfo,
      Fields);

    Assert.AreEqual(3, Fields.Count);

    ParseFields(
      'AA0A',
      FormatInfo,
      Fields);

    Assert.AreEqual(1, Fields.Count);
    Assert.AreEqual('AA0A', Fields[0]);
  finally
    Fields.Free;
  end;
end;

procedure TContestFileFormatTests.GetValue_ValidIndex;
var
  Fields: TStringList;
begin
  Fields := TStringList.Create;
  try
    Fields.Add('AA0A');
    Fields.Add('MO');

    Assert.AreEqual('AA0A', GetValue(Fields, 0));
    Assert.AreEqual('MO', GetValue(Fields, 1));
  finally
    Fields.Free;
  end;
end;

procedure TContestFileFormatTests.GetValue_IndexPastEnd_ReturnsEmptyString;
var
  Fields: TStringList;
begin
  Fields := TStringList.Create;
  try
    Fields.Add('AA0A');

    Assert.AreEqual('', GetValue(Fields, 1));
  finally
    Fields.Free;
  end;
end;

procedure TContestFileFormatTests.GetValue_NegativeIndex_ReturnsEmptyString;
var
  Fields: TStringList;
begin
  Fields := TStringList.Create;
  try
    Fields.Add('AA0A');

    Assert.AreEqual('', GetValue(Fields, -1));
  finally
    Fields.Free;
  end;
end;

procedure TContestFileFormatTests.GetValue_TrimsWhitespace;
var
  Fields: TStringList;
begin
  Fields := TStringList.Create;
  try
    Fields.Add('  AA0A  ');

    Assert.AreEqual('AA0A', GetValue(Fields, 0));
  finally
    Fields.Free;
  end;
end;

procedure TContestFileFormatTests.GetValue_EmptyField;
var
  Fields: TStringList;
begin
  Fields := TStringList.Create;
  try
    Fields.Add('AA0A');
    Fields.Add('');

    Assert.AreEqual('', GetValue(Fields, 1));
  finally
    Fields.Free;
  end;
end;

procedure TContestFileFormatTests.N1MM_Order_Is_Header_Directive;
var
  Fields: TStringList;
begin
  Fields := TStringList.Create;
  try
    Fields.Add('!!Order!!');

    Assert.IsTrue(
      IsFormatHeaderDirective(
        cffN1MMCsv,
        Fields));
  finally
    Fields.Free;
  end;
end;

procedure TContestFileFormatTests.Arrl_CabrilloId_Is_Header_Directive;
var
  Fields: TStringList;
begin
  Fields := TStringList.Create;
  try
    Fields.Add('cabrillo_id');
    Fields.Add('call');

    Assert.IsTrue(
      IsFormatHeaderDirective(
        cffArrlTsv,
        Fields));
  finally
    Fields.Free;
  end;
end;

procedure TContestFileFormatTests.Data_Row_Is_Not_Header_Directive;
var
  Fields: TStringList;
begin
  Fields := TStringList.Create;
  try
    Fields.Add('AA0A');

    Assert.IsFalse(
      IsFormatHeaderDirective(
        cffN1MMCsv,
        Fields));
  finally
    Fields.Free;
  end;
end;

procedure TContestFileFormatTests.Empty_Fields_Is_Not_Header_Directive;
var
  Fields: TStringList;
begin
  Fields := TStringList.Create;
  try
    Assert.IsFalse(
      IsFormatHeaderDirective(
        cffN1MMCsv,
        Fields));

    Assert.IsFalse(
      IsFormatHeaderDirective(
        cffArrlTsv,
        Fields));
  finally
    Fields.Free;
  end;
end;

procedure TContestFileFormatTests.Whitespace_Field_Is_Not_Header_Directive;
var
  Fields: TStringList;
begin
  Fields := TStringList.Create;
  try
    Fields.Add('   ');

    Assert.IsFalse(
      IsFormatHeaderDirective(
        cffN1MMCsv,
        Fields));

    Assert.IsFalse(
      IsFormatHeaderDirective(
        cffArrlTsv,
        Fields));
  finally
    Fields.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TContestFileFormatTests);

end.
