program MorseRunner;

uses
  Forms,
  Main in 'Main.pas' {MainForm},
  Contest in 'Contest.pas',
  RndFunc in 'RndFunc.pas',
  Ini in 'Ini.pas',
  Station in 'Station.pas',
  StnColl in 'StnColl.pas',
  DxStn in 'DxStn.pas',
  MyStn in 'MyStn.pas',
  CallLst in 'CallLst.pas',
  QrmStn in 'QrmStn.pas',
  Log in 'Log.pas',
  Qsb in 'Qsb.pas',
  DxOper in 'DxOper.pas',
  QrnStn in 'QrnStn.pas',
  ScoreDlg in 'ScoreDlg.pas' {ScoreDialog};

{$R *.RES}

begin
  Application.Initialize;
  Application.Title := 'Morse Runner';
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TScoreDialog, ScoreDialog);
  Application.Run;
end.

