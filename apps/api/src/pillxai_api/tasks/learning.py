"""04's batch-end rule. Input is ordered durable evidence, never UI state."""

from math import isfinite
from statistics import median

from .models import LearningResult, ParameterView

DEFAULT_SPEED = 0.2
DEFAULT_GATE = 0.7


def select_parameters(previous, prescription_id, medicine_id, feed_form, *, simulation):
    enabled = previous.learning_enabled if previous else True
    valid = bool(
        previous
        and previous.has_values
        and previous.medicine_id == medicine_id
        and previous.feed_form == feed_form
        and previous.simulation_only == simulation
        and previous.turntable > 0
        and previous.gate > 0
    )
    use_history = enabled and valid
    return ParameterView(
        prescription_id=prescription_id,
        medicine_id=medicine_id,
        revision=previous.revision if previous else 0,
        turntable=previous.turntable if use_history else DEFAULT_SPEED,
        gate=previous.gate if use_history else DEFAULT_GATE,
        simulation_only=simulation,
        learning_enabled=enabled,
        has_values=use_history,
        feed_form=feed_form,
    ), use_history


def clamp(value, low, high):
    return min(high, max(low, value))


def next_values(pulse, initial_gate, had_history, manual_gate=None):
    speed = clamp(0.15 + (pulse - 5) * 0.010, 0.15, 0.36)
    candidate = 0.85 - (pulse - 5) * 0.020 if pulse <= 13 else 0.69 - (pulse - 13) * 0.055
    candidate = clamp(candidate, 0.08, 0.98)
    if manual_gate is None:
        gate = initial_gate if had_history else candidate
    elif manual_gate < initial_gate and manual_gate < candidate:
        gate = clamp(0.35 * initial_gate + 0.15 * candidate + 0.5 * manual_gate, 0.08, 0.98)
    else:
        gate = clamp(0.7 * initial_gate + 0.3 * candidate, 0.08, 0.98)
    return speed, gate


def finite_number(value):
    if isinstance(value, bool):
        return None
    try:
        number = float(value)
        return number if isfinite(number) else None
    except (TypeError, ValueError, OverflowError):
        return None


def evaluate_batch(batch, records):
    """Replayed once at FINISH; page boundaries and duplicate uploads do not matter."""
    samples, adjustments, widths = [], [], []
    started = finished = abnormal = False
    last_number = None
    initial_gate = batch.parameters.gate
    manual_gate = None
    for event in records:
        if event["batch"] != batch.index:
            continue
        kind, detail = event["kind"], event["detail"]
        if kind in {
            "recovery",
            "recovered",
            "cancel_intent",
            "cancelled",
            "delete_intent",
            "skipped",
            "manual_completion",
            "reset_observed",
        }:
            abnormal = True
        if kind == "batch_started":
            if started:
                abnormal = True
            started = True
            value = finite_number(detail.get("gate"))
            speed = finite_number(detail.get("turntable"))
            if value is None or not 0 <= value <= 1 or speed != batch.parameters.turntable:
                abnormal = True
            else:
                initial_gate = value
        if kind == "manual_gate_written":
            value = finite_number(detail.get("gate"))
            applicable = started and not finished and value is not None and 0 <= value <= 1
            adjustments.append(
                {"sequence": event["sequence"], "value": value, "applied_to_learning": applicable}
            )
            if applicable:
                manual_gate = value
        if kind == "feedback":
            opening_stall = (
                detail.get("kind") == "stalled"
                and detail.get("ignored_reason") == "opening_phase"
                and (not started or finished)
            )
            if (
                detail.get("kind") in {"counterError", "initialized", "stalled", "malformed"}
                and not opening_stall
            ):
                abnormal = True
            if detail.get("kind") == "count":
                number = detail.get("count")
                width = finite_number(detail.get("width"))
                reason = "accepted"
                if not started or finished:
                    reason = "outside_batch"
                elif number is not None and (type(number) is not int or number < 0):
                    reason = "invalid_number"
                elif number is not None and last_number is not None and number <= last_number:
                    reason = "duplicate_or_backward"
                else:
                    if number is not None:
                        last_number = number
                    if width is None or not 3 <= width <= 200:
                        reason = "width_out_of_range"
                samples.append(
                    {
                        "sequence": event["sequence"],
                        "number": number if type(number) is int else None,
                        "raw_width": str(detail["width"])
                        if detail.get("width") is not None
                        else None,
                        "reason": reason,
                    }
                )
                if reason == "accepted":
                    widths.append(width)
        if kind == "batch_finished":
            finished = True
    result = LearningResult(
        batch=batch.index,
        status="insufficient",
        message="有效脉宽不足 7 个，保留原参数。",
        base_revision=batch.parameters.revision,
        evidence={
            "initial_gate": initial_gate,
            "had_valid_history": batch.had_valid_history,
            "manual_gate": manual_gate,
            "samples": samples,
            "adjustments": adjustments,
            "valid_samples": len(widths),
        },
    )
    if not batch.learning_enabled:
        result.status, result.message = "disabled", "自动学习已关闭，保留原参数。"
    elif abnormal or not started or not finished:
        result.status, result.message = "abnormal", "批次异常、中断或启动证据不完整，不更新参数。"
    elif len(widths) >= 7:
        result.median = median(widths)
        result.turntable, result.gate = next_values(
            result.median, initial_gate, batch.had_valid_history, manual_gate
        )
        result.status, result.message = "calculated", "本批次参数已计算，等待版本核对。"
    return result
