# Converted from the communitybot legacy tests by kora-qa-panel/scripts/convert-legacy.mjs.
# The """ block under each Scenario is the original test text, verbatim. Review before applying.
Feature: kora_drugs — Crime

  @kora_drugs @checklist @checklist:kora_drugs:drug-creator @cat:crime @needs:admin
  Scenario: /drugCreator admin tool
    """
    Checklist test: As admin run /drugCreator; add/edit/remove drug steps, locations, recipes and plant spots; changes apply live.
    """
    When I run the command "/drugCreator"
    Then the "kora_drugs:creator" app opens
    When I manually: add a drug step, a location, a recipe and a plant spot
    And I manually: edit each of them, then remove each of them
    Then I confirm: every change applies live without a restart

  @kora_drugs @checklist @checklist:kora_drugs:plant-picking @cat:crime
  Scenario: Pick plants (coca leaf, poppy, weed)
    """
    Checklist test: Go to a configured plant spot, use the target on the plant prop, finish the progress bar; item added and prop vanishes then respawns.
    """
    When I manually: go to a configured plant spot
    And I manually: use the target on the plant prop
    Then a progress bar should run
    When I manually: wait for the progress bar to finish
    Then I confirm: the picked item (coca leaf, poppy or weed) is added to my inventory
    And I confirm: the plant prop vanishes and later respawns

  @kora_drugs @checklist @checklist:kora_drugs:weed-drying @cat:crime
  Scenario: Weed drying
    """
    Checklist test: At the Weed drying step with wet_cola, run the craft; you get dried_cola carrying strain, grams, THC and CBD info.
    """
    Given I have 1 "wet_cola"
    When I manually: go to the Weed drying step and run the craft
    Then I should have 1 "dried_cola"
    And I confirm: the dried_cola info shows strain, grams, THC and CBD

  @kora_drugs @checklist @checklist:kora_drugs:weed-break-nugs @cat:crime
  Scenario: Weed: break dried cola into nugs
    """
    Checklist test: With dried_cola use the Break Nugs step; cola is removed and strain nugs are given matching the strain info.
    """
    Given I have 1 "dried_cola"
    When I manually: use the Break Nugs step
    Then I should have no "dried_cola"
    And I confirm: I received strain nugs matching the dried_cola strain info

  @kora_drugs @checklist @checklist:kora_drugs:weed-bagging @cat:crime
  Scenario: Weed: bag nugs into 1g bags
    """
    Checklist test: With nugs and gram_bag use the Bag Weed step; nugs and gram bags are consumed for the matching 1g bag items.
    """
    Given I have 1 "gram_bag"
    And I have 1 "skunk_weed"
    When I manually: use the Bag Weed step
    Then I should have no "gram_bag"
    And I should have no "skunk_weed"
    And I should have 1 "skunk_1g"

  @kora_drugs @checklist @checklist:kora_drugs:rolling-joint @cat:crime
  Scenario: Roll a joint with rolling_paper
    """
    Checklist test: Use rolling_paper while carrying a weed nug; 5s Rolling A Joint progress then the nug and paper become the strain joint.
    """
    Given I have 1 "rolling_paper"
    And I have 1 "skunk_weed"
    When I use the "rolling_paper"
    Then a progress bar labelled "Rolling A Joint" should run
    When I wait 6 seconds
    Then I should have 1 "skunk_joint"
    And I should have no "rolling_paper"
    And I should have no "skunk_weed"

  @kora_drugs @checklist @checklist:kora_drugs:weed-lab-teleport @cat:crime @manual
  Scenario: Weed/Cocaine/Meth lab teleport
    """
    Checklist test: Use the lab entrance target to enter the interior and the exit target to leave; works for weed, cocaine and meth labs.
    """
    When I manually: use the lab entrance target of the weed lab
    Then I confirm: I am teleported inside the interior
    When I manually: use the exit target
    Then I confirm: I am back outside the lab
    When I manually: repeat entering and leaving for the cocaine lab and the meth lab
    Then I confirm: both labs also teleport in and out correctly

  @kora_drugs @checklist @checklist:kora_drugs:cocaine-process @cat:crime
  Scenario: Cocaine powdering, cutting, bagging
    """
    Checklist test: At each Cocaine lab step (powder, cut, bag) with the right items run the craft animation and check input/output items.
    """
    Given I have 1 "coca_leaf"
    And I have 1 "coke_powder"
    And I have 1 "cut_coke"
    And I have 1 "gram_bag"
    When I manually: run the Cocaine powder step at the lab
    Then I confirm: the craft animation plays, the input items are consumed and the output item is given
    When I manually: run the Cocaine cut step
    Then I confirm: the craft animation plays, the input items are consumed and the output item is given
    When I manually: run the Cocaine bag step
    Then I confirm: the craft animation plays, the input items are consumed and the output item is given

  @kora_drugs @checklist @checklist:kora_drugs:crack-cooking @cat:crime
  Scenario: Crack cook and bagging
    """
    Checklist test: At the Crack steps cook coke into crack rock and bag it; items consumed and produced per recipe.
    """
    Given I have 1 "coke_powder"
    And I have 1 "baking_soda"
    And I have 1 "gram_bag"
    When I manually: use the Crack cook step at the Crack lab
    Then I confirm: the coke is consumed and crack_rock is produced per the recipe
    When I manually: use the Crack bagging step
    Then I confirm: the crack rock is consumed and crack_bag is produced per the recipe

  @kora_drugs @checklist @checklist:kora_drugs:heroin-chain @cat:crime
  Scenario: Heroin drying, vials and syringes
    """
    Checklist test: Run the Heroin drying, vials and syringe steps with poppy resin, empty vials and syringes; outputs match recipes.
    """
    Given I have 1 "poppy_resin"
    And I have 1 "empty_vial"
    And I have 1 "syringe"
    When I manually: run the Heroin drying step
    Then I confirm: the outputs match the recipe
    When I manually: run the Heroin vial step
    Then I confirm: the outputs match the recipe
    When I manually: run the Heroin syringe step
    Then I confirm: the outputs match the recipe

  @kora_drugs @checklist @checklist:kora_drugs:meth-cook @cat:crime
  Scenario: Meth cooking minigame chain
    """
    Checklist test: At the Meth lab: Pour, Heat (dial minigame), pick up tray, Smash, then Bag; steps are stage-locked and end with meth bagged.
    """
    When I manually: go to the Meth lab and try the Heat step before Pour
    Then I confirm: the step is locked until the previous stage is done
    When I manually: do the Pour step
    And I manually: do the Heat step and complete the dial minigame
    Then I should see a notification containing "You Have Heated the Meth"
    When I manually: pick up the tray
    And I manually: do the Smash step
    And I manually: do the Bag step
    Then I confirm: each step was stage-locked
    And I should have 1 "meth"

  @kora_drugs @checklist @checklist:kora_drugs:craft-cooldown @cat:crime @manual
  Scenario: Craft cooldown and distance check
    """
    Checklist test: Spam a craft step: server enforces a 2.5s cooldown; trying a step from far away is refused.
    """
    When I manually: spam a craft step repeatedly
    Then I confirm: crafts are refused within the 2.5s cooldown
    When I manually: try a craft step from far away from its location
    Then I confirm: the craft is refused

  @kora_drugs @checklist @checklist:kora_drugs:corner-selling @cat:crime
  Scenario: /cornerSell toggle
    """
    Checklist test: Run /cornerSell with sellable drugs: Looking for a buyer text, a nearby ped walks to you and 'Sell to buyer' target appears.
    """
    Given I have 1 "weed"
    When I run the command "/cornerSell"
    Then I confirm: a "Looking for a buyer" text appears
    And I confirm: a nearby ped walks to me
    And I confirm: a "Sell to buyer" target appears on the ped

  @kora_drugs @checklist @checklist:kora_drugs:corner-offer-nui @cat:crime
  Scenario: Corner sale offer panel
    """
    Checklist test: Target the buyer ped; NUI shows item, price, amount, total with Accept/Deny; Accept shakes hands and pays, Deny moves on.
    """
    Given I have 1 "weed"
    When I run the command "/cornerSell"
    And I manually: target the buyer ped when it arrives
    Then the "kora_drugs:cornerOffer" app opens
    And I confirm: the panel shows item, price, amount and total with Accept and Deny
    When I manually: click Accept
    Then I confirm: my character shakes hands and I am paid
    When I manually: start another sale and click Deny
    Then I confirm: the buyer moves on

  @kora_drugs @checklist @checklist:kora_drugs:dealer-shop @cat:crime @manual
  Scenario: Dealer shop
    """
    Checklist test: Visit a dealer zone and use the shop target; schedule, range and reputation lock which items can be bought.
    """
    When I manually: visit a dealer zone and use the shop target
    Then I confirm: the dealer shop opens
    And I confirm: schedule, range and reputation lock which items I can buy

  @kora_drugs @checklist @checklist:kora_drugs:dealer-delivery @cat:crime
  Scenario: Dealer delivery request and drop-off
    """
    Checklist test: Use 'Request delivery' on a dealer, go to the marked drop, use 'Deliver package' (3.5s); paid with a five-minute deadline.
    """
    When I manually: use the Request delivery target on a dealer
    Then I confirm: a drop-off is marked with a five-minute deadline
    When I manually: go to the marked drop and use the Deliver package target
    Then a progress bar should run
    And I confirm: the progress takes about 3.5 seconds and I am paid
    And I should see a notification containing "Your delivery has been settled"

  @kora_drugs @checklist @checklist:kora_drugs:dealer-admin-commands @cat:crime @needs:admin @manual
  Scenario: Dealer admin commands
    """
    Checklist test: As admin use /newdealer, /deletedealer, /dealers and /dealergoto; dealers persist in the dealers table.
    """
    When I manually: run /newdealer to create a dealer
    And I manually: run /dealers and /dealergoto for the new dealer
    And I manually: run /deletedealer for that dealer
    Then I confirm: the dealers table in the database persists the changes (ask a dev to check the table)

  @kora_drugs @checklist @checklist:kora_drugs:strain-quality-info @cat:crime
  Scenario: Strain, THC and CBD item info
    """
    Checklist test: Inspect weed items in inventory after drying/breaking/bagging; strain, grams, THC and CBD info is preserved.
    """
    Given I have 1 "wet_cola"
    When I open my inventory
    And I manually: inspect the weed items after drying, breaking and bagging
    Then I confirm: strain, grams, THC and CBD info is preserved at each stage
