# Contributing to Morse Runner CE
Morse Runner CE is a community-maintained project and we happily accept contributions.
Thank you for your interest in Morse Runner and taking the time to contribute.

We are looking for the following types of people:
- **Maintainers** - Contributors who are responsible for driving the vision and
managing the organizational aspects of the project.
(requires collaborator permissions.)
- **Contributors** - Everyone who has contributed something back to the project.
They might contribute to coding or testing, write documentation
or develop training materials, etc.
- **Community Members** - People who use the project.
They might be active in conversations or express their opinion on the project’s direction.

Please feel free to join in at whatever level you are comfortable.

The following is a set of guidelines for contributing to Morse Runner CE.
These are mostly guidelines, not rules.
Use your best judgement, and feel free to propose changes to this document
in a pull request.

> This file will help people contribute to the project. It explains what types of contributions are needed and describes how the process works.

> You should try to build a draft of the CONTRIBUTING.md file with the core contributors to your project to help them feel a shared sense of responsibility and to create the best possible guide for encouraging new contributors. It is sometimes best to practice building a markdown file in an offline program like Mou or an online one like Dilliger before you post it online.   
**Source**: https://mozillascience.github.io/working-open-workshop/contributing/

> Much of this document is inspired by https://github.com/atom/atom/blob/master/CONTRIBUTING.md.

#### Table of Contents
[Code of Conduct](#code-of-conduct)

[What should I know before I get started?](#what-should-i-know-before-i-get-started)
- [I'm new to open source software?](Im-new-to-open-source-software)

[How can I contribute?](#how-can-i-contribute)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Enhancements](#suggesting-enhancements)
- [Your First Code Contribution](#your-first-code-contribution)
- [Pull Requests](#pull-requests)

[Developer Guidelines](#developer-guidelines)

[Styleguides](#styleguides)
- [Changelog entries](#changelog-entries)
- [Git Commit messages](#git-commit-messages)
- [Coding Guidelines](#coding-guidelines)

[Additional Notes](#additional-notes)
- [Issue and Pull Request Labels](#issue-and-pull-request-labels)

[Additional Resources](#additional-resources)
- [Compilation Instructions](#compilation-instructions)
- [Open Source Software](#open-source-software)
- [Project Maintainers](#project-maintainers)
- [Project Contributors](#project-contributors)

[Credits & Attribution](#credits-and-attribution)

## Code of Conduct
This project and everyone participating in it is governed by the
[Morse Runner Code of Conduct](TODO https://github.com/w7sst/MorseRunner/CODE_OF_CONDUCT.md).
By participating, you are expected to uphold this code.
Please report unacceptable behavior to (TODO).

## What should I know before I get started?

### I'm new to open source software

If you are new to open source software, please read
[How to Contribute to Open Source](https://opensource.guide/how-to-contribute/)
and other resources by [Open Source Guides](https://opensource.guide).
See [Additional Resources](#additional-resources) section below for additional information.

## How can I Contribute?

If you wish to fix a bug, add a new feature or contest, provide documentation, develop training materials, or help in any way, these steps will get you started.

> The [atom editor project](https://www.github.com/atom/atom/) has provided some good content
[here](https://github.com/atom/atom/blob/master/CONTRIBUTING.md).
Their material applies to our project as well. Much of their material and text
has been reproduced below.

### Reporting Bugs (Opening an Issue)

1. Check for open issues or open a fresh issue to start a discussion around
a feature idea or a bug.

TBD...
<br>
**Possible Source:** https://github.com/atom/atom/blob/master/CONTRIBUTING.md

### Suggesting Enhancements (or Contests)

TBD...
<br>
**Possible Source:** https://github.com/atom/atom/blob/master/CONTRIBUTING.md

### Your First Code Contribution (Opening a Pull Request and making changes)

1. **Select an issue** you would like to work on.
Change the [issue state](#issue-state) to "active" to indicate you are
actively working on this issue.
There is a [good first issue](#issue-attributes) label for issues that should be
ideal for people who are new to the MorseRunner project and code base.
 
1. [Fork the respository](https://guides.github.com/activities/forking/) and
clone it locally. Connect your local to the original "upstream" respository
by adding it as a remote. Pull in changes from "upstream" often so that you stay
up to date so when you submit your pull request, merge conflicts will be less likely.
(See more detailed instructions [here](https://help.github.com/articles/syncing-a-fork).)

1. **Open a pull request** to track the work associated with the issue you have selected. See [Pull Requests](#pull-requests) below for more information.
Reference the issue # on which you are working.

1. [Create a branch](https://guides.github.com/introduction/flow/) for your changes.
Please follow the additional [developer guidelines](#developer-guidelines) below.

1. **Contribute in the style of the project** to the best of your abilities.
This may mean using indents, semi-colons or comments differently than you would
in your own repository, but makes it easier for the maintainer to merge,
and for others to understand and maintain in the future.
See [developer guidelines](#developer-guidelines) below for more information.

1. [future] [Develop unit tests](#general-guidelines) to exercise the new
functionality. Some low-level code can be tested at the unit-test level.

1. Add a [changelog entry](#label-changelog) and update [Readme.txt](TODO) as appropriate.

### Pull Requests
A pull request is used to track work being done within the project.
When you start working on a specific issue, create a pull request and
indicate which issue you are working on.
Keep the PR update-to-date during your development to notify others of
your progress.
If a larger change, you can push your branch so others can have an early-look
at your changes.
When your work is complete, the PR will be submitted for review by one or
more of the reviewers.

1. **Reference any relavent issues** or supporting documentation in your PR (for example, "Closes #13.") Usually a PR has an associated Issue #.

1. **Include screen shots of the before and after** if your change involves changes to the UI.
Drag/drop the changes into your pull request.

1. **Test your changes!** Please test your changes to best extent possible as there is no formal
test plan or test suite for this project. Consider asking the issue's author if they are available
for early testing. If so, push your branch and let them test it.

1. **Send the completed pull request** when your work is complete.
This notifies the maintainer of your pending contribution who will in turn merge
and publish your changes.
This may be an iterative process if others have found issues or have recommendations for
additional changes.
   - [ ] TODO - verify that this is how the process actually works.

## Developer Guidelines
As contributors, we should adopt reasonable open source
development processes and conventions.
As a starting point, we can draw from www.opensource.guide.
These guidelines are recommendations, not rules. Please use your own judgement.

- [ ] TODO - identify other sources/examples of community development guidelines
and best practices for open source projects.
- [ ] TODO - pull in examples and table of contents from atom project (see below)

### General Guidelines
1. **Use feature branches.** Each enhancement should be developed on a separate feature branch.
Each branch can independently reviewed and tested before integration into main branch.
The idea is to keep each feature small and independent.
This is a common open source approach with multiple contributors and allows easy
code review and integration by other community members and maintainers.

1. **Open new issues.** whenever new unrelated problems or bugs are found during development.
Avoid going beyond the scope of the current problem when working on an issue.

1. **Unit Testing.** [future] When and where appropriate, develop [unit tests](#unit-testing)
to fully test low-level modules and if possible, show that a feature or behavior is
working as expected.
An example would be exercising the function that looks for a partial match of a
user-entered string against a given callsign.
   - [ ] TODO - develop unit test capability within Morse Runner.

1. **Code reviews** by other developers, project maintainers, and/or community members
should be performed on the feature branch as part of submitting the pull request.
Doing so will help maintain a solid code base.
Reviews also serve as a good way to learn details of the project.
Reviewers are looking for bugs and adherance to coding standards.
Additional code changes are often made after a review to incorporate suggested
improvementment and/or suggestions.
Some reviewers may even contribute specific code changes as part of the review.
Code reviews will typically occur near the end of development or after
submitting your PR (Pull Request) for review.
   - [ ] TODO - We need to define how/when the code review occurs.
Github has tools to facilitate code reviews.
We need to find and adopt these tools and perhaps setup a automated processes if possible.

1. **Code refactoring** is encouraged and should alway be performed independent of
feature development or bug fixing.
If working on a feature and you discover a refactoring opportunity,
please do this refactoring using a separate feature branch before completing
work on the current feature.

1. **Avoid reformatting of existing code** (e.g. changing indentation, if/then/else alignment, etc.).
Doing so make it really hard to merge and compare code.
    a. When modifying existing code, following the coding style of the original author.
    a. When writing a new module/unit, following recommended coding guidelines.
    a. Short term, we may remove code reformatting to make it easier to compare/merge code as needed.
    a. Long term, after most branches have been merged, we can consider code reformatting.

1. **Design Changes.** Please discuss any design changes with the project maintainers
before making these changes. If a pull request arrives without a prior discussion
regarding design or direction changes, the request will probably be denied.
We are open to design proposals and changes, but we do request that such changes
are discussed early. Please open an Issue do we can let the design discussion occur
and allow the design idea/proposal to evolve into something that we can agree to.

## Styleguides

### Changelog entries
- [ ] TODO - define how/where changelog entries are managed.
   a. If fixing a bug, mention the fix in the changelog file. TODO - what file?
   a. If adding a new feature, mention the enhancement in the changelog file.
   a. If appropriate, summarize the feature in Readme.txt.

### Git Commit messages
TODO...

### Coding Guidelines
TODO...

## Additional Notes

### Issue and Pull Request Labels
This section lists the labels we use to track and manage issues and pull requests.

GitHub search make it easy to use labels for finding groups of issues or pull requests
you're interested in.
For example, you might be interested in beginner issues or perhaps open pull requests which
haven't been reviewed. To help you find issues and pull requests, each label is listed
with a search link for finding open items with that label.
See [other search filters](TODO) which will help you write more focused queries.

We will grow these labels over time as we better understand this process and how to use them.
Please open an issue if you have suggestions for new labels.

#### Issue Type
Label name | Search | Description
-----------|--------|------------
`bug` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3Abug) | Confirmed bugs or reports that are very likey to be bugs.
`documentation` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3Adocumentation) | Related to any type of documentation.
`enhancement` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3Aenhancement) | New feature or requests, including contest nominations.
`feedback` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3Afeedback) | General feedback; more than bug reports and feature requests.
`question` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3Aquestion) | Further information is requested. Questions that are more than bug reports or feature requests.
`training` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3Atraining) | Related to any type of training or presentation material (e.g. club presentation).

#### Issue Attribute
Label name | Search | Description
-----------|--------|------------
`good first issue` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3A"good+first+issue") | Less complex issues which would be good first issues to work on for users who wanted to contribute to MorseRunner.

#### Issue State

Label name | Search | Description
-----------|--------|------------
`active` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3Aactive) | Issues being actively worked on by a community member.
`blocked` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3Ablocked) | Issues blocked on other issues.
`confirmed` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3Aconfirmed) | Issues have been confirmed and ready to be fixed/implemented.
`duplicate` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3Aduplicate) | This issue or pull request already exists.
`help wanted` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3A"help+wanted") | Extra attention is needed. The MorseRunner team would appreciate help from the community in resolving these issues.
`invalid` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3Ainvalid) | Issues which aren't valid (e.g. user errors).
`more information needed` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3A"more+information+needed") | Likely bugs, but haven't been reliably reproduced.
`wontfix` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3Awontfix) | The MorseRunner reviewer team has decided not to fix these issues now, either because they're not working as intended or for some other reason.

#### Topic Categories
Label name | Search | Description
-----------|--------|------------
`contest` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3Acontest) | Related to behavior associated with a particular contest.
`crash` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3Acrash) | Report of MR completely crashing.
`git` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3Agit) | Related to Git functionality (e.g. .gitignore files or showing correct file status)
`hst` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3Ahst) | Related to High Speed Test (HST) mode, including posting high scores to internet.
`n1mm` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3An1mm) | Related to N1MM integration
`ui` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3Aui) | Related to user interface or menus
`windows` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3Awindows) | Related to MorseRunner running on Windows

#### Pull Request Labels
Label name | Search | Description
-----------|--------|------------
`needs review` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3A"needs+review") | Pull requests which need code review, and approval from maintainers.
`needs testing` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3A"needs+testing") | Pull requests which need manual testing.
`requires changes` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3A"requires+changes") | Pull requests which need to be updated based on review comments and then reviewed again.
`under review` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3A"under+review") | Pull requests being reviewed by maintainers.
`work in progress` | [search](https://github.com/search?q=is%3Aopen+is%3Aissue+repo%3Aw7sst%2FMorseRunner+label%3A"work+in+progress")  | Pull requests which are still being worked on, more changes will follow.

## Additional Resources
Initially, we have added lots of links here to get you started.
We welcome any contributions or changes to this section - please submit a pull request
if interested. Thank you! :tada:

### Compilation Instructions
TODO - write install, setup and compilation instructions.

### Open Source Software
The following resources are available to learn more about Open Source Software in general.
- [Open Source Guides](https://opensource.guide) - they publish several guidebooks on various
aspects of Open Source Software develoment:
   - [How to Contribute to Open Source](https://opensource.guide/how-to-contribute/) - good for those new to open source.
   - [Starting an Open Source Project](https://opensource.guide/starting-a-project/) - ideas and suggestions used to get this project off the ground.
   - [Finding Users for Your Project](https://opensource.guide/finding-users/) - how to grow your project.
   - [Building Welcoming Communities](https://opensource.guide/building-community/) -
   - and [others](https://opensource.guide/).

- [GitHub Get Started](https://docs.github.com/en/get-started) -
A good starting point to learn about git and GitHub.

   - [GitHub Quickstart Guide](https://docs.github.com/en/get-started/quickstart) -
Using GitHub to manage Git repositories and collaborate with others.
Provides an extensive overview of github and using git.

   - [GitHub Flow](https://docs.github.com/en/get-started/quickstart/github-flow) -
GitHub describes their common GitHub Flow for making changes, managing issues and pull requests.
This project will follow this flow.

- [Github Skills](https://skills.github.com/) - Learn how to use GitHub with interactive courses designed for beginners and experts.

- [Markdown Guide](https://www.markdownguide.org/) -
Our documentation, including Issues and Pull Requests, is written using markdown syntax.
This site describes the markdown syntax, including basic and extended syntax.

- See also:
   - https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax
   
### Project Maintainers
Project maintainers are given read/write access to the repository.
The following articles will help you better understand this role.
- [Collaborator access for a repository owned by a personal account](https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-personal-account-on-github/managing-personal-account-settings/permission-levels-for-a-personal-account-repository#collaborator-access-for-a-repository-owned-by-a-personal-account).

- [Best Practices for Maintainers](https://opensource.guide/best-practices/) - good for project leaders and maintainers of Morse Runner CE.

- [How to maintain open source projects](https://www.digitalocean.com/community/tutorials/how-to-maintain-open-source-software-projects)

- [Managing labels](https://docs.github.com/en/issues/using-labels-and-milestones-to-track-work/managing-labels)
- https://www.jeffgeerling.com/blog/2016/why-i-close-prs-oss-project-maintainer-notes
- https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file

### Project Contributors
- https://docs.microsoft.com/en-us/contribute/
- https://urllib3.readthedocs.io/en/latest/contributing.html
- https://coda.io/@mahavir/working-with-multiple-forks - Ideas for working with multiple forks.
- https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/setting-guidelines-for-repository-contributors
- https://docs.github.com/en/search-github/searching-on-github/searching-issues-and-pull-requests

## Credits & Attribution
We'd like to "tip our hats" and say "Thank you!" and acknowledge the following projects
for providing insight into starting and supporting our community-maintained open source project.
- https://opensoure.guide
- https://github.com/atom/atom/blob/master/CONTRIBUTING.md
- https://mozillascience.github.io/working-open-workshop/contributing/ -
How to build a contributing.md, including training for open source projects;
includes nine presentations and handouts.
- https://urllib3.readthedocs.io/en/latest/contributing.html

### Miscellaneous Notes
Other good sources to pull ideas from:

#### Sources - Code of Conduct
- https://opensource.guide/code-of-conduct/
- https://opensourceconduct.com/corecoc
