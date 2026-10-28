<!-- Successor prompt for modules/superset/bin/orchestrator-restart.sh; lines starting with an HTML comment are dropped and the rest is joined into one line. {OLD_NAME}, {STATE}, {WORKSPACE}, {ORCH_DIR} are replaced; the successor fills in its own session name. A line that is exactly {CLOSE_STEP} is replaced by the script with the close step (or, with --keep-old, with "the predecessor stays open"); keep it after the read, announce and wake steps. The script refuses a template without that line, without a `boss-of.sh set` step or with its own `terminals close` command. A project may point ORCH_SUCCESSOR_PROMPT at its own copy (for example in the owner's language). -->
You are the orchestrator; continue. You replace the previous orchestrator {OLD_NAME}.
Read {STATE} (the SessionStart hook may already have printed it) before you run any command.
Record your session name as the project's orchestrator address: run {ORCH_DIR}/bin/boss-of.sh set <your session name>; if it does not print OK, fix that before you announce anything.
Send every live worker in STATE.md one message with your name as the new orchestrator address, ending "No action needed if you already sent DONE". Never send it to another project's orchestrator: peers read the address with boss-of.sh.
Wake-ups are Superset automations and survive the restart: do not recreate them. Run {ORCH_DIR}/bin/wake.sh list; it is the truth: correct STATE.md ("Wake automations:") to it and run wake.sh rm <slug> for a wake whose wait is over.
{CLOSE_STEP}
Then continue from NOW/NEXT.
