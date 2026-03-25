unit Flags;

interface

type
  TFlags16 = record
  public
    FValue: UInt16;
  public
    // Constructor to initialize the flag value
    constructor Create(Value: UInt16); overload;

    // Inline methods for flag manipulation
    procedure SetFlag(const Flag: UInt16); overload; inline;
    procedure SetFlag(const Flag: UInt16; const Val: Boolean); overload;
    procedure ClearFlag(const Flag: UInt16); inline;
    procedure ToggleFlag(const Flag: UInt16); inline;
    function TestFlag(const Flag: UInt16): Boolean; inline;

    // Accessor to get and set the underlying value
    function GetValue: UInt16; inline;
    procedure SetValue(const Value: UInt16); inline;
  end;

  const Flags16Init: TFlags16 = (FValue: 0);

implementation

{ TFlags16 }

constructor TFlags16.Create(Value: UInt16);
begin
  FValue := Value;
end;

procedure TFlags16.SetFlag(const Flag: UInt16);
begin
  FValue := FValue or Flag;  // Set the flag using bitwise OR
end;

procedure TFlags16.SetFlag(const Flag: UInt16; const Val: Boolean);
begin
  if Val then
    SetFlag(Flag)
  else
    ClearFlag(Flag);
end;

procedure TFlags16.ClearFlag(const Flag: UInt16);
begin
  FValue := FValue and (not Flag);  // Clear the flag using bitwise AND-NOT
end;

procedure TFlags16.ToggleFlag(const Flag: UInt16);
begin
  FValue := FValue xor Flag;  // Toggle the flag using bitwise XOR
end;

function TFlags16.TestFlag(const Flag: UInt16): Boolean;
begin
  Result := (FValue and Flag) = Flag;  // Test if the flag is set
end;

function TFlags16.GetValue: UInt16;
begin
  Result := FValue;  // Return the raw value of the flags
end;

procedure TFlags16.SetValue(const Value: UInt16);
begin
  FValue := Value;  // Set the raw value of the flags
end;

end.

