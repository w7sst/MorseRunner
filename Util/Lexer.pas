unit Lexer;

interface

uses
  Generics.Defaults,
  Generics.Collections,   // for TList<>
  SysUtils,               // Exception
  PerlRegEx;      // for regular expression support (TPerlRegEx, TPerlRegExList)

type
  {
    Lexer rules are defined as a pair, consisting of a RegEx string and a
    corresponding type. An array of TTokenRuleDef records will be passed
    into TLexer.Create.

    Example:
      LexerRules: array[0..2] of TTokenRuleDef = (
        (R: '[A-Z]+';               T: Ord(ttAlpha)),
        (R: '\d+';                  T: Ord(ttNumeric)),
        (R: '+';                    T: Ord(ttPlus)),
        (R: '-';                    T: ORd(ttMinus))
      );

    Perl-Compatible Regular Expressions ...
    - https://pcre.org/original/doc/html/index.html
    - https://pcre.org/original/doc/html/pcrepattern.html#SEC27
  }
  TTokenRuleDef = record
    R: PCREString;
    T: Integer;
  end;

  {
    Returned by TLexer.NextToken(out tok: TExchToken).
  }
  TExchToken = record
    TokenType: Integer;
    Value: string;
    Pos: integer;

    procedure Init(AType: Integer; aValue: string; aPos: integer);
  end;

  {
    A simple regex-based lexer/tokenizer.

    The basic idea is to search a set of rules (regular expressions) looking
    for a match, where each expression represents a different token. Whitespace
    is handled in one of two ways: it can be automatically skipped by the Lexer,
    or user can provide additional rules to manage whitespace.

    The initial application of this class will be to support the ARRL
    Sweepstakes Contest.

    Inspiration and design is based on this article:
      https://eli.thegreenplace.net/2013/06/25/regex-based-lexical-analysis-in-python-and-javascript
  }
  TLexer = class
  private
  protected
    type
      {
        Hold a single token rule for the Lexer, including its type and
        corresponding regular expression. A set of rules are passed to
        the Lexer as an array of TTokenRuleDef records.
      }
      TTokenRule = packed record
        tokenType: Integer;
        regex: TPerlRegEx;

        constructor init(AType: Integer; ARegEx: TPerlRegEx);
      end;

    var
      SkipWhitespace: Boolean;
      Pos: Integer;
      Buf: string;
      ReSkipWhitespace: TPerlRegEx;
      Rules: TList<TTokenRule>;
  public
    type
      ELexerError = class(SysUtils.Exception);
      EInvalidData = class(ELexerError);

    constructor Create(const ARules: array of TTokenRuleDef;
      ASkipWhitespace: Boolean = True);
    destructor Destroy; override;

    procedure Input(const ABuf: string);
    function NextToken(var AToken: TExchToken): Boolean; virtual;
  end;

implementation

uses
  System.Classes;

constructor TLexer.TTokenRule.init(AType: Integer; ARegEx: TPerlRegEx);
begin
  Self.tokenType := AType;
  Self.regex := ARegEx;
end;

procedure TExchToken.Init(AType: Integer; aValue: string; aPos: integer);
begin
  Self.TokenType := AType;
  Self.Value := aValue;
  Self.Pos := aPos;
end;

{
  Create a Lexer...
  ARules
      An array of TTokenRuleDef's. Each rule contains a regex
      and a Token type value. `Regex` is regex is the regular expression used
      to recognize the token and `type` is the type of the token to return
      when it's recognized.

  ASkipWhitespace
      If True, whitespace will be skipped and not reported by the lexer.
      Otherwise, you have to specify your rules for whitespace, or it will be
      flagged as an error.
}
constructor TLexer.Create(const ARules: array of TTokenRuleDef;
  ASkipWhitespace: Boolean = True);
var
  Def: TTokenRuleDef;
  Rule: TTokenRule;
  Reg: TPerlRegEx;
begin
  ReSkipWhitespace := TPerlRegEx.Create;
  Rules := TList<TTokenRule>.Create;

  SkipWhitespace := ASkipWhitespace;
  ReSkipWhitespace.Options := [preAnchored];
  ReSkipWhitespace.RegEx := '\s*';  //'\s+';
  ReSkipWhitespace.Compile;

  for Def in ARules do
    begin
      Reg := TPerlRegEx.Create;
      Reg.Options := [preAnchored];
      Reg.RegEx := Def.R;
      Rule.regex := Reg;
      Rule.tokenType := Def.T;
      Rules.Add(Rule);
      Reg := nil;
    end;
end;


destructor TLexer.Destroy;
var
  Rule: TTokenRule;
begin
  for Rule in Rules do
    Rule.regex.Free;
  FreeAndNil(Rules);
  FreeAndNil(ReSkipWhitespace);
end;


procedure TLexer.Input(const ABuf: string);
var
  Rule: TTokenRule;
begin
  Buf := ABuf;
  Pos := 1;
  ReSkipWhitespace.Subject := Self.Buf;
  ReSkipWhitespace.Start := 1;
  ReSkipWhitespace.Stop := Self.Buf.Length;
  for Rule in Rules do
    begin
      Rule.regex.Subject := Self.Buf;
      Rule.regex.Start := 1;
      Rule.regex.Stop := Self.Buf.Length;
    end;
end;


function TLexer.NextToken(var AToken: TExchToken): Boolean;
var
  Rule: TTokenRule;
  Matched: boolean;
begin
  Result := self.Pos <= buf.length;
  if not Result then
    begin
      AToken.Init(-1, self.Buf, self.Pos);
      Exit;
    end;

  if SkipWhitespace then
    begin
      assert(ReSkipWhitespace.Subject = self.Buf);
      assert(ReSkipWhitespace.Stop = Self.Buf.Length);
      ReSkipWhitespace.Start := self.Pos;
      if ReSkipWhitespace.MatchAgain then
        self.Pos := ReSkipWhitespace.Start;

      Result := self.Pos <= buf.length;
      if not Result then
        begin
          AToken.Init(-1, self.Buf, self.Pos);
          Exit;
        end;
    end;

  for Rule in Rules do
    begin
      assert(Rule.regex.Subject = Self.Buf);
      assert(Rule.regex.Stop = Self.Buf.Length);
      Rule.regex.Start := Self.Pos;
      Result := Rule.regex.MatchAgain;
      if Result then
        begin
          AToken.Init(Rule.tokenType, Rule.regex.MatchedText, Self.Pos);
          Self.Pos := Rule.regex.Start;
          Exit;
        end;
    end;

  // if we're here, no rule matched
  raise EInvalidData.CreateFmt('Invalid data (%s) at position %d',
    [Self.Buf.Substring(Self.Pos-1,1), Self.Pos]);
end;


end.
