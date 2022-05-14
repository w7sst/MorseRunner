{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit MorseRunnerVcl;

{$warn 5023 off : no warning about unused units}
interface

uses
  BaseComp, Crc32, Mixers, MorseKey, MorseTbl, MovAvg, PermHint, QuickAvg, 
  SndCustm, SndOut, SndTypes, VolmSldr, VolumCtl, WavFile, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('SndOut', @SndOut.Register);
  RegisterUnit('VolmSldr', @VolmSldr.Register);
  RegisterUnit('WavFile', @WavFile.Register);
end;

initialization
  RegisterPackage('MorseRunnerVcl', @Register);
end.
