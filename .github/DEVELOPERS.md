The purpose of this document is to document the steps for a new developer of this project to get onboarded
to be able to contribute.

1 - The source code for this application is written in the Pascal programming language.
Only Windows operating systems are currently supported as the target platform for the application to operate on.

2 - Create a GitHub account if you don't already have one
Details available at https://docs.github.com/en/get-started/signing-up-for-github/signing-up-for-a-new-github-account

3 - Fork the w7sst/MoreseRunner repo to your own GitHub account.
With your browser got to https://github.com/w7sst/MorseRunner
then click on the fork button near the top right of the page.

4 - Clone your your GitHub account's fork of the repo.
Using GitBash on Windows or a Linx or MacOS terminal clone your fork of repo via the following command
replacing <yourAccountName> with the name of your GitHub account.
git clone https://github.com/<yourAccountName>/MourseRunner.git

5 - Get your IDE (Integrated Development Environment) setup
This project is currently supported with the use of two seperate IDEs for Pascal
- Lazarus version 2.2.4 (fpc 3.2.2)
Lazarus was the original IDE used for MorseRunner by VE3NEA
- Delphi Community Edition (aka RX RAD Studio 10.4)
Delphi CE is free for use by open source projects and Delphi is the perferred IDE at this time
- Install and start Delphi CE 
- To open the project in the IDE Click File then click Open Project
then navigate to where you cloned your MorseRunner repo and
select the VCL/MorseRunnerVcl.dproj (~44KB) which is a Delphi Project File then click Open.
- Build the project via clicking Project then click Build MorseRunnerVcl
- Install packages via clkicking Component on menu then click Install Packages. Click Add (lower right),
navigate to and select VCL/Win32/Debug/MorseRunnerVcl.bpl, click open and click save.
- Reopen the MorseRunner project with the MorseRunner.dproj in the parent directory of the repo
- To run the source code - Click Run and Run again or click the play icon

6 - Directory hierarcy
.git - DO NOT TOUCH the contents here is how git does all it's magic
.github - contains support pages
PerlRegEx - TBD
VCL - Visual Component Library who's purpose is TBD
tools - contains verify-normalization.sh script who's purpose is TBD
. - the parent directory of the repo contains the bulk of the source code, configuration and data files

7 - How to write and contribute unit tests
There aren't any unit tests. This may be added to the roadmap. Code refactoring will be needed to be able to support unit testing.

8 - How to build the source code into an executable via Delphi IDE
On the menu click Project then click Build MorseRunner. That will create MorseRunner.exe in the parent directory of your cloned repo.

9 - How to run and test the source code via Delphi IDE
Click Run and Run again or press F9 which will run it in debug mode. 
If you wish to not run it in debug mode click Run and Run Without Debugging or press Shift+Ctrl+F9

10 - Production builds are currently created for each release by W7SST

In conclusion, thank you for volunteering to help improve this project. We all look forward to your contributions!

