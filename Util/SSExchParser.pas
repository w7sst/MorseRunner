unit SSExchParser;

interface

uses
  Lexer,
  System.Generics.Collections,    // TObjectList
  System.Classes,                 // TStringList
  PerlRegEx;      // for regular expression support (TPerlRegEx, TPerlRegExList)

type
  TExchTokenType = (
    ttEOS,      // End of String token
    ttDigit1,   // numeric token, 1-digit
    ttDigit2,   // numeric token, 2-digit
    ttDigits,   // numeric token, 3 or more digits
    ttAlpha,    // Alpha characters only token
    ttCallsign, // callsign token
    ttPrec,     // Precedence token (added by TSSLexer)
    ttSect);    // Section token (added by TSSLexer)

  TSSExchToken = class
    TokenType: TExchTokenType;
    Value: string;
    Pos: integer;

    constructor Create; overload;
    constructor Create(const token: TExchToken); overload;
    constructor Create(const token: TSSExchToken); overload;

    procedure Clear;
    procedure Init(const token: TExchToken); overload;
    procedure Init(const token: TSSExchToken); overload;
    function IsValid: Boolean;
  end;

  TSSLexer = class(TLexer)
  private
    Sections: TStringList;
  public
    constructor Create;
    destructor Destroy; override;

    function NextToken(var AToken: TExchToken): Boolean; override;
    function IsValidCall(const Call: string): Boolean;
    function IsValidSection(const Section: string): Boolean;
  end;

  TMyExchParser = class
  private
    Reg : TPerlRegEx;
    Lexer: TLexer;
  protected
    FErrorStr: String;
  public
    constructor Create;
    destructor Destroy; override;

    function ParseMyExch(const AExchange: string): boolean;
    function GroupByName(const name: string): string;

  public
    property ErrorStr: string read FErrorStr;
  end;

  TSSExchParser = class
  private
  protected
    IsValidExchange: Boolean;
    Lexer: TSSLexer;
    PreviousCall: String;                   // copy of user-entered call (Edit1)
    Tokens: TObjectList<TSSExchToken>;
    TwoDigitList: TList<TSSExchToken>;      // insert each new 2digit token into this list (mru at 0)
    CheckTokenstack: TStack<TSSExchToken>;  // each new check token is pushed
    UnboundNRs: TStack<TSSExchToken>;       // holds <NR>'s not yet bound to <Precedence>
    NRToken: TSSExchToken;
    PrecedenceToken: TSSExchToken;
    CheckToken: TSSExchToken;
    SectionToken: TSSExchToken;
    FExchError: String;               // most recent exchange parsing error
    procedure Reset;
    function GetExchSummary: String;

  public
    NR: Integer;
    Precedence: String;
    Check: String;
    Section: String;
    Call: String;
    property ExchError: String read FExchError;
    property ExchSummary: String read GetExchSummary;

    constructor Create;
    destructor Destroy; override;

    procedure OnWipeBoxes;
    function ValidateEnteredExchange(const ACall, AExch1, AExch2: string;
      out AExchError: String) : boolean;
  end;

{$ifdef DEBUG}
  var
    // helpful for enabling breakpoints in the debugger while running UnitTests
    DbgBreak: Boolean = False;
{$endif}

  const
    SSLexerRules: array[0..4] of TTokenRuleDef = (
      // - https://en.wikipedia.org/wiki/Amateur_radio_call_signs
      // - the leading positive-lookbehind ('(<=\b)') makes sure there is
      //   whitespace before the callsign.
      //   (See: https://www.regular-expressions.info/lookaround.html)
      (R: '(?<=\b)([A-Z\d]{2,}\/)?([A-Z]{1,2}|\d[A-Z]|[A-Z]\d|\d[A-Z]{2})([0-9])([A-Z\d]*[A-Z])(\/[A-Z\d]+)?(\/[A-Z\d]+)?\b';
                                  T: Ord(ttCallsign)),
      (R: '\d\d\d+';              T: Ord(ttDigits)),
      (R: '\d\d';                 T: Ord(ttDigit2)),
      (R: '\d';                   T: Ord(ttDigit1)),
      (R: '[A-Z]+';               T: Ord(ttAlpha))
    );

function ToStr(const val: TExchTokenType): String; overload;

implementation

uses
  ArrlSections,   // for ARRL/RAC Sections
  TypInfo,        // for typeInfo
  StrUtils,
  System.SysUtils;

const
  MyExchRegExpr: string = '^ *(?P<exch1>(?P<nr>[0-9]+|#)? *(?P<prec>[QABUMS])) +'
                        + '(?P<chk>[0-9]{2}) *(?P<sect>[A-Z]+) *$';

function ToStr(const val: TExchTokenType): String; overload;
begin
  Result := GetEnumName(typeInfo(TExchTokenType), Ord(val));
end;


constructor TSSExchToken.Create;
begin
  Clear;
end;

constructor TSSExchToken.Create(const token: TExchToken);
begin
  Init(token);
end;

constructor TSSExchToken.Create(const token: TSSExchToken);
begin
  TokenType := token.TokenType;
  Value := token.Value;
  Pos := token.Pos;
end;

procedure TSSExchToken.Clear;
begin
  TokenType := TExchTokenType(-1);
  Value := '';
  Pos := -1;
  assert(not IsValid);
end;

procedure TSSExchToken.Init(const token: TExchToken);
begin
  TokenType := TExchTokenType(token.TokenType);
  Value := token.Value;
  Pos := token.Pos;
end;

procedure TSSExchToken.Init(const token: TSSExchToken);
begin
  TokenType := token.TokenType;
  Value := token.Value;
  Pos := token.Pos;
end;


function TSSExchToken.IsValid: Boolean;
begin
  Result := TokenType <> TExchTokenType(-1);
end;

constructor TSSLexer.Create;
var
  I: integer;
begin
  inherited Create(SSLexerRules, True);
  Sections := TStringList.Create(False);

  Sections.Capacity := High(SectionsTbl) - Low(SectionsTbl);
  for I := Low(SectionsTbl) to High(SectionsTbl) do
    Sections.Append(SectionsTbl[I]);
  Sections.Sort;
end;

destructor TSSLexer.Destroy;
begin
  FreeAndNil(Sections);
  inherited Destroy;
end;

function TSSLexer.NextToken(var AToken: TExchToken): Boolean;
var
  Index: Integer;
begin
  Result := inherited NextToken(AToken);
  if not Result then
    Exit;

  case TExchTokenType(AToken.TokenType) of
  ttAlpha:
    if (AToken.Value.Length = 1) and
       (System.Pos(AToken.Value, 'QABUMS') > 0) then
      AToken.TokenType := Ord(ttPrec)
    else if Sections.Find(AToken.Value, Index) then
      AToken.TokenType := Ord(ttSect);

  ttDigit1:
    // treat '0' as a possible 2-digit <Chk> value (convert '0' to '00')
    if AToken.Value.Equals('0') then
      begin
        AToken.TokenType := Ord(ttDigit2);
        AToken.Value := '00';
      end;
  end;
end;


function TSSLexer.IsValidCall(const Call: string): Boolean;
var
  token: TExchToken;
begin
  Input(Call);
  Result := NextToken(token) and (token.TokenType = Integer(ttCallsign));
end;


function TSSLexer.IsValidSection(const Section: string): Boolean;
var
  Index: Integer;
begin
  Result := Sections.Find(Section, Index);
end;


constructor TMyExchParser.Create;
begin
  Lexer := TSSLexer.Create;
  Reg := TPerlRegEx.Create;
  Reg.RegEx := UTF8Encode(MyExchRegExpr);
  Reg.Compile;
  Reg.Study;
end;


destructor TMyExchParser.Destroy;
begin
  FreeAndNil(Reg);
  FreeAndNil(Lexer);
end;


function TMyExchParser.ParseMyExch(const AExchange: string): boolean;
const
  Expected: string = '''[#|123] <precedence> <check> <section>'' (e.g. A 72 OR)';
begin
  assert(Reg.Compiled);

  Reg.Subject := UTF8Encode(AExchange);
  Result := Reg.Match;

  FErrorStr := '';
  if not Result then
      FErrorStr := format('invalid exchange ''%s''', [AExchange]);
end;


function TMyExchParser.GroupByName(const name: string): string;
begin
  var Index: Integer := Reg.NamedGroup(UTF8String(name));
  assert(Index >= 0);
  Result := String(Reg.Groups[Index]);
end;


{ TSSExchParser }

constructor TSSExchParser.Create;
begin
  Lexer := TSSLexer.Create;
  Tokens := TObjectList<TSSExchToken>.Create(True);
  TwoDigitList:= TList<TSSExchToken>.Create;
  CheckTokenstack := TStack<TSSExchToken>.Create;
  UnboundNRs := TStack<TSSExchToken>.Create;
  PreviousCall := '';
  NRToken := nil;
  PrecedenceToken := nil;
  CheckToken := nil;
  SectionToken := nil;
end;

destructor TSSExchParser.Destroy;
begin
  Reset;
  TwoDigitList.Free;
  CheckTokenstack.Free;
  UnboundNRs.Free;
  Tokens.Free;
  FreeAndNil(Lexer);
end;

procedure TSSExchParser.Reset;
begin
  NRToken := nil;
  PrecedenceToken := nil;
  CheckToken := nil;
  SectionToken := nil;

  Tokens.Clear;
  TwoDigitList.Clear;
  CheckTokenstack.Clear;
  UnboundNRs.Clear;

  NR := 0;
  Precedence := '';
  Check := '';
  Section := '';
  Call := '';

  IsValidExchange := False;
end;


{
  Exchange summary shows parsed result; displayed as an updated Caption.
  Example: '192A W7SST 72 OR'
}
function TSSExchParser.GetExchSummary: String;
begin
  if Assigned(NRToken) or
     Assigned(CheckToken) or
     Assigned(PrecedenceToken) or
     Assigned(SectionToken) or
     not Call.IsEmpty then
    Result := format('%d%s %s %s %s', [NR, Precedence,
      IfThen(Call.IsEmpty, PreviousCall, Call), Check, Section])
  else
    Result := '';
end;


procedure TSSExchParser.OnWipeBoxes;
begin
  Reset;
end;


function TSSExchParser.ValidateEnteredExchange(const ACall, AExch1, AExch2: string;
  out AExchError: String) : boolean;
var
  token: TSSExchToken;
  NrIsBound: Boolean;   // 1, 3, or 4-digit <NR> has been entered,
                        // or bound with <Precedence> or implied with <Section>
begin
  // optimization - return if user-entered exchange has not changed
  if (ACall = PreviousCall) and
{$ifdef DEBUG}
    not DbgBreak and
{$endif}
    (AExch2 = Lexer.Buf) then
    begin
      AExchError := FExchError;
      Result := IsValidExchange;
      Exit;
    end;

  Self.Reset;
  AExchError := '';
  NrIsBound := False;

  try
    Lexer.Input(AExch2);
    PreviousCall := ACall;

    // Pass 1 -- build tokens array; grab callsign
    begin
      var token0: TExchToken;
      while Lexer.NextToken(token0) do begin
        case TExchTokenType(token0.TokenType) of
          ttCallsign:
            Call := token0.Value;
          else
            Tokens.Add(TSSExchToken.Create(token0));
        end;
      end;
    end;

    // Pass 2 -- process each token
    var SkipNextToken: Boolean := False;
    var I: Integer;
    for I := 0 to Tokens.Count-1 do begin
      if SkipNextToken then begin
        SkipNextToken := False;
        Continue;
      end;

      token := Tokens[I];
      case token.TokenType of
      ttDigit1, ttDigits:             // one digit or three or more digits
        begin
          if token.Value.ToInteger > 10000 then
            token.Value := '10000';

          // is next token a possible Section value (length = 2 or 3)?
          if ((I+1) < Tokens.Count) and
            (Tokens[I+1].TokenType in [ttSect, ttAlpha]) and
            (Tokens[I+1].Value.Length in [2,3]) then
            begin
              // Verify current token contains a valid Check value (00..99)
              if token.Value.ToInteger < 100 then
                begin
                  CheckToken := token;
                  CheckTokenstack.Clear;
                  TwoDigitList.Clear;
                  NrIsBound := True;
                  UnboundNRs.Push(token);

                  if Tokens[I+1].TokenType = ttSect then
                    SectionToken := Tokens[I+1];
                end;

              SkipNextToken := True;
            end
          else // otherwise, treat this token as a serial NR
            begin
              NrToken := token;
              NrIsBound := True;
              UnboundNRs.Push(token);

              // Is next token a Precedence value?
              if ((I+1) < Tokens.Count) and
                (Tokens[I+1].TokenType in [ttPrec, ttAlpha]) and
                (Tokens[I+1].Value.Length = 1) then
                begin
                  if (Tokens[I+1].TokenType = ttPrec) or
                     (System.Pos(Tokens[I+1].Value, 'QABUMS') > 0) then
                    PrecedenceToken := Tokens[I+1];

                  SkipNextToken := True;
                end
            end;
        end;

      ttDigit2:   // two digits, 1st is Nr, 2nd is Chk
        begin
          TwoDigitList.Add(token);

          // is next token a possible Precedence value (length = 1)
          if ((I+1) < Tokens.Count) and
            (Tokens[I+1].TokenType in [ttPrec, ttAlpha]) and
            (Tokens[I+1].Value.Length = 1) then
              begin
                NRToken := token;
                TwoDigitList.Clear;
                CheckTokenstack.Clear;
                NrIsBound := True;

                if (Tokens[I+1].TokenType = ttPrec) or
                   (System.Pos(Tokens[I+1].Value, 'QABUMS') > 0) then
                  begin
                    PrecedenceToken := Tokens[I+1];
                    SkipNextToken := True;
                  end;
              end

          // Is next token a possible Section token (ttSect or ttAlpha with length [2,3]
          else if ((I+1) < Tokens.Count) and
            (Tokens[I+1].TokenType in [ttSect, ttAlpha]) and
            (Tokens[I+1].Value.Length in [2,3]) then
            begin
              if not NrIsBound and (CheckTokenstack.Count > 0) then
                NRToken := CheckToken;
              CheckToken := token;
              CheckTokenstack.Clear;

              if Tokens[I+1].TokenType = ttSect then
                SectionToken := Tokens[I+1];

              SkipNextToken := True;
            end

          // if Check/Section are bound, update Check
          else if Assigned(CheckToken) and Assigned(SectionToken) then // Check/Section is bound
            begin
              if not NrIsBound and (CheckTokenstack.Count > 0) then
                NRToken := CheckToken;
              CheckToken := token;
              CheckTokenstack.Push(CheckToken);
            end
          // otherwise update Chk and optionally NR
          else
            begin
              if Assigned(CheckToken) and not NrIsBound and
                (CheckTokenstack.Count > 0) then
                  NRToken := CheckToken;
              CheckToken := token;
              CheckTokenstack.Push(CheckToken);
            end;
        end;

      ttAlpha:  // other character strings, not valid Precedence nor Section
        begin
{$ifdef DEBUG}
          if token.Value = 'XYZZY' then
            begin
              FExchError := 'A MAZE OF TWISTY LITTLE PASSAGES, ALL ALIKE';
              AExchError := FExchError;
              IsValidExchange := False;
              Result := IsValidExchange;
              Exit;
            end;
{$endif}
          if token.Value.Length = 2 then
            begin
              if TwoDigitList.Count > 0 then
                begin
{$ifdef DEBUG}
                  assert(Assigned(NRToken));
                  assert(CheckToken = TwoDigitList.Last);
{$endif}
                  CheckToken := TwoDigitList.Last;
                  CheckTokenstack.Push(CheckToken);
                end
              else if UnboundNRs.Count > 0 then
                begin
                  CheckToken := UnboundNRs.Pop;
                  CheckTokenstack.Push(CheckToken);
                  if UnboundNRs.Count > 0 then
                     NRToken := UnboundNRs.Peek;
                end;
            end;
        end;

      ttPrec:
        begin
          PrecedenceToken := token;
          if Assigned(NRToken) then
            NRIsBound := True;
        end;

      ttSect:
          SectionToken := token;
      end;
    end;

    if Assigned(NRToken) then NR := StrToIntDef(NRToken.Value, 0);
    if Assigned(PrecedenceToken) then Precedence := PrecedenceToken.Value;
    if Assigned(CheckToken) then Check := format('%.02d', [StrToIntDef(CheckToken.Value, 0)]);
    if Assigned(SectionToken) then Section := SectionToken.Value;

    if not Assigned(NRToken) then
      FExchError := 'Missing/Invalid Serial Number'
    else if not Assigned(PrecedenceToken) then
      FExchError := 'Missing/Invalid Precedence'
    else if not Assigned(CheckToken) then
      FExchError := 'Missing/Invalid Check'
    else if not Assigned(SectionToken) then
      FExchError := 'Missing/Invalid Section'
    else
      FExchError := '';

    IsValidExchange := FExchError.IsEmpty;

  except
    on E: TLexer.ELexerError do begin
      FExchError := E.Message;
      IsValidExchange := False;
    end;
  end;

  AExchError := FExchError;
  Result := IsValidExchange;
end;


end.
