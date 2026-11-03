"""Validate a skip's durable request and sequential device acknowledgements."""


def confirmed_skip(records, batch, detail):
    if detail.get("source") == "counter_review":
        return (
            set(detail) == {"source", "manual", "all_remaining"}
            and detail["manual"] is True and detail["all_remaining"] is False
            and confirmed_counter_review(records, batch)
        )
    if set(detail) != {"all_remaining", "manual"}:
        return False
    if any(type(value) is not bool for value in detail.values()):
        return False
    if detail["all_remaining"] and detail["manual"]:
        return False
    expected = [
        ("written", "stop_skip"), ("ack", "stop_skip"),
        ("written", "exit"), ("ack", "exit"), ("command_done", "exit"),
    ]
    stage = -1
    for record in records:
        if record["batch"] != batch:
            continue
        kind, data = record["kind"], record["detail"]
        if kind == "skip_requested":
            stage = 0 if data == detail else -1
        elif kind in ("recovery", "recovered", "cancel_intent", "batch_finished"):
            stage = -1
        elif stage >= 0 and kind in ("written", "ack", "command_done"):
            pair = kind, data.get("command")
            if stage < len(expected) and pair == expected[stage]:
                stage += 1
            elif pair != ("command_done", "stop_skip"):
                stage = -1
    return stage == len(expected)


def confirmed_counter_review(records, batch):
    """A manual count-error result requires the fault and the open tray, in order."""
    expected = [
        ("written", "stop_review"), ("ack", "stop_review"),
        ("written", "exit"), ("ack", "exit"), ("command_done", "exit"),
        ("written", "open"), ("ack", "open"), ("command_done", "open"),
    ]
    saw_fault = False
    stage = -1
    for record in records:
        if record["batch"] != batch:
            continue
        kind, data = record["kind"], record["detail"]
        if kind in ("recovery", "recovered", "cancel_intent", "batch_finished"):
            stage, saw_fault = -1, False
        elif kind == "feedback" and str(data.get("raw", "")).strip() == "machine_state:CNT_ERR":
            saw_fault = True
        elif kind == "counter_review_requested":
            stage = 0 if saw_fault else -1
        elif stage >= 0 and kind in ("written", "ack", "command_done"):
            pair = kind, data.get("command")
            if stage == len(expected) and pair[1] in ("release_stall_2", "release_stall_3"):
                continue
            if stage < len(expected) and pair == expected[stage]:
                stage += 1
            elif stage > 0 and pair != ("command_done", "stop_review"):
                stage = -1
    return stage == len(expected)
