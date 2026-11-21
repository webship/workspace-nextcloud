---
name: nextcloud-scenarios
description: Write webship-js scenarios for a Nextcloud file and collaboration server of the Webship Workspace from phrases that exist — the Nextcloud step pack's steps by area (the session and the forgotten password, the header and the dashboard, Files, sharing and public links, the viewers, the unified search, notifications, the activity stream, the personal settings and the accounts page), the handles of the users registry, the test-data steps that take away what they make, the traps found on a real server, and three features that pass on a site built with the default accounts. Use when writing or fixing a scenario for the file server, choosing a step for one of its apps, or turning a manual check of the server into a feature.
---

# nextcloud-scenarios

Scenarios for a site built with the Nextcloud plugin (`bash cmd-nextcloud-project.sh <site> --install --add-users`)
in a container-based workspace (DDEV by default), tested with webship-js and `@webship-js/nextcloud-steps` once
`bash cmd-tools-testing.sh <site>` set the project up. Every phrase below exists in the pack or in webship-js; a
scenario names no platform.

## Accounts and test data

- `Given I am a logged in user with the "user" user`: `administrator` (in the admin group), `editor`, `user` (each
  an account of its own). `Given I am not logged in` for a visitor; `Given I am on the login page` for the form.
- `Given "user" has the file "meeting-notes.md"` (`… in the folder "Project files"`), `Given "user" has the folder
  "Project files/Reports"`, `Given "user" has shared the file "team-photo.png" with "editor"`, `Given "user" has the
  notification "Quarterly review is due"` (`… saying "…"`): made through the server's own APIs, taken away after the
  scenario.
- The pack's own files: `meeting-notes.md`, `budget.txt`, `team-photo.png`, `annual-report.pdf` (two pages, the first
  says "Annual report 2026"). A file of the project goes in `tests/assets/`.
- What a scenario adds or changes on screen is taken back after it: its files and folders, its shares, its
  notifications, a field of the profile, the theme, the status, the layout of the dashboard, a password.

## Phrases by area

| Area | Steps |
| --- | --- |
| Session | `I am on the login page`, `I go to the login page`, `I log in as "user" with the login form`, `I log in with the username "…" and the password "…"`, `the login should be refused with "Wrong login or password."`, `I log out`, `I should be logged in`, `I should be logged in as "user"`, `I should not be logged in`, `I should be on the login page` |
| Forgotten password | `I ask for a password reset link for "user"`, `an email about "password reset" should be sent to "user"`, `no email should be sent to "nobody@example.com"`, `I open the password reset link of the email to "user"`, `I choose the new password "…"` |
| Header | `I open the "Files" app`, `I should be in the "Files" app`, `the apps menu should list "Activity"` (`should not list`), `the user menu should offer "Accounts"` (`should not offer`), `I choose "Settings" in the user menu`, `I set my status to "Away"`, `my status should be "Away"`, `I should see the error page "Access forbidden"` |
| Dashboard | `I go to the dashboard`, `the dashboard should greet "User"`, `the dashboard should show the "Recommended files" widget` (`should not show`), `I add the "Favorite files" widget to the dashboard`, `I remove the "…" widget from the dashboard`, `the "Favorite files" widget should list "…"`, `the "Favorite files" widget should say "No favorites"` |
| Files | `I go to the files`, `I go to the folder "Project files/Reports"`, `I open the folder "Project files"`, `I open the "Favorites" files view` ("Shared with you", "Recent", "Deleted files"…), `I go to the deleted files`, `the file list should show "…"` (`should not show`), `the file list should be empty`, `I upload the file "meeting-notes.md"`, `I create the folder "…"`, `I rename "…" to "…"`, `I move "…" to the folder "…"`, `I copy "…" to the folder "…"`, `I delete "…"`, `the deleted files should list "…"` (`should not list`), `I restore "…" from the deleted files`, `I add "…" to the favorites`, `I remove "…" from the favorites`, `"…" should be marked as a favorite` (`should not be`), `a message "Delete file: done" should pop up` |
| Details | `I open the details of "…"`, `the details should show "User"`, `I open the "Activity" tab of the details`, `the details tab should show "You created meeting-notes.md"`, `I close the details` |
| Sharing | `I share "…" with "editor"` (`… as "View only"`), `"…" should be shared with "editor"` (`… as "View only"`, `should not be shared`), `I create a public link for "…"`, `I protect the public link of "…" with the password "…"`, `I set the public link of "…" to expire in 30 days`, `the public link of "…" should expire in 30 days`, `I open the public link of "…" as a visitor`, `I should be asked for the password of the share`, `I enter the share password "…"`, `the share password should be refused`, `the shared file "…" should be shown` |
| Viewers | `I open the file "…"`, `the viewer should show the image "…"`, `the viewer should show the PDF "…"`, `the PDF should have 2 pages`, `the PDF should show "…"`, `the viewer should show the text "…"`, `I close the viewer` |
| Search | `I search for "team" in the unified search`, `the unified search should find "team-photo.png" in "Files"` (`should not find`, `in "Apps"`), `the unified search should find nothing`, `I open the search result "…"` |
| Notifications | `I open the notifications`, `the notifications should show "…"` (`should not show`), `I dismiss the notification "…"`, `I dismiss all notifications`, `I should have no notifications` |
| Activity | `I go to the activity stream`, `I filter the activity stream by "File changes"`, `the newest activity should be "You created meeting-notes.md"`, `the activity stream should show "…"` (`should not show`) |
| Personal settings | `I go to the personal settings`, `I open the "Security" section of the personal settings`, `I set my "Headline" to "…"`, `my "Headline" should be "…"`, `I change my password to "…"`, `I change my password with the wrong current password "…"`, `I choose the "Dark theme" appearance`, `the "Dark theme" appearance should be in use` |
| Accounts page | `I go to the accounts page`, `the account list should show "editor"` (`should not show`), `the account "administrator" should be in the group "admin"` (`should not be`), `I search the accounts for "edit"`, `I open the "Admins" account list`, `I try to create the account "editor"`, `the new account should be refused with "User already exists"` |

## A scenario, start to end

A public link with a password and an end date, opened by a visitor in a browser of its own:

```gherkin
Feature: Public links
  Scenario: A visitor needs the password of the link
    Given "user" has the file "team-photo.png"
    And I am a logged in user with the "user" user
    When I go to the files
    And I create a public link for "team-photo.png"
    And I protect the public link of "team-photo.png" with the password "Webship-Share-2026"
    And I set the public link of "team-photo.png" to expire in 30 days
    Then the public link of "team-photo.png" should expire in 30 days
    When I open the public link of "team-photo.png" as a visitor
    Then I should be asked for the password of the share
    When I enter the share password "Wrong-password-1"
    Then the share password should be refused
    When I enter the share password "Webship-Share-2026"
    Then the shared file "team-photo.png" should be shown
```

Three whole features that pass on a site built with `--install --add-users`: `examples/files.feature`,
`examples/sharing.feature` and `examples/account.feature`. Copy one into `tests/features/` and run it with
`bash cmd-tools-testing.sh <site> --run --path tests/features/<name>.feature`.

## Traps found on a real server

- Each app (Files, Activity, Settings, the dashboard) is a single-page app: the steps wait for its own loading icon
  and its own requests (a WebDAV PROPFIND for a folder), never for the clock. The activity stream keeps a "Loading
  more activities" icon at its foot while more can load: that one is no work in progress.
- The Sharing tab of the details is a custom element whose `shadowRoot` is the element itself: a Playwright locator
  that pierces shadow roots (role, text or CSS) can run into it without end. The pack's sharing steps use XPath and
  the page's DOM there; a scenario of your own uses the pack's sharing steps, not generic clicks, in that tab.
- A message that pops up ("Delete file: done", "Wrong password") lives about seven seconds: check it in the step right
  after the action.
- The activity stream keeps every run's history: assert the newest activity, not one that any earlier run also made.
- A file a scenario uploads must not be in the folder yet (the upload would ask what to do with it): the clean-up
  takes away what every scenario adds, and `bash cmd-tools-nextcloud-occ.sh <site> --empty-files` clears what an
  interrupted run left.
- Error pages and refusals (403, 404, a taken account name) make the browser log the refused request: tag those
  scenarios `@js-off`.

## The book

For any automated functional testing in this work (a Gherkin feature, a step definition, choosing a
step, a test run and its failures), read the book *Automated Functional Testing Recipes* first.

- **Where.** Use the first that exists: `.claude/automated-functional-testing-recipes/` in the project,
  `~/.claude/automated-functional-testing-recipes/` (installed by webship/webship-js-ai-agent,
  webship/webship-js-skills or webship/ai-agents), or
  https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes
- **How.** Its `README.md` first, then the chapter that matches the task (one file per chapter,
  named by its subject), not the single complete file.
- **Which wins.** The installed webship-js package and the step pack are the source of truth for
  step phrasing. When they differ from the book, follow them and say so.
- **For the file server.** Start with `ch10-authentication-authorization.md` (logins, sessions and refusals),
  `ch07-waiting-dynamic-content.md` and `ch27-testing-spa.md` (each app is a single-page app: wait on its own
  signals), and `ch20-design-patterns-for-tests.md` (test data a scenario makes and takes away).
