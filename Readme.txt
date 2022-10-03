                                MORSE RUNNER
                              Contest Simulator
                                  freeware

                          Field Day Contest Prototype

                          Ver 1.80 Copyright (C) 2022  Mike Brashler, W7SST https://github.com/w7sst/MorseRunner
Previous works:
              original to Ver 1.68  Copyright (C) 2004-2016 Alex Shovkoplyas, VE3NEA http://www.dxatlas.com/MorseRunner
              Ver 1.69 to Ver 1.71  Copyright (C) 2016 Lin Quan, BG4FQD https://github.com/BH1SCW/MorseRunner
                          Ver 1.71a Copyright (C) 2021 David Palma, CT7AUP

PLATFORMS

  - Windows XP/7/8/10/11
  - works on Linux systems under WINE (info TNX F8BQQ).

INSTALLATION

  - Uncompress the file to any folder and run "MorseRunner.exe"

UNINSTALLATION

  - Delete MorseRunner directory.

CONFIGURATION

  Contest Selection
    1) Select the desired contest using the Contest drop-down list.
    2) Enter the Contest Exchange in the Exchange field;
       error messages will be displayed in the status area.

  Station

    Call - enter your contest callsign here.

    QSK - simulates the semi-duplex operation of the radio. Enable it if your
      physical radio supports QSK. If it doesn't, enable QSK anyway to see
      what you are missing.

    CW Speed - select the CW speed, in WPM (PARIS system) that matches your
      skills. The calling stations will call you at about the same speed.

    CW Pitch - pitch in Hz.

    RX Bandwidth - the receiver bandwidth, in Hz.

    Audio Recording Enabled - when this menu option is checked, MR saves
      the audio in the MorseRunner.wav file. If this file already
      exists, MR overwrites it.

  Band Conditions

     I tried to make the sound as realistic as possible, and included a few
     effects based on the mathematical model of the ionospheric propagation.
     Also, some of the calling stations exhibit less then perfect operating
     skills, again to make the simulation more realistic. These effects can
     be turned on and off using the checkboxes described below.

     QRM - interference form other running stations occurs from time to time.

     QRN - electrostatic interference.

     QSB - signal strength varies with time (Rayleigh fading channel).

     Flutter - some stations have "auroral" sound.

     LIDS - some stations call you when you are working another station,
       make mistakes when they send code, copy your messages incorrectly,
       and send RST other than 599.

     Activity - band activity, determines how many stations on average
       reply to your CQ.

  Audio buffer size

    You can adjust the audio buffer size by changing the BufSize value in the
    MorseRunner.ini file. Acceptable values are 1 through 5, the default is 3.
    Increase the buffer size for smooth audio without clicks and interruptions;
    decrease the size for faster response to keyboard commands.

  Competition duration

    The default duration of a competition session is 60 minutes. You can set it
    to a smaller value by changing the CompetitionDuration entry in the
    MorseRunner.ini file, e.g.:

    [Contest]
    CompetitionDuration=15

  Calls From Keyer

    If you have an electronic keyer that simulates a keyboard - that is, sends
    all transmitted characters to the PC as if they were entered from a keyboard,
    you can add the following to the INI file:

    [Station]
    CallsFromKeyer=1

    With this option enabled, the callsign entered into the CALL field is not
    transmitted by the computer when the corresponding key is pressed. This option
    has no effect in the WPX and HST competition modes.

  Additional simulator settings

    Setup/CW Min Rx Speed - Set a speed below the CW Speed. If 0 it behaves like the original MorseRunner
    Setup/CW Max Rx Speed - Set a speed above the CW Speed. If 0 it behaves like the original MorseRunner
    Setup/NR Digits       - The number of digits of the DX Station NR
    Setup/CWOps Number    - CWOps ID number used on the CWT Contest

STARTING A CONTEST

The selected contest can be started in one of four modes.

 Pile-Up mode: a random number of stations calls you after you send a CQ. Good
   for improving copying skills.

 Single Calls mode: a single station calls you as soon as you finish the
   previous QSO. Good for improving typing skills.

 WPX Competition mode: similar to the Pile-Up mode, but band conditions and contest
   duration are fixed and cannot be changed. The keying speed and band activity
   are still under your control.

 HST Competition mode: all settings conform to the IARU High Speed Telegraphy
   competition rules.

To start a contest, set the duration of the exercise in the Run for NN Minutes
box (only for Pile-Up and Single Calls modes), and click on the desired mode
in the Run button's menu. In the Pile-Up and Competition mode, hit F1 or Enter
to send a CQ.

KEY ASSIGNMENTS

  F1-F8 - sends one of the pre-defined messages. The buttons under the input
    fields have the same functions as these keys, and the captions
    of the buttons show what each key sends.

  "\" - equivalent to F1.(*Above 1.70 disable this key)

  Esc - stop sending.

  Alt-W, Ctrl-W, F11 - wipe the input fields.

  Alt-Enter, Shift-Enter, Ctrl-Enter - save QSO.

  <Space> - auto-complete input, jump between the input fields.

  <Tab>, Shift-<Tab> - move to the next/previous field.

  ";", <Ins> - equivalent to F5 + F2.

  "+", ".", ",", "[" - equivalent to F3 + Save.

  Enter - sends various messages, depending on the state of the QSO;

  Up/Down arrows - RIT;

  Ctrl-Up/Ctrl-Down arrows - bandwidth;

  PgUp/PgDn, Ctrl-F10/Ctrl-F9, Alt-F10/Alt-F9 - keying speed,
    in 5 WPM increments.

WPX COMPETITION RULES

The exchange consists of the RST and the serial number of the QSO.

The score is a product of points (# of QSO) and multiplier (# of different
prefixes).

The bottom right panel shows your current score, both Raw (calculated
from your log) and Verified (calculated after comparing your log to other
stations' logs). The histogram shows your raw QSO rate in 5-minute blocks.

The log window marks incorrect entries in your log as follows:

  DUP - duplicate QSO.

  NIL - not in other station's log: you made a mistake in the callsign, or forgot
        to send the corrected call to the station.

  RST - incorrect RST in your log.

  NR - incorrect exchange number in your log.

  CL - incorrect Arrl Field Day Classification in your log.

  NAME - incorrect Name in your log.

  SEC - incorrect ARRL Section in your log.

  ST - incorrect State in your log.

SUBMITTING YOUR SCORE

If you complete a full 60-minute session in the WPX Competition mode, Morse Runner
will generate a score string that you can post.

  The original scoring website by Alex Shovkoplyas, VE3NEA, was
  http://www.dxatlas.com/MorseRunner/MrScore.asp
  but it is no longer active.

  Lin Quan, BG4FQD, created the scoring website, https://www.bh1scw.com/mr/score
  but to submit scores you must now email him at bh1scw[at]gmail.com

  "Open 2019 UZ2M Morse Runner contest" Facebook Group
  (Still active)
      Open contest between friends in Morse Runner in two modes,
      Single Call and Pile-Up mode. Try 10 min training and fix
      screenshot with date and time. Please send a screenshot to
      this group and after we check it we will publish it!

  "ZS-CW Morse Runner" Facebook Group
      In Morse Runner, Here you will screen shot your 10 min stint,
      (ONLY 10 min not more) paste it into this Facebook Group,
      the idea is to try beat the previous score of the last person
      who posted their screen shot. I'm aware we are all on different
      levels of copy speed, but that's irrelevant because you might
      want to match their speed, and try beat their score

  "CW Freak - Morse Runner" Facebook Group
      This is a group for Morse Games fans. I thank in advance anyone
      who wants to share their results, their advice and their
      impressions with fun.

You can view your previous score strings using the
File -> View Score menu command.

VERSION HISTORY

1.80 (W7SST) Oct 2022
  - Beta release of multi-contest support
  - Add ARRL Field Day
  - Add NCL NAQP

1.71a (CT7AUP) Nov 2021
  - CWOPS CWT Contest
  - CW RX Min Speed.
  - CW RX Max Speed.
  - NR number of digits.

1.70 (BG4FQD) Aug 25, 2016
  - Adjust UI, support windows scheme.
  - Support showing callsign infomation, You can modify it in the "ARRL.LIST"
  - Disable hot key: "\" to prevent pressing by carelessness.
  - Some other bugs fixing.

1.69 (BG4FQD) Jul 16, 2016
  - Add "Hi-Score web page" server in MorseRunner.ini.
  - Change default Font to Cleartype 'segoe ui', 'Consolar';
  - Change string to Unicode, Building with Delphi 2010 sp3.

1.68 (VE3NEA) 2016
  - TU + MyCall after the QSO is now equivalent to CQ

1.67 (VE3NEA)
  - small changes in the HST competition mode.

1.65, 1.66 (VE3NEA)
  - a few small bugs fixed.

1.61 - 1.64 (VE3NEA)
  - small changes in the HST competition mode.

1.6 (VE3NEA)
  - HST competition mode added;
  - CallsFromKeyer option added.

1.52 (VE3NEA)
  - the CompetitionDuration setting added.

1.51 (VE3NEA)
  - minor bugs fixed.

1.5 (VE3NEA)
  - more realistic behavior of calling stations;
  - self-monitoring volume control;
  - more creative LIDS;
  - CW speed hotkeys;
  - WAV recording;
  - menu commands for all settings (for blind hams).

1.4 (VE3NEA)
  - RIT function;
  - callsign completion/correction when sending;
  - faster response to keyboard commands;
  - bandwidth adjustment in 50 Hz steps;
  - the middle digit is selected when the cursor enters the RST field;
  - the QSO rate is now expressed in Q/hr;
  - the problem with the Finnish character set fixed.

1.3 (VE3NEA)
  - some key assignments corrected for compatibility with popular contesting
    programs;
  - statistical models refined for more realistic simulation;
  - rate display added;
  - a few bugs fixed.

1.2 (VE3NEA)
    (first public release)
  - Competetion mode added;
  - some bugs fixed.

1.1 (VE3NEA)
  - ESM (Enter Sends Messages) mode added;
  - a lot of bugs fixed.

DISCLAIMER OF WARRANTY

THE SOFTWARE PRODUCT IS PROVIDED AS IS WITHOUT WARRANTY OF ANY KIND. TO THE
MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, THE AUTHOR FURTHER
DISCLAIMS ALL WARRANTIES, INCLUDING WITHOUT LIMITATION ANY IMPLIED WARRANTIES
OF MERCHANTABILITY, FITNESS  FOR A PARTICULAR PURPOSE, AND NONINFRINGEMENT.
THE ENTIRE RISK   ARISING OUT OF THE USE OR PERFORMANCE OF THE SOFTWARE PRODUCT
AND DOCUMENTATION REMAINS WITH RECIPIENT. TO THE MAXIMUM EXTENT PERMITTED BY
APPLICABLE LAW, IN NO EVENT SHALL  THE AUTHOR BE LIABLE FOR ANY
CONSEQUENTIAL, INCIDENTAL, DIRECT, INDIRECT, SPECIAL, PUNITIVE, OR OTHER DAMAGES
WHATSOEVER  (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF PROFITS,
BUSINESS INTERRUPTION, LOSS OF INFORMATION, OR OTHER PECUNIARY LOSS) ARISING
OUT OF THIS AGREEMENT OR THE USE OF OR INABILITY TO USE THE SOFTWARE PRODUCT,
EVEN IF THE AUTHOR HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH
DAMAGES.

END OF DOCUMENT
