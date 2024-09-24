                                MORSE RUNNER
                              Contest Simulator
                                  freeware

                Version 1.85 - ARRL Sweepstakes Contest
            The sixth release of the Morse Runner Community Edition

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
  - Works on Linux systems under WINE (info TNX F8BQQ).
  - Works on Mac systems under WINE (use Win7 bottle) or Crossover (info TNX N3RTW).

INSTALLATION
  Open the zip file, extract the folder to your DESKTOP, and run
  MorseRunner.exe within this folder. Do not add these files to
  a previous release folder, or place in a windows program directory
  as this causes errors.

UNINSTALLATION
  - Delete MorseRunner directory.

CONFIGURATION
  First time setup instructions can be found within the program under help.

  Contest Selection
    1) Select the desired contest using the Contest drop-down list.
    2) Enter the Contest Exchange in the Exchange field;
       any error messages will be displayed in the status area.
       (please keep in mind that the IARU HST Competition mode might ignore
        some settings so as to behave like the original program.)

    Specific contest information is at very bottom of this document.

  Station
    Call - enter your contest call sign here.
    QSK - simulates the semi-duplex operation of the radio. Enable it if your
          physical radio supports QSK. If it doesn't, enable QSK anyway to see
          what you are missing.
    CW Speed - select the CW speed, in WPM (PARIS system) that matches your
               skills. The calling stations will call you at about the same speed.
               There are more speed controls under the settings menu.
    CW Pitch - pitch in Hz.
    RX Bandwidth - there are several ways to adjust this. See the key
                   assignments below.


  Band Conditions and Sounds
     It has been brought to our attention that our Morse Runner's Morse Code
     sounds different than the original 1.67/1.68. This is true, and if you
     caught this you have good ears! We corrected the spacing in the original
     program to match the rules for proper Morse Code. For more on this see:
     https://github.com/w7sst/MorseRunner/issues/301

     Alex Shovkoplyas, VE3NEA, made the sound as realistic as possible,
     and included a few effects based on the mathematical model of the
     ionospheric propagation. Also, some of the calling stations exhibit
     less than perfect operating skills, again to make the simulation more
     realistic. These effects can be turned on and off using the check boxes
     described below.

     QRM - interference form other running stations occurs from time to time.
     QRN - electrostatic interference.
     QSB - signal strength varies with time (Rayleigh fading channel).
     Flutter - some stations have "auroral" sound.
     LIDS - some stations call you when you are working another station,
            make mistakes when they send code, copy your messages incorrectly,
            and send RST other than 599. They might even ask for info over and
            over.
     Activity - band activity, determines how many stations on average
                reply to your CQ.

  The Run Button
    This starts and stops the competition or contest.
    Starting a Contest -
      To start the contest that is selected in the contest drop down,
      set the duration in the minutes box and use the run drop down
      to select the desired mode for the contest (single call or pile up).
      You may have to hit F1 (or Enter) to start sending CQ.

    Starting a Competition -
      To start a Competition, select either the WPX and HST competitions found
      in the run drop down. Many settings are locked for the competitions but
      The keying speed and activity are still under your control.

      WPX Competition mode forces all Band Conditions (QRM, QRN, QRB, Flutter, LIDs).
      HST Competition mode settings conform to the IARU High Speed Telegraphy
      competition rules and forces off all Band Conditions
      (QRM, QRN, QRB, Flutter, LIDs).

      The default duration of a competition session is 60 minutes. You can
      change this setting to any time desired. To set a new default
      use the CompetitionDuration entry in the MorseRunner.ini file, e.g.:
        [Contest]
        CompetitionDuration=15

  Additional Settings
    RIT - Many never noticed that the original program has an RIT function
          in the receiver. It is the unmarked teal bar at the very bottom of
          the screen. If you can't hear someone calling you, or if they are off
          frequency this is why. This is controlled by the up and down arrows on
          the keyboard as well as the mouse scroll wheel. This is handy to
          focus on a particular responder.
          The RIT is adjusted between -500 and 500 Hz incremented in 50Hz Steps.
          You can modify the RIT step increment in the MorseRunner.ini file, e.g.:
            [Settings]
            RitStepIncr=50
          Valid values range between -500 and 500. Negative values can be used to
          change the direction of Up/Down arrow keys or mouse wheel movement. Note
          that a zero value will disable this feature and is not recommended.
          HST Competition mode ignores this setting and defaults to 50Hz/Step.

    Audio Recording Enabled - You can record yourself under "File" menu
      "Audio Recording Enabled". When this menu option is checked, MR saves
      the audio as "MorseRunner.wav" in the same folder. If this file already
      exists, MR overwrites it.

    Audio buffer size
      You can adjust the audio buffer size by changing the BufSize value in the
      MorseRunner.ini file. Acceptable values are 1 through 5, the default is 3.
      Increase the buffer size for smooth audio without clicks and interruptions;
      decrease the size for faster response to keyboard commands.

    Calls from a keyer
      If you have an electronic keyer that simulates a keyboard - that is, sends
      all transmitted characters to the PC as if they were entered from a keyboard,
      you can add the following to the INI file:
        [Station]
        CallsFromKeyer=1
      With this option enabled, the call sign entered into the CALL field is not
      transmitted by the computer when the corresponding key is pressed. This option
      has no effect in the WPX and HST competition modes.

    CW speed controls
      CW Min and Max settings
        Under the Settings menu the CW Min Rx Speed and CW Max RX Speed can
        establish a variable amount of speeds to respond to. Setting this to
        0 will have the program behave like the original MorseRunner 1.68.
      Farnsworth: For the K1USN SST contest only. Character wpm speed can be
        set by changing the number for "FarnsworthCharacterRate=25" entry in the
        MorseRunner.ini file found in the install folder and restarting the program.
      CW Speed increment
        This is changed in 2 WPM increments except the HST Competition which is locked
        at 5 WPM increments. The default WPM Step rate can be changed with values
        between 1 and 20 with the WpmStepRate entry in the MorseRunner.ini file, e.g.:
          [Station]
          WpmStepRate=2
      Suggestions
        Try selecting a speed higher than your proficiency to improve. Keep in mind
        the CWops CW Academy (free classes) start with 18 WPM, 20 WPM and 25 WPM
        character speeds for each level of classes.

    Serial NR
      Serial numbers sent by the responding station can be adjusted with the
      following settings:
        - Start of Contest (Default)
            Generates random serial numbers starting near 1 and increasing as
            the contest runs. Matches default behavior found in version 1.68.
            Used during HST Simulation.
        - Mid-Contest (50-500)
            Sends 2 and 3-digit numbers, randomly generated between 50 and 500.
            Numbers will generated using a similar distribution as CQ WPX 2023.
        - End of Contest (500-5000)
            Sends 3 and 4-digit numbers, randomly generated between 500 and 5000.
            Numbers will generated using a similar distribution as CQ WPX 2023.
        - Custom Range (01-99)...
            This option allows a user-entered range string of the form "<min>-<max>".
            An optional leading zero can be specified for generating serial numbers
            with leading zeros (e.g. 001-200).

    Show Check/Section (for ARRL Sweepstakes only)
      This contest has a complicated exchange and there is a setting to prepopulate
      the exchange to match N1MM's behavior. Please see the contest rules section
      below for more information.

    Show Exchange Summary In Status Bar (for ARRL Sweepstakes only)
      This contest will display the parsed exchange summary in either the status
      bar (default) or optionally in the label/caption above the exchange entry
      field. Please see the contest rules section below for more information.


  Responses
    There are five basic responses that you can receive:
       1. Nothing
          If calling CQ, no one heard you call CQ again.
          If you responded to someone and you got silence, the call sent was incorrect.
          Send F8 NIL (Not In Log) to have them respond again and/or restart the pile-up.
       2. Corrected Call
          If you sent a partial call or if you were off a little they may respond with
          "de" (from) and their call or just their call again. Sometimes just the call
          is repeated and sometimes with the exchange.
       3. They may respond with "NR?"
          You will have to send your exchange again (Hit F2).
       4. They may respond with "AGN"
          You will have to send your exchange again (Hit F2).
       5. "R" with their exchange.
          When you get the exchange hit enter to log it.
          Please note that occasionally you will get "NR?" and "AGN" multiple times.
          Respond with F5 then F2. This is a FULL exchange, you will get that "R"
          (Roger) and the exchange. Respond with F3, "TU".

KEY ASSIGNMENTS
  F1               - Send CQ (sounds like seek you)
  F2               - Sends your full exchange
  F3               - Send TU (thank you)
  F4               - Sends your call sign
  F5               - Sends responder's call sign
  F6               - Send B4
  F7               - Sends the question mark (?)
  F8               - Sends NIL (not in log)
  F11              - Wipes the input fields
  F12              - Sends NR? (request their exchange to be repeated)

  Enter Key        - Enter Sends Message (msg sent depends on state of QSO)
  Space Bar        - Auto completes and jumps between input fields
  Escape key       - Stops your sending

  Semicolon        - Sends your full exchange
  Insert key       - Sends your full exchange
  Plus key (+)     - Send TU (thank you) and saves QSO
  Period (.)       - Send TU (thank you) and saves QSO
  Bracket ([)      - Send TU (thank you) and saves QSO
  Comma (,)        - Send TU (thank you) and saves QSO

  Ctrl-W           - Wipes the input fields
  Alt-W            - Wipes the input fields (with Windows chime)
  Shift-Enter      - Saves the QSO without sending anything
  Ctrl-Enter       - Saves the QSO without sending anything
  Alt-Enter        - Saves the QSO without sending anything
  Tab Key          - Moves to Call, RST, CQ-Zone, Station Call, and your exchange
  Shift Tab        - Moves to Call, RST, CQ-Zone, Station Call, and your exchange
  Up arrow         - Moves the RIT right (reversible in settings)
  Down arrow       - Moves the RIT left (reversible in settings)
  Mouse wheel      - Moves the RIT
  Left arrow       - Adjusts the RX Bandwidth
  Right arrow      - Adjusts the RX Bandwidth
  Ctrl-up arrow    - Adjusts the RX Bandwidth
  Ctrl-down arrow  - Adjusts the RX Bandwidth
  Ctrl-mouse wheel - Adjusts the RX Bandwidth
  Page down key    - Adjusts the keying speed down
  Page up key      - Adjusts the keying speed up
  Ctrl-F9          - Adjusts the keying speed down
  Ctrl-F10         - Adjusts the keying speed up
  Alt-F9           - Adjusts the keying speed down
  Alt-F10          - Adjusts the keying speed up

STATISTICS AREA
  The bottom right panel shows your current score, both Raw (calculated
  from your log) and Verified (calculated after comparing your log to other
  stations' logs). The histogram shows your raw QSO rate in 5-minute blocks.

LOG WINDOW
  The log window marks incorrect entries in your log as follows:
  DUP   - duplicate QSO.
  NIL   - not in other station's log: you made a mistake in the call sign,
          or waited to long to save the information.
  RST   - incorrect RST
  NR    - incorrect exchange
  CL    - incorrect Arrl Field Day Classification
  NAME  - incorrect Name
  SEC   - incorrect ARRL Section
  ST    - incorrect State/Provence
  QTH   - incorrect location information.
  ZN    - incorrect CQ-Zone or ITU-Zone information
  SOC   - incorrect IARU Society information

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

Version 1.85 (September 2024)
  - Add ARRL Sweepstakes Contest (W7SST)

  Contest-specific improvements...
  - Correct the call history file for the JARL ALL JA contest (JR8PPG)
  - HST Contest - show Score column for all run modes (W7SST)
  - CQWW - Allow cut numbers to sent and entered into log (W7SST)
  - NCJ NAQP - update call history file
  - ARRL FD - update call history file
  - IARU HF - update call history file

  General bug fixes and improvements...
  - Replace Check column with corrected exchange information (errors are shown in Red) (W7SST)
  - Fix caller ghosting where stations would disappear from QSO (W7SST)
  - Fix problem where ghosted calls are not added to log (W7SST)
  - Improve handling of partial callsign matches (W7SST)
  - Improve QSO exchanges for partially-correct callsigns (W7SST)
  - Improve QSO exchange error reporting via status bar (W7SST)
  - Add application Minimize button (W7SST)

Version 1.84 (March 2024)
  - Add IARU HF World Championship Contest (W7SST)
  - CQ WPX improvements, including editable exchange and improved serial NR generation (W7SST)
  - Update call history files for ARRL DX, ARRL FD, CQ WW, CWOPS CWT, K1USN SST and NCJ NAQP Contests

  Contest-specific improvements...
  - ARRL DX - Fix incorrect handling of KH6/KL7 stations using AH6/AL7, NH6/NL7, WH6/WL7 (Coded by W7SST)
  - ARRL FD - Reduce high number of home/portable club stations (W7SST)
  - CQ WPX - Add editable exchange field with starting number or '#' (W7SST)
  - CQ WPX - Improve Serial Number generation; rename NR Digits menu Serial NR (W7SST)
  - CQ WPX - Fix problem where DX stations will occasionally send a serial number of zero (Coded by W7SST)
  - CWOPS CWT - Fix problem where contest parser was reading first line of file (Coded by W7SST)
  - JARL - DX station will send an abbreviated exchange number in the JARL ALLJA and ACAG contests (Coded by JR8PPG)
  - JARL - User's exchange number is not abbreviated (not convert 100 to 1TT) (Coded by JR8PPG)
  - K1USN SST - User text field in call history file should be optional (Coded by W7SST)
  - NAQP - Fix problem where exchange field did not allow numbers (e.g. KH6 or KL7) (Coded by W7SST)

  General bug fixes and improvements...
  - Improve Run button behavior with default Run Mode and Stop icon (W7SST)
  - No RIT needed for Single Call Modes (W7SST)
  - After a CQ, if nothing is caught or if what you caught is wrong, you can use
    F7 ('?') to instruct the callers to call again. (F6FVY)
  - New callers can be added when a QSO is done. (F6FVY)
  - When F1 was hit several times in a row, the number of callers was
    increasing without respect to the activity setting. (F6FVY)
  - Improve the "reply or not" algorithm to allow callers with long
    callsigns to reply, even if only few letters are caught. (F6FVY)
  - Add Receive Bandwidth adjustment using Cntl-key and mouse wheel (F6FVY, W7SST)
  - Speed increments / decrements modified (2 WPM instead of 5). (F6FVY, W7SST)
  - Improve RIT adjustment using mouse wheel (W7SST)
  - Improve pattern matching for DXCC entities (used in status bar) (Coded by W7SST)
  - Fix WPM keyboard entry incorrect behavior for Spin Box (up down control) (Coded by W7SST)
  - Spacebar or Tab will now select both exchange fields (Coded by W7SST)
  - Hide Dx Station's Entity status string if same as user's Entity (Coded by W7SST)
  - Shift-F9 added as shortcut to start Single Call mode (Coded by W7SST)

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
  - Bug fixes

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

1.68.4+ (F6FVY) 2018
  - The mouse wheel now acts as RIT. (F6FVY)

1.68.3+ (F6FVY) 2018
  - After a CQ, if nothing is caught or if what you caught is wrong, you can use
    F7 ('?') to instruct the callers to call again. (F6FVY)

1.68.2+ (F6FVY) 2018
  - New callers can be added when a QSO is done. (F6FVY)
  - Bugfix : When F1 was hit several times in a row, the number of callers was
    increasing without respect to the activity setting. (F6FVY)
  - The "reply or not" algorithm has been modified to allow callers with long
    callsigns to reply, even if only few letters are caught (experimental). (F6FVY)
  - Speed increments / decrements modified (2 WPM instead of 5). (F6FVY)

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

    ARRL Sweepstakes
    When: First full weekend in November
    How: Stations in US/Canada exchange information with other US/Canada stations.
    Exchange: <serial number> <Precedence> <Callsign> <Check> <Section>
    where:
      Serial number: sequential serial number for each contact
      Precedence: A, B, Q, M, S, U
      Callsign: your call sign
      Check: last two digits of the year the operator or station was first licensed
      Section: ARRL/RAC Section
      for example: "123 A 72 OR"
    Rules: https://contests.arrl.org/ContestRules/SS-Rules.pdf
    Entering your Exchange:
    - This contest uses a single field to enter the four parts of the SS-Rules
      exchange. The exchange parts can be entered in any order as long as the
      'numeric part' is followed by its corresponding 'character part.'
    - For example, the two exchange parts can be entered in either order:
        a) "123 A 72 OR"
        b) "72 OR 123 A"
    - If a correction needs to be made, just type it at the end. For example,
      while copying you realize a mistake (123 should be 124). In this case,
      simply type the correction at the end:
        "123 A 72 OR  124 A"
      This allows corrections to be made while you are copying the exchange
      without using any arrow, delete or backspace keys.
    - The spaces between the numeric and characters parts are optional.
      The following are equivalent:
        "123 A 72 OR"
        "123A 72OR"
        "72 OR 123 A"
        "72OR 123A"
    - Callsigns corrections can be optionally entered into the Exchange field.
      If the caller sends a corrected callsign, you can enter the updated call
      anywhere in the exchange field without changing focus to the original
      callsign entry field.  For example, entering "W1AW 123 A 38 CT" will
      update the callsign when storing the QSO into the log.
    - For added realism, the simulation will populate the exchange field
      with the Check and Section entries for the entered callsign. This
      behavior matches current N1MM behavior. In addition, the simulation will
      occasionally modify the Section to simulate when an operator is operating
      from a different location.

      By default, the Check/Section value will be pre-populated in the Exchange
      field about 50% of the time. This behavior can be adjusted between 0% and
      100% by setting the following keyword in the MorseRunner.ini file:
        [Settings]
        ShowCheckSection=50
      Valid values range between 0 and 100, representing 0% and 100%.
      Note that a zero value will disable this feature.

      An Exchange Summary is provided as the user enters the received exchange
      into the Exchange field. This summary shows QSO information as it will
      entered into the log. For example: "192B W7SST 72 OR". By default, this
      information is displayed in the status bar. If desired, the exchange
      summary can be written into the label above the exchange field entry
      field by setting the following keyword in the MorseRunner.ini file:
        [Settings]
        ShowExchangeSummaryInStatusBar=0
      Valid values are: 0-display above entry field; or 1-display in status bar.

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

    HST (High Speed Test)
    When: MorseRunner is a category in the World and IARU Region championships which takes
    place every year. A list of winners for MorseRunner is found here:
    http://www.highspeedtelegraphy.com/HST-world-championships/Results-Morse-Runner
    How: Using MorseRunner the test is 10 minutes with two attempts. Activity is set at 4.
    The competitor can change the speed during the contest. Currently the rules state the
    settings and the version of MorseRunner to be used (1.67).
    Exchange: RST plus serial number starting with 001
    Rules: https://www.iaru-r1.org/about-us/committees-and-working-groups/hst/hst-rules/

    IARU HF World Championship
    Focused on contacting amateurs around the world especially IARU member
    society headquarters stations using the 160, 80, 40, 20, 15 and 10 meter bands.
    When: The second full weekend of July Beginning at 1200 UTC Saturday and runs through
    1159 UTC Sunday. Both Single and Multioperator stations operate the 24-hour period.
    How: Contact as many as possible.
    Exchange: IARU member society stations, council and committees send signal report and
    abbreviations such as AC, R1, R2, or R3. All others send signal report and ITU Zone.
    Rules: https://contests.arrl.org/ContestRules/IARU-HF-Rules.pdf

    JARL All Cities All Guns(ACAG)
    The ACAG contests have very long exchange numbers.
    When: Two days before the second Monday in October.
    How: Contact as many City or Gun(Country) or Ku(Ward) possible.
    In JARL contests, a power code is added to the end of the exchange number.
    P is 5W or less(QRP), L is 10W or less, M is 100W or less, H is over 100W.
    Exchange: RST plus City code/Gun(Country) code/Ku(Ward) code plus Power code(P/L/M/H)
    Rules: https://www.jarl.org/Japanese/1_Tanoshimo/1-1_Contest/all_cg/allcg_rule.htm (japanese only)

    JARL ALL JA
    The ALLJA Contest is the largest contest in Japan.
    When: Last weekend in April.
    How: Contact as many Prefecture or Hokkaido promotion bureau possible.
    In JARL contests, a power code is added to the end of the exchange number.
    P is 5W or less(QRP), L is 10W or less, M is 100W or less, H is over 100W.
    Exchange: RST plus Prefecture code/Hokkaido promotion bureau code plus Power code(P/L/M/H)
    Rules: https://www.jarl.org/Japanese/1_Tanoshimo/1-1_Contest/all_ja/all_ja_rule.htm (japanese only)

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
