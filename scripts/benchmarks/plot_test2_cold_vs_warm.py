#!/usr/bin/env python3
"""TEST 2 — Cold vs Warm line chart — qwen3 4b/8b/14b/32b — dark theme
   Prompt: 'สรุปหลักการและวัตถุประสงค์ของ GenEd อย่างละเอียด...'
"""

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.lines as mlines
import matplotlib.font_manager as fm
import numpy as np

# ── Thai font ─────────────────────────────────────────────────────────────────
_thai_fp = fm.FontProperties(fname="/System/Library/Fonts/Supplemental/Thonburi.ttc")
fm.fontManager.addfont("/System/Library/Fonts/Supplemental/Thonburi.ttc")

# ── Theme ─────────────────────────────────────────────────────────────────────
BG       = "#0F0F1A"
PANEL    = "#1A1A2E"
GRID_C   = "#2A2A40"
TEXT     = "#E0E0E0"
SHADE_COLD = "#2A1A1E"
SHADE_WARM = "#1A2A1E"
COLD_COLOR = "#EF7C8E"
WARM_COLOR = "#4BB87F"

plt.rcParams.update({
    "figure.facecolor":  BG,
    "axes.facecolor":    PANEL,
    "axes.edgecolor":    GRID_C,
    "axes.labelcolor":   TEXT,
    "axes.titlecolor":   TEXT,
    "xtick.color":       TEXT,
    "ytick.color":       TEXT,
    "xtick.labelsize":   13,
    "ytick.labelsize":   13,
    "axes.labelsize":    13,
    "axes.titlesize":    15,
    "text.color":        TEXT,
    "grid.color":        GRID_C,
    "legend.facecolor":  PANEL,
    "legend.edgecolor":  GRID_C,
    "legend.labelcolor": TEXT,
    "legend.fontsize":   12,
    "font.family":       "Thonburi",
})

# ── Raw data (run 1-2 = cold, run 3-4 = warm) ─────────────────────────────────
runs = [1, 2, 3, 4]

models = {
    "qwen3:4b-q4_K_M": {
        "color": "#4C9BE8",
        "node": "llm-01",
        "time_s":    [22.1, 26.2, 22.0, 21.5],
        "speed_tps": [64.9, 70.0, 83.2, 82.8],
    },
    "qwen3:8b-q4_K_M": {
        "color": "#F4A261",
        "node": "llm-01",
        "time_s":    [39.3, 33.0, 29.8, 28.7],
        "speed_tps": [45.5, 44.0, 56.0, 56.1],
    },
    "qwen3:14b-q4_K_M": {
        "color": "#9B59B6",
        "node": "llm-01",
        "time_s":    [63.2, 67.4, 51.2, 49.1],
        "speed_tps": [26.5, 27.4, 34.4, 34.4],
    },
    "qwen3:30b-a3b-q4_K_M": {
        "color": "#00E5FF",
        "node": "llm-02",
        "moe": True,
        "time_s":    [41.4, 34.9, 27.9, 25.9],
        "speed_tps": [55.2, 54.1, 73.0, 73.2],
    },
    "qwen3:32b-q4_K_M": {
        "color": "#E74C3C",
        "node": "llm-03",
        "time_s":    [354.1, 362.3, 229.4, 221.8],
        "speed_tps": [  5.1,   5.3,   7.6,   7.3],
    },
}

x_labels = ["Run 1\n(cold)", "Run 2\n(cold)", "Run 3\n(warm)", "Run 4\n(warm)"]

metrics = [
    ("time_s",    "Test 2 — Time (s)",       "Seconds", (0, 400)),
    ("speed_tps", "Test 2 — Speed (tok/s)",  "tok/s",   (0, 100)),
]

# ── Layout ────────────────────────────────────────────────────────────────────
fig, axes = plt.subplots(1, 2, figsize=(20, 8))
fig.patch.set_facecolor(BG)
fig.suptitle(
    "TEST 2 — Cold (no pre-load) vs Warm (pre-loaded)  |  RAG + PII scrub  |  llm-01 / llm-02 / llm-03\n"
    "Prompt: 'Summarize GenEd principles, objectives, things students should know, and required credits'",
    fontsize=13, fontweight="bold", y=1.03, color=TEXT,
)

def shade_regions(ax, ymax):
    ax.axvspan(0.5, 2.5, color=SHADE_COLD, zorder=0)
    ax.axvspan(2.5, 4.5, color=SHADE_WARM, zorder=0)
    ax.text(1.5, ymax * 0.98, "COLD", ha="center", va="top",
            fontsize=13, color=COLD_COLOR, fontweight="bold")
    ax.text(3.5, ymax * 0.98, "WARM", ha="center", va="top",
            fontsize=13, color=WARM_COLOR, fontweight="bold")
    ax.axvline(2.5, color=GRID_C, lw=1, ls=":", zorder=1)

label_offsets = {
    "qwen3:4b-q4_K_M":       -40,
    "qwen3:8b-q4_K_M":       -20,
    "qwen3:30b-a3b-q4_K_M":    0,
    "qwen3:14b-q4_K_M":        20,
    "qwen3:32b-q4_K_M":        40,
}

for ax, (key, title, ylabel, (ylo, yhi)) in zip(axes, metrics):
    ax.set_facecolor(PANEL)
    shade_regions(ax, yhi)
    ax.grid(axis="y", color=GRID_C, linewidth=0.5, linestyle="--", zorder=0)

    for name, d in models.items():
        raw   = d[key]
        color = d["color"]
        moe   = d.get("moe", False)
        marker = "D" if moe else "o"
        ls     = "--" if moe else "-"

        ax.plot(runs, raw, color=color, linewidth=2.2, linestyle=ls, zorder=2)

        for i, (x, y) in enumerate(zip(runs, raw)):
            cold = i < 2
            ax.plot(x, y,
                    marker=marker, markersize=9, color=color,
                    markerfacecolor=PANEL if cold else color,
                    markeredgewidth=2, zorder=4)
            unit = "s" if key == "time_s" else ""
            ax.annotate(f"{y}{unit}", (x, y),
                        textcoords="offset points",
                        xytext=(label_offsets.get(name, 0), 11),
                        ha="center", fontsize=11, fontweight="bold",
                        color=color, zorder=5)

    ax.set_xlim(0.5, 4.5)
    ax.set_xticks(runs)
    ax.set_xticklabels(x_labels, fontsize=13)
    ax.set_ylabel(ylabel)
    ax.set_title(title, fontsize=15)
    ax.set_ylim(ylo, yhi)
    for spine in ax.spines.values():
        spine.set_color(GRID_C)

# ── Legend ────────────────────────────────────────────────────────────────────
leg_handles = []
for name, d in models.items():
    moe  = d.get("moe", False)
    node = d.get("node", "llm-01")
    lbl  = f"{name}  [{node}]" + (" ◆MoE" if moe else "")
    leg_handles.append(mlines.Line2D([], [], color=d["color"],
                                     linewidth=2.2, linestyle="--" if moe else "-",
                                     marker="D" if moe else "o",
                                     markersize=7, label=lbl))
leg_handles.append(mlines.Line2D([], [], color=TEXT, linewidth=0,
                                  marker="o", markersize=7, markerfacecolor=PANEL,
                                  markeredgewidth=2, label="cold run (hollow)"))
leg_handles.append(mlines.Line2D([], [], color=TEXT, linewidth=0,
                                  marker="o", markersize=7, markerfacecolor=TEXT,
                                  label="warm run (filled)"))
fig.legend(handles=leg_handles, loc="lower center", ncol=3,
           fontsize=12, bbox_to_anchor=(0.5, -0.18))

# ── Summary stats table ────────────────────────────────────────────────────────
header = f"{'Model':<26}  {'Cold time':>10}  {'Warm time':>10}  {'Δ time':>7}  {'Cold spd':>9}  {'Warm spd':>9}  {'Δ spd':>7}"
rows = [header, "─" * len(header)]
for name, d in models.items():
    t = d["time_s"]; s = d["speed_tps"]
    cold_t = [v for v in t[:2] if v is not None]
    warm_t = [v for v in t[2:] if v is not None]
    cold_s = [v for v in s[:2] if v is not None]
    warm_s = [v for v in s[2:] if v is not None]
    ct = np.mean(cold_t); wt = np.mean(warm_t)
    cs = np.mean(cold_s); ws = np.mean(warm_s)
    tag = " ◆" if d.get("moe") else "  "
    rows.append(
        f"{name+tag:<26}  {ct:>8.1f}s  {wt:>8.1f}s  {(ct-wt)/ct*100:>+6.0f}%"
        f"  {cs:>7.1f}t/s  {ws:>7.1f}t/s  {(ws-cs)/cs*100:>+6.0f}%"
    )
fig.text(0.5, -0.36, "\n".join(rows), ha="center", fontsize=11,
         family="monospace", color=TEXT,
         bbox=dict(boxstyle="round,pad=0.5", facecolor=PANEL, edgecolor=GRID_C))

plt.tight_layout()
plt.subplots_adjust(bottom=0.02)
out = "/Users/hanif/mac-llm-cluster/scripts/benchmarks/test2_cold_vs_warm.png"
plt.savefig(out, dpi=150, bbox_inches="tight", facecolor=BG)
print(f"Saved → {out}")
