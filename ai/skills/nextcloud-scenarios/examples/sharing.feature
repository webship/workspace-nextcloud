@sharing
Feature: Sharing with an account and with a public link
  A share made on screen and found by the other account, and a public link with a password opened by a visitor.

  Scenario: The other account finds the file shared with it
    Given "user" has the file "meeting-notes.md"
    And I am a logged in user with the "user" user
    When I go to the files
    And I share "meeting-notes.md" with "editor" as "View only"
    Then "meeting-notes.md" should be shared with "editor" as "View only"
    Given I am a logged in user with the "editor" user
    When I open the "Shared with you" files view
    Then the file list should show "meeting-notes.md"

  Scenario: A visitor needs the password of the link
    Given "user" has the file "team-photo.png"
    And I am a logged in user with the "user" user
    When I go to the files
    And I create a public link for "team-photo.png"
    And I protect the public link of "team-photo.png" with the password "Webship-Share-2026"
    And I set the public link of "team-photo.png" to expire in 7 days
    And I open the public link of "team-photo.png" as a visitor
    Then I should be asked for the password of the share
    When I enter the share password "Webship-Share-2026"
    Then the shared file "team-photo.png" should be shown
