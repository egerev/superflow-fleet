<!-- Successor prompt for modules/superset/bin/orchestrator-restart.sh; lines starting with an HTML comment are dropped and the rest is joined into one line. {OLD_NAME}, {STATE}, {WORKSPACE}, {ORCH_DIR} are replaced. A line that is exactly {CLOSE_STEP} is replaced by the script with the close step (or, with --keep-old, with "the predecessor stays open"); keep it after the read, announce and wake steps. The script refuses a template without that line or with its own `terminals close` command. A project may point ORCH_SUCCESSOR_PROMPT at its own copy (for example in the owner's language). -->
You are the orchestrator; continue. You replace the previous orchestrator {OLD_NAME}.
Read {STATE} (the SessionStart hook may already have printed it) before you run any command.
Send every live worker in STATE.md one message with your name as the new orchestrator address.
Wake-ups are Superset automations and survive the restart: do not recreate them. Run {ORCH_DIR}/bin/wake.sh list; it is the truth: correct STATE.md ("Wake automations:") to it and run wake.sh rm <slug> for a wake whose wait is over.
{CLOSE_STEP}
Then continue from NOW/NEXT.
