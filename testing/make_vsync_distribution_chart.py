import argparse
import json
import math
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np


VSYNC_HZ = 90.0
VSYNC_INTERVAL_MS = 1000.0 / VSYNC_HZ


def _as_float(value):
    if isinstance(value, (int, float)):
        v = float(value)
        return v if math.isfinite(v) else None
    if isinstance(value, str):
        try:
            v = float(value.strip())
            return v if math.isfinite(v) else None
        except ValueError:
            return None
    return None


def _extract_perf_timeline_trace_events(data):
    if not isinstance(data, dict):
        return None

    perf_timeline = data.get("perf_timeline")
    if not isinstance(perf_timeline, dict):
        return None

    trace_events = perf_timeline.get("traceEvents")
    return trace_events if isinstance(trace_events, list) else None


def _extract_frame_begin_timestamps_us(trace_events):
    timestamps = []
    for event in trace_events:
        if not isinstance(event, dict):
            continue
        if event.get("name") != "Frame":
            continue
        if event.get("ph") not in {"b", "B"}:
            continue

        ts = _as_float(event.get("ts"))
        if ts is not None:
            timestamps.append(ts)

    return sorted(timestamps)


def _extract_frame_gaps_ms(json_path):
    with json_path.open("r", encoding="utf-8") as f:
        data = json.load(f)

    trace_events = _extract_perf_timeline_trace_events(data)
    if not trace_events:
        return []

    frame_begins_us = _extract_frame_begin_timestamps_us(trace_events)
    if len(frame_begins_us) < 2:
        return []

    return [
        (frame_begins_us[i] - frame_begins_us[i - 1]) / 1000.0
        for i in range(1, len(frame_begins_us))
    ]


def _pct(count, total):
    return (count / total * 100.0) if total else 0.0


def build_chart(input_dir: Path, output_file: Path, run_label: str):
    json_files = sorted(input_dir.glob("perf_run_*.json"))
    if not json_files:
        raise SystemExit(f"No perf JSON files found in: {input_dir}")

    all_gaps_ms = []
    for json_file in json_files:
        all_gaps_ms.extend(_extract_frame_gaps_ms(json_file))

    if not all_gaps_ms:
        raise SystemExit("No frame gaps extracted from input JSON files.")

    gaps_vsync = np.array(all_gaps_ms) / VSYNC_INTERVAL_MS
    rounded_vsync = np.rint(gaps_vsync).astype(int)

    total = int(len(gaps_vsync))
    mean_gap_ms = float(np.mean(all_gaps_ms))
    mean_vsync = float(np.mean(gaps_vsync))

    c1 = int(np.sum(rounded_vsync == 1))
    c2 = int(np.sum(rounded_vsync == 2))
    c3 = int(np.sum(rounded_vsync == 3))

    p1 = _pct(c1, total)
    p2 = _pct(c2, total)
    p3 = _pct(c3, total)

    plt.style.use("ggplot")
    fig = plt.figure(figsize=(12, 7), dpi=150)
    gs = fig.add_gridspec(2, 2, height_ratios=[2.3, 1.7], width_ratios=[2.2, 1.3])

    # Top: full vsync distribution histogram.
    ax_hist = fig.add_subplot(gs[0, :])
    ax_hist.hist(gaps_vsync, bins=45, color="#4D84D9", edgecolor="none", alpha=0.85)
    ax_hist.axvline(
        mean_vsync,
        color="#E74C3C",
        linestyle="--",
        linewidth=2.4,
        label=f"Mean: {mean_vsync:.3f} vsyncs",
    )
    ax_hist.set_title("Frame Gap Distribution", fontsize=16, pad=12)
    ax_hist.set_xlabel("Frame Gap (vsyncs)", fontsize=14)
    ax_hist.set_ylabel("Frequency", fontsize=14)
    ax_hist.set_xlim(left=0.3)
    ax_hist.legend(loc="upper right", frameon=True, fancybox=False, edgecolor="#BFC3C9")

    # Bottom-left: rounded vsync bar chart.
    ax_bar = fig.add_subplot(gs[1, 0])
    bars = ax_bar.bar([1, 2, 3], [p1, p2, p3], color=["#37A854", "#F9BE00", "#F04B3D"], width=0.6)
    ax_bar.set_title("Rounded Frame Gaps", fontsize=16, pad=10)
    ax_bar.set_xlabel("Vsync Multiples", fontsize=14)
    ax_bar.set_ylabel("Percentage (%)", fontsize=14)
    ax_bar.set_ylim(0, max(60, p1, p2, p3) + 4)

    for bar, pct in zip(bars, [p1, p2, p3]):
        ax_bar.text(
            bar.get_x() + bar.get_width() / 2,
            bar.get_height() + 0.6,
            f"{pct:.1f}%",
            ha="center",
            va="bottom",
            fontsize=13,
            color="#2F2F2F",
        )

    # Bottom-right: stats text box.
    ax_text = fig.add_subplot(gs[1, 1])
    ax_text.axis("off")
    stats_text = (
        "Summary Statistics\n\n"
        f"Total Frame Gaps: {total:,}\n"
        f"Mean Gap: {mean_gap_ms:.2f} ms\n"
        f"Mean (vsyncs): {mean_vsync:.3f}\n\n"
        f"1 vsync: {c1:,} ({p1:.1f}%)\n"
        f"2 vsyncs: {c2:,} ({p2:.1f}%)\n"
        f"3 vsyncs: {c3:,} ({p3:.1f}%)\n\n"
        f"Device Cadence: {int(VSYNC_HZ)} Hz\n"
        f"Vsync Interval: {VSYNC_INTERVAL_MS:.3f} ms"
    )
    ax_text.text(
        0.02,
        0.95,
        stats_text,
        va="top",
        ha="left",
        fontsize=13.5,
        family="monospace",
        bbox=dict(boxstyle="round,pad=0.6", facecolor="#E9EAEC", edgecolor="#C4C8CE"),
    )

    fig.suptitle(f"{run_label} Vsync Distribution", fontsize=10, y=0.995, color="#666")
    fig.tight_layout()

    output_file.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_file, dpi=150)
    plt.close(fig)

    print(f"Wrote chart: {output_file}")


def main():
    parser = argparse.ArgumentParser(description="Build a frame-gap vsync distribution chart from perf JSON exports.")
    parser.add_argument(
        "--input-dir",
        required=True,
        help="Directory containing perf_run_*.json files.",
    )
    parser.add_argument(
        "--output-file",
        required=True,
        help="Output PNG path.",
    )
    parser.add_argument(
        "--run-label",
        default="Run",
        help="Short label shown in the figure subtitle.",
    )
    args = parser.parse_args()

    build_chart(Path(args.input_dir), Path(args.output_file), args.run_label)


if __name__ == "__main__":
    main()
