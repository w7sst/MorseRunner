# Morse Runner Community Edition

## Welcome
For many years, hams have been using Morse Runner as an effective practice tool
for improving their CW copying and pileup handling skills. All along, users
have expressed interest in additional contest support. Over the past few
years, a few developers have added additional contests to Morse Runner,
but not in a coordinated manner.

In this project, Morse Runner will be enhanced to support multiple contests along with combining
features and bug fixes from various independent development efforts.
Initial contests will include ARRL Field Day, CQ WW, CWOPS CWT, NCJ NAQP, etc.
Any contest with a corresponding call history file could be implemented.

## Goals
Our goal is to create a community of users and developers who share
a common vision of improving and supporting the Morse Runner Contest Simulator.

- Improve end-user experience by supporting multiple popular contests.
- Promote a community-based collaborative development environment.
- Incorporate enhancements and bug fixes from [other Morse Runner versions](#morse-runner-release-history).
- Maintain embedded operation with select logging programs (e.g. N1MM and DxLog).
- Integrate a recent Linux port.
- Perhaps develop training materials, including club presentations and perhaps end-user training.

## How can I help?
Anyway you want...

We need developers, contest advocates, testers, CW trainees and trainers,
documentation writers, release coordinators, open source development advocates,
project advisors, and Delphi and Lazarus development environment experts.
We hope to grow a community of contributors who can develop and
maintain Morse Runner over time.
By establishing a community-based approach focused on a common project, we will be
more efficient than individual efforts working on separately forked/cloned projects.

Please refer to [CONTRIBUTING.md](.github/CONTRIBUTING.md) for more information.

## Roadmap
Below is a high-level overview of project activities over the next year.

Now (active) | Next (planned, this fall) | Later (future, next year)
-------------|----------------|---------------
**Community...**<br>Launch Community Repository | Foster Community Growth | Investigate using GitHub project boards for this roadmap
Develop Community Guidelines | Trial team-based contest development model | Promote team-based contest development model
**Development...**:<br>Standardize git setup | Multi-contest design | Multi-contest implementation
Invite prior authors;<br>Solicit early feedback | Merge selected features and bug fixes [from prior authors](#morse-runner-release-history) | Maintain existing integration with N1MM and DxLog
**Contests...**<br>FD, CWT, WPX, NAQP, HST | CQWW, Sweepstakes?, others... | Perhaps IARU/HF, All Asia, IOTA, ...<br>(based on community input/suggestions)
**Releases...**<br>FD prototype (v1.80) | v1.8x (based on FD prototype) | v2.0 (based on new design)

### Roadmap - Additional details

***Complete - Spring 2022 (Apr-June)***
- [x] **Develop FD prototype** - Build a FD prototype building upon work from
[prior authors](#morse-runner-release-history).
The approach taken introduces a table-driven
design along with the notion of generalized exchange fields (e.g Exch1=3A, Exch2=OR).
Contests include CQ WPX, CWOPS CWT, ARRL FD, NCJ NAQP, and HST.
Contest is selected using a drop-down list.
This prototype was shared with a few individuals in early June.

***Now - Summer 2022 (July-Sept)***
Projects we are currently working on...
- [ ] **Develop Community Guidelines** - Discuss and adopt community guidelines
for contributing to this project, including roles, code of conduct, best practices, guidelines,
expectations, adherence to standards, etc.

- [ ] **Launch Community Repository** - Create a single repository containing
most major development projects/branches by various MR authors.
Over time portions these projects, including individual features and bug fixes,
can be independently extracted and merged into a common development branch.

- [ ] **Invite prior authors** - Invite all known MR authors to join and contribute
to this effort.
Encourage them to at least connect as a "Watcher" of this project and share any
personal knowledge they may have with this project.

- [ ] **Standardize git setup** - Resolve git setup issues with CRLF caused by different git
setups on individual computers and git setups. Document recommended setup for future work.
Document this issue so other developers can understand avoid this issue.

- [ ] **Release FD prototype (v1.80)** - Release the FD prototype to allow others to see the
general direction of the project and solicit early feedback. Release expected mid-Sept 2022.

- [ ] **Solicit early feedback** - Invite users to try the FD prototype and provide
early feedback. Discussions can occur within github regarding this prototype and
future directions.
Ask users to suggest which contests should be added next.

***Next - Fall 2022 (Oct-Dec)***
Projects we will work on next...

- [ ] **Foster Community Growth** - We are looking for ways to grow this community.
To achieve this, we want to adequately document this project by improving
community documentation, including README.md, CONTRIBUTING.md, etc., files.
Once complete, we will reach out to various user communities
(e.g. N1MM forums, and perhaps specific clubs).

- [ ] **Multi-contest design** - Discuss the design approach for supporting multiple
contests within Morse Runner based on FD prototype.
Look for patterns across multiple contests and propose interface(s) to be used
to generalize an individual contest.

- [ ] **Add a few more contests** -
Implement one or two more popular contests.
Consider adding ARRL Sweepstakes; however this one might be a little harder since
it has a complex exchange.

- [ ] **Merge selected features and bug fixes** - Identify and integrate features from
[other MR branches](#morse-runner-release-history) into the main release branch.

***Later - 1st Half 2023 (Jan-June)***

Projects that we'll work on later...
- [ ] **Team-based (developer/advocate) contest development model** - promote the notion of a small contest development team consisting of a developer and one or more user/advocates.
This team will develop and test an individual contest before it is released for general use.
Please review Issues pages for contest recommendations and add a comment to your favorite contests. Also mention if you're interested in either an advocate or developer role for this contest. As a point of reference, adding the NAQP contest to the FD prototype codebase was completed in one afternoon.

- [ ] **Multi-contest implementation** - finish the initial implementation of the
multi-contest codebase. Major interfaces are developed and running. Contests are
added by extending these interfaces only. Most switch states in code have been removed.

- [ ] **Maintain existing integration with N1MM and DxLog.**
N2IC has done work to integrate Morse Runner within N1MM and DxLog.
We want to continue this work to allow Morse Runner to run with these
popular logging programs.
   
- [ ] **Add additional contests** - by now, adding a contest should be fairly straight-forward.
Perhaps adding a contest will need two people, a contest developer and a contest advocate.
This team can develop and test a contest before releasing to general use.

***Future***
- [ ] **Project Wiki** - Explore idea of developing a project wiki containing additional
project details, including recommended setups (both developer and user),
design discussions, compile instructions, coding standards, release criteria, etc.
This will also include details on adding a new contest to Morse Runner.
Is this implemented within github or elsewhere?

- [ ] **User-defined contests** - Explore notion of user-defined contests using a contest configuration file. Perhaps a yaml file? Can this be similar to N1MM contest definition file?

# History
TODO - add a paragraph or two regarding the history of MR.

> VE3NEA, of CW Skimmer fame, was the original author of MorseRunner. 9A5K later made some changes and interfaced it with DXLog.Net. Later, I ported it to a development environment that was free (instead of $500) and interfaced it to N1MM+. Many thanks to K1XM for letting me peruse the DXLog.Net code.
> <br>**Source:** [Steve London, N2IC, N1MMLoggerPlus forum](https://groups.io/g/N1MMLoggerPlus/topic/n1mm_morserunner_field_day/92010360?p=,,,20,0,0,0::recentpostdate/sticky,,,20,2,100,92010360,previd%3D1656505378749563661,nextid%3D1656224384912816884&previd=1656505378749563661&nextid=1656224384912816884).

## Morse Runner Release History
The following table shows the release history of Morse Runner.
Links are provided back the commit history page of the corresponding github repository.
Please update this table if you find additional versions.
> It is interesting to note that with all the independent work on Morse Runner
over the years, there have been no duplicate version numbers.

Date           | Repo/Author   | Version/Link   | Features/Contests
---------------|----------|:---------:|---------
2004-201x      | VE3NEA   | 1.1-1.6x  | original version, CQ WPX, HST.
unknown        | 9A5K (sk)| unknown   | additional changes; interface with DXLog.Net.
June 2015      | VE3NEA   | [1.68](https://github.com/ve3nea/MorseRunner/commits/master)      | bug fixing; last release by Alex.
Nov 2015       | DF9TS    | no release| Ansi support, some changes to Log display window.
July 2016      | BH1SCW (BG4FQD)   | [1.69](https://github.com/BH1SCW/MorseRunner/commits/master)      | adds Hi-Score web page, Unicode support
Aug 2016       | BH1SCW (BG4FQD)   | [1.70](https://github.com/BH1SCW/MorseRunner/commits/master)      | show callsign info in status window
Sept-Nov 2016  | BH1SCW (BG4FQD)   | [1.71](https://github.com/BH1SCW/MorseRunner/commits/master)      | bug fixes
Jan 2017       | BH1SCW (BG4FQD)   | [1.72](https://www.bh1scw.com/mr/score)      | bug fix/ export qso/ PgUp,PgDn functions/ prefix judgment/ slow cw settings
Oct 2018       | F6FVY    | [1.68.2+](https://github.com/f6fvy/MorseRunner/commits/master)   | New callers are added after qso, F1 improvements, speed increment/decrement, remove beep after qso.
Oct 2018       | F6FVY    | [1.68.3+](https://github.com/f6fvy/MorseRunner/commits/master)   | improve F7 ('?') to cause Dx stations to call again.
Nov 2018       | F6FVY    | [1.68.4+](https://github.com/f6fvy/MorseRunner/commits/master)   | mouse wheel controls RIT, callsign lookup using master.dta.
Oct 2018       | N2IC     | [1.68+](https://github.com/n2ic/MorseRunner/commits/master)     | f6fvy's DxCount bug fix
April 2020     | N2IC     | [1.70+](https://github.com/n2ic/MorseRunner/commits/master)     | adds CQ WW, allow 2 instances of MR to be running (one for each radio w/ N1MM).
May 2020       | N2IC     | [1.70+](https://github.com/n2ic/MorseRunner/commits/master) ??  | (#3,#4) bug fixing, msgTU from N1MM
May 2020       | N2IC     | [1.70+](https://github.com/n2ic/MorseRunner/commits/master) ??  | (#5, #6, #7) bug fixing, msgTU from N1MM
Jan 2021       | N2IC     | [1.70+](https://github.com/n2ic/MorseRunner/commits/master) ??  | (#8) Add set pitch handler for side tone frequency
Nov 2021       | CT7AUP   | 1.71a     | CWOPS CWT Contest, CW Rx Speed adjust.
Jan 2022       | JR8PPG   | [JA-1.68.1](https://github.com/jr8ppg/MorseRunner/commits/master) | MorseRunnerJA - JARL All Japan.
Feb 2022       | JR8PPG   | [JA-1.68.2](https://github.com/jr8ppg/MorseRunner/commits/master) | MorseRunnerJA - JARL All Japan, ACAG, and CQ Wpx.
June 2022      | zmetzing | [1.68z](https://github.com/zmetzing/MorseRunner/commits/master) | Linux port of VE3NEA's 1.68 codebase.
Summer 2022    | W7SST    | 1.80      | FD prototype with CQ WPX, CWOPS CWT, ARRL FD, and NCJ NAQP. Release is planned by mid-Sept 2022.
Winter 2022    | W7SST    | 1.81      | First general release, adds CQ WW, and perhaps ARRL Sweepstakes.

# To Do
- [x] Update MR History section
- [ ] what other sections or topics should be included here?
- [ ] Reach out to VE3NEA to see if he has any documentation, materials, or old emails
  that can be added to the wiki.
- [ ] Explore using Mermaid or PlantUML languages for adding diagrams to this documentation. Perhaps the Roadmap itself can be generated using PlantUML Ghant chart syntax. Or, we look into using GitHub's project boards.
