Write and run the webship-js scenarios of one area of a Nextcloud file server (Files, sharing, the viewers, search, notifications, activity, settings, the accounts page), from the step pack's own phrases.

The launch command below is for Claude Code, the default; the text between the triple quotes can be given to another AI CLI as it is.

```
claude --permission-mode bypassPermissions """
Write and run the scenarios of <area> for the Nextcloud site <site> of this sites folder
# ~/workspace/<dev|test|sandboxes|demos> · https://<site>.ddev.site · container-based (DDEV by default)
# the area: <login|dashboard|files|sharing|viewers|search|notifications|activity|personal settings|accounts page>
# every phrase from the step pack or webship-js (the nextcloud-scenarios skill lists them by area): never invent a step, never name the platform in a step phrase
# accounts are configuration: never create or delete one in a suite, never write an account's password into a feature; the accounts page is tested read only or through its refusals
# test data through the steps that take it away after the scenario: Given "user" has the file "…", has the folder "…", has shared the file "…" with "…", has the notification "…"
# a feature to write or a run to read: the book Automated Functional Testing Recipes first (its README.md, then the matching chapter), from .claude/automated-functional-testing-recipes/ in the project, ~/.claude/automated-functional-testing-recipes/ or https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes

1. bash cmd-tools-testing.sh <site>
   (once: webship-js, the step pack, the users registry)
2. Open the pages of the area in the Playwright MCP browser, in a tab of your own, as the account each scenario uses; note what a person reads.
3. Write tests/features/<area>.feature from those notes: one scenario per behaviour, the test-data steps for what a scenario needs.
4. bash cmd-tools-testing.sh <site> --dry-run --path tests/features/<area>.feature
5. bash cmd-tools-testing.sh <site> --run --path tests/features/<area>.feature
6. Run it a second time: it must pass again (the steps take away what a scenario added or changed).

If a scenario fails, read its message and its screenshot, look at the page again in the browser, then fix the scenario, not the step pack.
When the feature is green twice: the scenarios, the steps, and anything the pages did that surprised you.
"""
```
