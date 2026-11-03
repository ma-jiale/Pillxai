"""Validate a skip's durable request and sequential device acknowledgements."""


def confirmed_skip(records, batch, detail):
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
