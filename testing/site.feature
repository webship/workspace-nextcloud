Feature: The file server answers and its accounts work
  As the owner of the file server
  I want the login, each default account, a file and the accounts page to work
  So that a build that came out broken is caught before anything else is tested

  # Placed by the workspace's testing setup as a starting point: it is yours to change.
  # The accounts are the default ones (cmd-tools-nextcloud-occ.sh --add-users); a scenario logs in by a handle of the
  # users registry in cucumber.js, so no password is written here. It passes on a site built with --install --add-users.

  @critical
  Scenario: A visitor is sent to the login page
    Given I am not logged in
    Then I should be on the login page

  Scenario Outline: The <account> account logs in with the login form
    Given I am not logged in
    When I log in as "<account>" with the login form
    Then I should be logged in as "<account>"
    And I should be in the "Dashboard" app

    Examples:
      | account       |
      | administrator |
      | editor        |
      | user          |

  Scenario: A wrong password is refused
    Given I am on the login page
    When I log in with the username "user" and the password "Wrong-password-1"
    Then the login should be refused with "Wrong login or password."

  Scenario: A file is uploaded and opened in the viewer
    Given I am a logged in user with the "user" user
    When I go to the files
    And I upload the file "team-photo.png"
    And I open the file "team-photo.png"
    Then the viewer should show the image "team-photo.png"

  # The browser logs the refused request (403).
  @js-off
  Scenario: Only an administrator reaches the accounts page
    Given I am a logged in user with the "user" user
    When I go to the accounts page
    Then I should see the error page "Access forbidden"
