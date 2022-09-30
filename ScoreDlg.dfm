object ScoreDialog: TScoreDialog
  Left = 212
  Top = 107
  Hint = 'Post your score to Server.'
  BorderStyle = bsDialog
  Caption = 'The contest is over'
  ClientHeight = 163
  ClientWidth = 394
  Color = clBtnFace
  Font.Charset = ANSI_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  OnCreate = FormCreate
  DesignSize = (
    394
    163)
  PixelsPerInch = 96
  TextHeight = 15
  object Label1: TLabel
    Left = 14
    Top = 69
    Width = 102
    Height = 15
    Anchors = [akLeft, akBottom]
    Caption = 'Your score string is:'
    ExplicitTop = 8
  end
  object Label2: TLabel
    Left = 29
    Top = 26
    Width = 336
    Height = 24
    Anchors = [akLeft, akBottom]
    Caption = 'Congratulations on a new record!'
    Font.Charset = ANSI_CHARSET
    Font.Color = clAqua
    Font.Height = -21
    Font.Name = 'Arial'
    Font.Style = [fsBold]
    ParentFont = False
    Transparent = True
    ExplicitTop = -35
  end
  object Label3: TLabel
    Left = 28
    Top = 24
    Width = 336
    Height = 24
    Anchors = [akLeft, akBottom]
    Caption = 'Congratulations on a new record!'
    Font.Charset = ANSI_CHARSET
    Font.Color = clGreen
    Font.Height = -21
    Font.Name = 'Arial'
    Font.Style = [fsBold]
    ParentFont = False
    Transparent = True
    ExplicitTop = -37
  end
  object Edit1: TEdit
    Left = 14
    Top = 89
    Width = 365
    Height = 25
    Anchors = [akLeft, akBottom]
    AutoSelect = False
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -14
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    TabOrder = 0
  end
  object Button1: TButton
    Left = 183
    Top = 130
    Width = 113
    Height = 25
    Hint = 'View web page'
    Anchors = [akLeft, akBottom]
    Caption = '&Hi-Score web page'
    ParentShowHint = False
    ShowHint = True
    TabOrder = 2
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 304
    Top = 130
    Width = 75
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = '&Close'
    ModalResult = 2
    TabOrder = 3
    OnClick = Button2Click
  end
  object Button3: TButton
    Left = 64
    Top = 130
    Width = 113
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = '&Submit to Server'
    Default = True
    ParentShowHint = False
    ShowHint = True
    TabOrder = 1
    OnClick = Button3Click
  end
end
