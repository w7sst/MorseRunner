//------------------------------------------------------------------------------
//This Source Code Form is subject to the terms of the Mozilla Public
//License, v. 2.0. If a copy of the MPL was not distributed with this
//file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit ExchFields;

interface

uses
  Classes
  ;

type
  // Exchange Field #1 types
  TExchange1Type = (etRST, etOpName, etFdClass, etSSNrPrecedence);

  // Exchange Field #2 Types
  TExchange2Type = (etSerialNr, etGenericField, etArrlSection, etStateProv,
                    etCqZone, etItuZone, etAge, etPower, etJaPref, etJaCity,
                    etNaQpExch2, etNaQpNonNaExch2, etSSCheckSection);

  {
    Defines the characteristics and behaviors of an exchange field.
    Used to declare various exchange field behaviors. Field Definitions
    are indexed by a contest definition (e.g. ARRL FD uses etFdClass and
    etStateProv). As new contests are added, new field definition
    may be required. When adding a new exchange field definition,
    search for existing code usages to find areas that will require changes.
  }
  TFieldDefinition = record
    C: PChar;     // Caption
    R: PChar;     // Regular Expression
    L: smallint;  // MaxLength
    T: smallint;  // Type
  end;

  PFieldDefinition = ^TFieldDefinition;

const
  // Adding a contest: define contest-specific field types
  // Exchange Field 1 settings/rules
  Exchange1Settings: array[TExchange1Type] of TFieldDefinition = (
    (C: 'RST';   R: '[1-5E][1-9N][1-9N]';     L: 3;   T:Ord(etRST))
   ,(C: 'Name';  R: '[A-Z][A-Z]*';            L: 10;  T:Ord(etOpName))
   ,(C: 'Class'; R: '[1-9][0-9]*[A-F]';       L: 3;   T:Ord(etFdClass))
   // ARRL SS does not parse user-entered Exchange 1 field; Exchange 2 field is used.
   ,(C: '';      R: '([0-9]+|#)? *[QABUMS]';  L: 4;   T:Ord(etSSNrPrecedence))
  );

  // Exchange Field 2 settings/rules
  Exchange2Settings: array[TExchange2Type] of TFieldDefinition = (
    (C: 'Nr.';        R: '([0-9OTN]+)|(#)';                L: 4;  T:Ord(etSerialNr)),
    (C: 'Exch';       R: '[0-9A-Z]*';                      L: 12; T:Ord(etGenericField)),
    (C: 'Section';    R: '([A-Z][A-Z])|([A-Z][A-Z][A-Z])'; L: 3;  T:Ord(etArrlSection)),
    (C: 'State/Prov'; R: '[ABCDFGHIKLMNOPQRSTUVWY][ABCDEFHIJKLMNORSTUVXYZ]';
                                                           L: 6;  T:Ord(etStateProv)),
    (C: 'CQ-Zone';    R: '[0-9OANT]+';                     L: 2;  T:Ord(etCqZone)),
    (C: 'Zone';       R: '[0-9]*';                         L: 4;  T:Ord(etItuZone)),
    (C: 'Age';        R: '[0-9][0-9]';                     L: 2;  T:Ord(etAge)),
    (C: 'Power';      R: '([0-9]*)|(K)|(KW)|([0-9A]*[OTN]*)'; L: 4; T:Ord(etPower)),
    (C: 'Number';     R: '([0-9AOTN]*)([LMHP])';           L: 4; T:Ord(etJaPref)),
    (C: 'Number';     R: '([0-9AOTN]*)([LMHP])';           L: 7; T:Ord(etJaCity))
    // NAQP Contest: NA Stations send name and (state/prov/dxcc);
    //           Non-NA stations send name only
   ,(C: 'State';      R: '([0-9A-Z/]*)';                   L: 6; T:Ord(etNaQpExch2))
   ,(C: 'State';      R: '()|([0-9A-Z/]*)';                L: 6; T:Ord(etNaQpNonNaExch2))
   ,(C: 'Nr Prec CK Sect';
                      R: '[0-9ONT]{1,2} +[A-Z]{2,3}';      L: 32; T:Ord(etSSCheckSection))
  );

implementation

end.
