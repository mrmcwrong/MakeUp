import argparse
import csv
import json
import math
from pathlib import Path
from statistics import mean


UI_KEYS_MS = {
    "uiFrameTime",
    "uiFrameTimeMs",
    "ui_time_ms",
    "uiTimeMs",
    "buildTimeMs",
    "build_time_ms",
    "frameBuildTimeMs",
    "frame_build_time_ms",
}

RASTER_KEYS_MS = {
    "rasterFrameTime",
    "rasterFrameTimeMs",
    "raster_time_ms",
    "rasterTimeMs",
    "rasterTime",
    "rasterTimeMillis",
    "frameRasterTimeMs",
    "frame_raster_time_ms",
}

UI_KEYS_US = {
    "uiFrameTimeMicros",
    "ui_frame_time_micros",
    "buildTimeMicros",
    "build_time_micros",
    "frameBuildTimeMicros",
}

RASTER_KEYS_US = {
    "rasterFrameTimeMicros",
    "raster_frame_time_micros",
    "rasterTimeMicros",
    "raster_time_micros",
    "frameRasterTimeMicros",
}


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


def _pick_time_ms(obj, keys_ms, keys_us):
    if not isinstance(obj, dict):
        return None

    for key in keys_ms:
        if key in obj:
            value = _as_float(obj[key])
            if value is not None:
                return value

    for key in keys_us:
        if key in obj:
            value = _as_float(obj[key])
            if value is not None:
                return value / 1000.0

    return None


def _walk_json_for_frames(node, ui_times, raster_times):
    if isinstance(node, dict):
        ui_ms = _pick_time_ms(node, UI_KEYS_MS, UI_KEYS_US)
        raster_ms = _pick_time_ms(node, RASTER_KEYS_MS, RASTER_KEYS_US)

        if ui_ms is not None:
            ui_times.append(ui_ms)
        if raster_ms is not None:
            raster_times.append(raster_ms)

        for value in node.values():
            _walk_json_for_frames(value, ui_times, raster_times)

    elif isinstance(node, list):
        for item in node:
            _walk_json_for_frames(item, ui_times, raster_times)


def _extract_thread_names(trace_events):
    names = {}
    for event in trace_events:
        if not isinstance(event, dict):
            continue
        if event.get("name") != "thread_name":
            continue
        args = event.get("args", {})
        tid = event.get("tid")
        if isinstance(args, dict) and tid is not None:
            thread_name = args.get("name")
            if isinstance(thread_name, str):
                names[tid] = thread_name
    return names


def _extract_paired_durations_ms(trace_events, span_name, thread_name_filter=None):
    thread_names = _extract_thread_names(trace_events)
    starts = {}
    durations_ms = []

    for event in trace_events:
        if not isinstance(event, dict):
            continue
        if event.get("name") != span_name:
            continue

        tid = event.get("tid")
        if tid is None:
            continue

        if thread_name_filter:
            thread_name = thread_names.get(tid, "")
            if thread_name_filter not in thread_name:
                continue

        ph = event.get("ph")
        ts = _as_float(event.get("ts"))
        if ts is None:
            continue

        # trace spans use b/e and B/E begin/end markers.
        if ph in {"b", "B"}:
            starts.setdefault(tid, []).append(ts)
        elif ph in {"e", "E"}:
            stack = starts.get(tid)
            if not stack:
                continue
            start_ts = stack.pop()
            if ts >= start_ts:
                durations_ms.append((ts - start_ts) / 1000.0)

    return durations_ms


def read_frame_times(path: Path):
    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)

    ui_times = []
    raster_times = []

    # integration_test timeline export path (flutter drive + integrationDriver).
    if isinstance(data, dict):
        perf_timeline = data.get("perf_timeline")
        if isinstance(perf_timeline, dict):
            perf_trace = perf_timeline.get("traceEvents")
            if isinstance(perf_trace, list):
                ui_times.extend(
                    _extract_paired_durations_ms(
                        perf_trace,
                        span_name="Frame",
                        thread_name_filter=".ui",
                    )
                )
                raster_times.extend(
                    _extract_paired_durations_ms(
                        perf_trace,
                        span_name="GPURasterizer::Draw",
                        thread_name_filter=".raster",
                    )
                )
                if not raster_times:
                    raster_times.extend(
                        _extract_paired_durations_ms(
                            perf_trace,
                            span_name="Rasterizer::DoDraw",
                            thread_name_filter=".raster",
                        )
                    )

    # DevTools snapshot export path (performance screen).
    if isinstance(data, dict):
        performance = data.get("performance")
        if isinstance(performance, dict):
            flutter_frames = performance.get("flutterFrames")
            if isinstance(flutter_frames, list):
                for frame in flutter_frames:
                    if not isinstance(frame, dict):
                        continue

                    # In snapshot exports, build/raster are in microseconds.
                    build_us = _as_float(frame.get("build"))
                    raster_us = _as_float(frame.get("raster"))

                    if build_us is not None:
                        ui_times.append(build_us / 1000.0)
                    if raster_us is not None:
                        raster_times.append(raster_us / 1000.0)

    # Common Flutter timeline export path.
    trace_events = data.get("traceEvents") if isinstance(data, dict) else None
    if isinstance(trace_events, list):
        for event in trace_events:
            args = event.get("args", {}) if isinstance(event, dict) else {}
            ui_ms = _pick_time_ms(args, UI_KEYS_MS, UI_KEYS_US)
            raster_ms = _pick_time_ms(args, RASTER_KEYS_MS, RASTER_KEYS_US)

            if ui_ms is not None:
                ui_times.append(ui_ms)
            if raster_ms is not None:
                raster_times.append(raster_ms)

    # Fallback for other DevTools export shapes.
    if not ui_times and not raster_times:
        _walk_json_for_frames(data, ui_times, raster_times)

    return ui_times, raster_times


def _percentile(values, pct):
    if not values:
        return None
    if pct < 0 or pct > 100:
        raise ValueError("pct must be between 0 and 100")

    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]

    rank = (len(ordered) - 1) * (pct / 100.0)
    low = int(math.floor(rank))
    high = int(math.ceil(rank))

    if low == high:
        return ordered[low]

    weight = rank - low
    return ordered[low] + (ordered[high] - ordered[low]) * weight


def _print_percentiles(label, values):
    p50 = _percentile(values, 50)
    p90 = _percentile(values, 90)
    p95 = _percentile(values, 95)
    p99 = _percentile(values, 99)
    print(f"{label} p50/p90/p95/p99 (ms): {p50:.3f} / {p90:.3f} / {p95:.3f} / {p99:.3f}")


def _build_metrics(values):
    if not values:
        return None
    return {
        "frames": len(values),
        "mean_ms": mean(values),
        "p50_ms": _percentile(values, 50),
        "p90_ms": _percentile(values, 90),
        "p95_ms": _percentile(values, 95),
        "p99_ms": _percentile(values, 99),
    }


def _write_csv_row(csv_file, row):
    fieldnames = [
        "label",
        "json_file",
        "ui_frames",
        "ui_mean_ms",
        "ui_p50_ms",
        "ui_p90_ms",
        "ui_p95_ms",
        "ui_p99_ms",
        "ui_jank_percent",
        "raster_frames",
        "raster_mean_ms",
        "raster_p50_ms",
        "raster_p90_ms",
        "raster_p95_ms",
        "raster_p99_ms",
    ]

    csv_file.parent.mkdir(parents=True, exist_ok=True)
    write_header = not csv_file.exists() or csv_file.stat().st_size == 0

    with csv_file.open("a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        if write_header:
            writer.writeheader()
        writer.writerow(row)


def main():
    parser = argparse.ArgumentParser(
        description="Read Flutter DevTools frame-time JSON exports and print summary stats."
    )
    parser.add_argument(
        "json_file",
        nargs="?",
        default="testing/dart_devtools_2026-04-02_17_57_32.460.json",
        help="Path to a Flutter DevTools JSON export.",
    )
    parser.add_argument(
        "--csv",
        dest="csv_file",
        help="Append analysis metrics to this CSV file.",
    )
    parser.add_argument(
        "--label",
        dest="label",
        help="Optional run label written to CSV (default: JSON filename stem).",
    )
    args = parser.parse_args()

    path = Path(args.json_file)
    if not path.exists():
        raise SystemExit(f"File not found: {path}")

    ui_times, raster_times = read_frame_times(path)
    ui_metrics = _build_metrics(ui_times)
    raster_metrics = _build_metrics(raster_times)
    ui_jank_percent = None

    if ui_metrics:
        print(f"UI frames: {ui_metrics['frames']}")
        print(f"Mean UI (ms): {ui_metrics['mean_ms']:.3f}")
        _print_percentiles("UI", ui_times)
        jank_frames = sum(1 for t in ui_times if t > 16.67)
        ui_jank_percent = jank_frames / ui_metrics["frames"] * 100
        print(f"UI Jank % (>16.67ms): {ui_jank_percent:.2f}")
    else:
        print("No UI frame times found.")

    if raster_metrics:
        print(f"Raster frames: {raster_metrics['frames']}")
        print(f"Mean Raster (ms): {raster_metrics['mean_ms']:.3f}")
        _print_percentiles("Raster", raster_times)
    else:
        print("No raster frame times found.")

    if args.csv_file:
        if not ui_metrics and not raster_metrics:
            print("Skipped CSV append: no frame metrics extracted from this file.")
            return

        csv_path = Path(args.csv_file)
        label = args.label or path.stem
        row = {
            "label": label,
            "json_file": str(path),
            "ui_frames": ui_metrics["frames"] if ui_metrics else "",
            "ui_mean_ms": f"{ui_metrics['mean_ms']:.3f}" if ui_metrics else "",
            "ui_p50_ms": f"{ui_metrics['p50_ms']:.3f}" if ui_metrics else "",
            "ui_p90_ms": f"{ui_metrics['p90_ms']:.3f}" if ui_metrics else "",
            "ui_p95_ms": f"{ui_metrics['p95_ms']:.3f}" if ui_metrics else "",
            "ui_p99_ms": f"{ui_metrics['p99_ms']:.3f}" if ui_metrics else "",
            "ui_jank_percent": f"{ui_jank_percent:.2f}" if ui_jank_percent is not None else "",
            "raster_frames": raster_metrics["frames"] if raster_metrics else "",
            "raster_mean_ms": f"{raster_metrics['mean_ms']:.3f}" if raster_metrics else "",
            "raster_p50_ms": f"{raster_metrics['p50_ms']:.3f}" if raster_metrics else "",
            "raster_p90_ms": f"{raster_metrics['p90_ms']:.3f}" if raster_metrics else "",
            "raster_p95_ms": f"{raster_metrics['p95_ms']:.3f}" if raster_metrics else "",
            "raster_p99_ms": f"{raster_metrics['p99_ms']:.3f}" if raster_metrics else "",
        }
        _write_csv_row(csv_path, row)
        print(f"Appended CSV row: {csv_path}")


if __name__ == "__main__":
    main()