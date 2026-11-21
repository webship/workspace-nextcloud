@files
Feature: Files of an account
  Upload, a folder, a move, the deleted files and a favorite, with the files the step pack ships.

  Scenario: A file is uploaded into a new folder
    Given I am a logged in user with the "user" user
    When I go to the files
    And I create the folder "Project files"
    And I open the folder "Project files"
    Then the file list should be empty
    When I upload the file "meeting-notes.md"
    Then the file list should show "meeting-notes.md"

  Scenario: A deleted file comes back from the deleted files
    Given "user" has the file "budget.txt"
    And I am a logged in user with the "user" user
    When I go to the files
    And I delete "budget.txt"
    And I go to the deleted files
    Then the deleted files should list "budget.txt"
    When I restore "budget.txt" from the deleted files
    And I go to the files
    Then the file list should show "budget.txt"

  Scenario: A favorite, and the PDF viewer
    Given "user" has the file "annual-report.pdf"
    And I am a logged in user with the "user" user
    When I go to the files
    And I add "annual-report.pdf" to the favorites
    Then "annual-report.pdf" should be marked as a favorite
    When I open the file "annual-report.pdf"
    Then the viewer should show the PDF "annual-report.pdf"
    And the PDF should have 2 pages
