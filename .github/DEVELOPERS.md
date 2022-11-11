The purpose of this document is to document the steps for a new developer of this project to get onboarded
to be able to contribute.

1 - The source code for this application is written in the Pascal programming language.
Only Windows operating systems are currently supported as the target platform for the application to operate on.

1 - Fork the repo to your own GitHub account.
git clone https://github.com/<yourAccountName>/MourseRunner.git

1 - Get your IDE (Integrated Development Environment) setup
This project is currently supported with the use of two seperate IDEs for Pascal
- Lazarus version 2.2.4 (fpc 3.2.2)
Lazarus was the original IDE used for MorseRunner by VE3NEA
- Delphi Community Edition (aka RX RAD Studio 10.4)
Delphi CE is free for use by open source projects and Delphi is the perferred IDE at this time
- Install and start Delphi CE 
### TBD how do you configure each IDE?
- To open the project in the IDE Click File then click Open Project
then navigate to where you cloned your MorseRunner repo and
select the 51KB MorseRunner Delphi Project File then click Open.
- To run the source code - Click Run and Run again or click the play icon

1 - Clone your git repo into the IDE

1 - Directory hierarcy
.git - DO NOT TOUCH the contents here is how git does all it's magic
.github - contains support pages
PerlRegEx - TBD
VCL - Visual Component Library who's purpose is TBD
tools - contains verify-normalization.sh script who's purpose is TBD
. - the parent directory of the repo contains the bulk of the source code, configuration and data files
### TBD source directory refactoring. Should we look to put .pas and possibly other files in a src subdirectory?

1 - How to write and contribute unit tests
There aren't any unit tests. This may be added to the roadmap. Code refactoring will be needed to be able to support unit testing.
### TBD add unit testing framework and refactor to support it to the long term roadmap

1 - How to build, run, test the source code

1 - How to build an executable

1 - Production builds are currently created for each release by W7SST
### TBD add automated nightly test builds and versioned release builds to the long term roadmap
### TBD perform builds via github actions? if not then maybe GitLab, Travis or Jenkins?

In conclusion, thank you for volunteering to help improve this project. We all look forward to your contributions!

