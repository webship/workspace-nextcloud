@account
Feature: The account's own pages
  Notifications, the unified search, the profile and the activity of an account, and the refusal of the accounts page.

  Scenario: A notification is read and dismissed
    Given "user" has the notification "Quarterly review is due"
    And I am a logged in user with the "user" user
    When I open the notifications
    Then the notifications should show "Quarterly review is due"
    When I dismiss the notification "Quarterly review is due"
    Then I should have no notifications

  Scenario: The unified search finds a file and the activity names it
    Given "user" has the file "team-photo.png"
    And I am a logged in user with the "user" user
    When I search for "team" in the unified search
    Then the unified search should find "team-photo.png" in "Files"
    When I go to the activity stream
    Then the newest activity should be "You created team-photo.png"

  Scenario: A field of the profile is saved
    Given I am a logged in user with the "user" user
    When I go to the personal settings
    And I set my "Organisation" to "Webship"
    Then my "Organisation" should be "Webship"

  # The browser logs the refused request (403).
  @js-off
  Scenario: The accounts page is the administrator's
    Given I am a logged in user with the "user" user
    When I go to the accounts page
    Then I should see the error page "Access forbidden"
