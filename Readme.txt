                                MORSE RUNNER
                              Contest Simulator
                                  freeware

                Version 1.83 - JARL allja, JARL acag, & K1USN sst
            The fourth release of the Morse Runner Community Edition

               Copyright (C) 2004-2016 Alex Shovkoplyas, VE3NEA
                      http://www.dxatlas.com/MorseRunner/

        Copyright (C) 2022-2024 Morse Runner Community Edition Contributors
                   https://www.github.com/w7sst/MorseRunner/


JOIN OUR COMMUNITY
  You are invited to join our community effort.
  For more information on the Morse Runner Community Edition project,
  please visit https://github.com/w7sst/MorseRunner#readme.
  Feedback can be left in our discussions area.

  You can also discuss or leave feedback at https://groups.io/g/MorseRunnerCE.

PLATFORMS
  - Windows XP/7/8/10/11
  - works on Linux systems under WINE (info TNX F8BQQ).

INSTALLATION
  Open the zip file, extract the folder to your desktop, and run
  MorseRunner.exe in that folder. (Please do not add these files to
  a previous folder.)

UNINSTALLATION
  - Delete MorseRunner directory.

CONFIGURATION
  First time setup instructions can be found within the program under help.

  Contest Selection
    1) Select the desired contest using the Contest drop-down list.
    2) Enter the Contest Exchange in the Exchange field;
       any error messages will be displayed in the status area.
       * Cut Numbers in sending exchanges coming soon.

    More contest information is at the bottom of this document.

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
     Alex Shovkoplyas, VE3NEA, made the sound as realistic as possible,
     and included a few effects based on the mathematical model of the
     ionospheric propagation. Also, some of the calling stations exhibit
     less than perfect operating skills, again to make the simulation more
     realistic. These effects can be turned on and off using the checkboxes
     described below.

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
    Setup/CW Min Rx Speed - Set a speed below the CW Speed. 0 behaves like the original MorseRunner
    Setup/CW Max Rx Speed - Set a speed above the CW Speed. 0 behaves like the original MorseRunner
    Setup/NR Digits       - The number of digits of the DX Station NR
    Setup/CWOps Number    - CWOps ID number used on the CWT Contest

    Farnsworth: For the K1USN SST contest only. Character wpm speed can be set by
    changing the number for "FarnsworthCharacterRate=25" entry in the MorseRunner.ini
    file found in the install folder and restarting the program.

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

STATISTICS AREA
  The bottom right panel shows your current score, both Raw (calculated
  from your log) and Verified (calculated after comparing your log to other
  stations' logs). The histogram shows your raw QSO rate in 5-minute blocks.

LOG WINDOW
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
  will generate a score string that you can post. (A replacement Hi-Score site is needed.)

    The original scoring website by Alex Shovkoplyas, VE3NEA, was
    http://www.dxatlas.com/MorseRunner/MrScore.asp
    but it is no longer active.

    Lin Quan, BG4FQD, created the scoring website, https://www.bh1scw.com/mr/score
    but to submit scores you must now email him at bh1scw[at]gmail.com

    "Open 2019 UZ2M Morse Runner contest" Facebook Group
    (Still active)
        Open contest between friends in Morse Runner in two modes,
        Single Call and Pile-Up mode for HST. Try 10 min duration and fix
        screenshot with date and time. Please send a screenshot to
        this group and after they check it they will publish it!

    "ZS-CW Morse Runner" Facebook Group
        In Morse Runner, Here you will screen shot your 10 min HST,
        (ONLY 10 min not more) paste it into this Facebook Group,
        the idea is to try beat the previous score of the last person
        who posted their screen shot. I'm aware we are all on different
        levels of copy speed, but that's irrelevant because you might
        want to match their speed, and try beat their score.

    "CW Freak - Morse Runner" Facebook Group
        This is a group for Morse Games fans. For Anyone
        who wants to share their results, their advice and their
        impressions with fun.

  You can view your previous score strings using the
  File -> View Score menu command.

VERSION HISTORY

Version 1.83 (March 2023)
  - Added K1USN Slow Speed Test (Coded by W7SST)
  - Added JARL All Japan Contest (Coded by JR8PPG)
  - Added JARL All Cities All Guns (ACAG) Contest (Coded by JR8PPG)
  - Add support for CWOPS CWT nonmember exchanges (Coded by W7SST)
  - Improve CW spacing and timing (Found by John K3TN, Coded by W7SST)

Version 1.82 (Dec 2022)
  - Added ARRL DX Contest (Coded by W7SST)
  - CWOPS Contest fixes (Coded by W7SST)
  - Rename the F2 button to exchange (Coded by tekenny)
  - Add 'Help | First Time Setup' (Written by KD4SIR & W7SST)
  - Add cut numbers (e.g. 5NN = 599) in exchanges received (Coded by W7SST)
  - bug fixes

Version 1.81 (Oct 2022)
  - Fix bad CWOPS CWT Exchange message (Coded by W7SST)
  - Added CQ WW Contest (Coded by W7SST)
  - Update README.md (by F6FVY, KD4SIR)
  - Updated GUI and menu items (Coded by W7SST)

Version 1.80 (Oct 2022)
  - Added multi-contest support (Coded by W7SST)
  - Added ARRL Field Day contest (Coded by W7SST)
  - Added NCL NAQP contest (Coded by W7SST)

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

CONTEST INFORMATION

    ARRL DX
    When: Third full weekend in February
    How: W/VE stations only work DX and vice versa
    Exchange: W/VE send RST and state/province
    DX send RST and power (number or abbreviation like k or kw)
    Rules: https://contests.arrl.org/ContestRules/DX-Rules.pdf

    ARRL Field Day
    When: always held on the 4th full weekend in June.
    How: operate in abnormal situations in less than optimal conditions.
    Exchange: Number of Transmitters with Class plus ARRL/RAC section (or DX)
    for example: "3A KY" or "1D DX"
    Classes are:
    A: Club/non-club (3+ people) portable
    B: 1 or 2 people portable
    C: Mobile/Maritime/Aeronautical
    D: Home stations
    E: Home stations using emergency power
    F: Emergency Operation Centers
    Rules: https://contests.arrl.org/ContestRules/Field-Day-Rules.pdf

    CQ WPX
    When: Last weekend in May
    How: Multi may operate 48 hours, Singles may work 36 hours.
    Prefixes are Multipliers.
    Exchange: RST plus serial number starting with 001
    Rules: https://www.cqwpx.com/rules/2022_cqwpx_rules.pdf

    CQ WW
    The largest Amateur Radio competition in the world.
    When: Last weekend in November
    How: Contact as many CQ zones and countries possible.
    Exchange: RST plus CQ Zone (e.g., 599 05)
    Rules: https://www.cqww.com/rules/current_rules_cqww.pdf

    CWOPS CWT
    CWOPS membership not required, a meet and greet and show activity on the bands.
    When: 1 hour long Wednesdays at 1300z and 1900z, Thursdays at 0300z and 0700z.
    How: Call “CQ CWT”. Slow down for others so everyone is welcome.
    Exchange: Members: First Name and CWOPS member number.
    Non-members: First Name, and State/Province or DX Country prefix.
    Rules: https://cwops.org/cwops-tests/

    JARL ALLJA
    The ALLJA Contest is the largest contest in Japan.
    When: Last weekend in April.
    How: Contact as many Prefecture or Hokkaido promotion bureau possible.
    In JARL contests, a power code is added to the end of the exchange number.
    P is 5W or less(QRP), L is 10W or less, M is 100W or less, H is over 100W.
    Exchange: RST plus Prefecture code/Hokkaido promotion bureau code plus Power code(P/L/M/H)
    Rules: https://www.jarl.org/Japanese/1_Tanoshimo/1-1_Contest/all_ja/all_ja_rule.htm (japanese only)

    JARL All Cities All Guns(ACAG)
    The ACAG contests have very long exchange numbers.
    When: Two days before the second Monday in October.
    How: Contact as many City or Gun(Country) or Ku(Ward) possible.
    In JARL contests, a power code is added to the end of the exchange number.
    P is 5W or less(QRP), L is 10W or less, M is 100W or less, H is over 100W.
    Exchange: RST plus City code/Gun(Country) code/Ku(Ward) code plus Power code(P/L/M/H)
    Rules: https://www.jarl.org/Japanese/1_Tanoshimo/1-1_Contest/all_cg/allcg_rule.htm (japanese only)

    K1USN Slow Speed Test (SST)
    Members of the K1USN Radio Club, who are also members of the CW Operators’ Club (CWops),
    sponsor a one-hour slow speed CW “contest” called the SST. For those who prefer a more
    leisurely CW pace or are new CW operators or contesters, this just might be what you're looking for!
    When: Fridays 20:00-21:00 UTC & Mondays 00:00-01:00 UTC
    How: Slower speeds (up to 20 Words Per Minute). Usually sent with 25wpm character speeds.
    Many operators prefer slower effective speeds using the “Farnsworth” sending method,
    sending characters at speeds up to 25WPM.
    Farnsworth: For this contest only. Character wpm speed can be set by changing the number
    for "FarnsworthCharacterRate=25" entry in the MorseRunner.ini file found in the install
    folder and restarting the program.  Actual WPM throughput is set by entering a value
    in the CW Speed box.
    Exchange: suggested first name and state, province, or DX country. It is fairly common
    to send greetings before the exchange.
    Rules, frequencies and sample exchanges can be found at http://www.k1usn.com/sst.html

    HST (High Speed Test)
    When: MorseRunner is a category in the World and IARU Region championships which takes
    place every year. A list of winners for MorseRunner is found here:
    http://www.highspeedtelegraphy.com/HST-world-championships/Results-Morse-Runner
    How: Using MorseRunner the test is 10 minutes with two attempts. Activity is set at 4.
    The competitor can change the speed during the contest. Currently the rules state the
    settings and the version of MorseRunner to be used (1.67).
    Exchange: RST plus serial number starting with 001
    Rules: https://www.iaru-r1.org/about-us/committees-and-working-groups/hst/hst-rules/

    NCJ NAQP
    The National Contest Journal North American QSO Party
    When: Second full week in January and first full weekend in August
    How: To work as many North American stations as possible.
    Single op, Single op assisted and Multi two transmitter categories.
    Exchange: North America: First Name and state/province/country
    Non-North America: First Name only.
    Rules: https://ncjweb.com/NAQP-Rules.pdf

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
