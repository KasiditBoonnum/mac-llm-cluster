#!/usr/bin/env python3
"""TEST 1 — Cold vs Warm line chart — qwen3 4b/8b/14b/32b — dark theme"""

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.lines as mlines
import numpy as np

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
})

# ── Raw data ──────────────────────────────────────────────────────────────────
runs = [1, 2, 3, 4]

models = {
    "qwen3:4b-q4_K_M": {
        "color": "#4C9BE8",
        "node": "llm-01",
        "time_s":    [20.3, 27.7, 23.5, 17.3],
        "speed_tps": [61.5, 68.9, 81.9, 82.3],
    },
    "qwen3:8b-q4_K_M": {
        "color": "#F4A261",
        "node": "llm-01",
        "time_s":    [47.1, 24.7, 21.0, 35.1],
        "speed_tps": [45.2, 39.6, 55.5, 55.2],
    },
    "qwen3:14b-q4_K_M": {
        "color": "#9B59B6",
        "node": "llm-01",
        "time_s":    [60.6, 59.8, 39.2, 43.5],
        "speed_tps": [25.7, 25.8, 34.3, 34.2],
    },
    "qwen3:30b-a3b-q4_K_M": {
        "color": "#00E5FF",
        "node": "llm-02",
        "moe": True,
        "time_s":    [39.8, 36.6, 21.1, 23.1],
        "speed_tps": [53.3, 54.6, 72.7, 73.1],
    },
    "qwen3:32b-q4_K_M": {
        "color": "#E74C3C",
        "node": "llm-03",
        "time_s":    [215.0, 215.9, 98.6, 101.3],
        "speed_tps": [   7.0,   7.0, 16.0,  16.0],
    },
}

x_labels = ["Run 1\n(cold)", "Run 2\n(cold)", "Run 3\n(warm)", "Run 4\n(warm)"]

metrics = [
    ("time_s",    "Test 1 — Time (s)",       "Seconds", (0, 235)),
    ("speed_tps", "Test 1 — Speed (tok/s)",  "tok/s",   (0, 100)),
]

# ── Layout ────────────────────────────────────────────────────────────────────
fig, axes = plt.subplots(1, 2, figsize=(20, 8))
fig.patch.set_facecolor(BG)
fig.suptitle(
    "TEST 1 — Cold (no pre-load) vs Warm (pre-loaded)  |  RAG + PII scrub  |  llm-01 / llm-02 / llm-03",
    fontsize=14, fontweight="bold", y=1.02, color=TEXT,
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
        vals   = d[key]
        color  = d["color"]
        moe    = d.get("moe", False)
        marker = "D" if moe else "o"
        ls     = "--" if moe else "-"

        ax.plot(runs, vals, color=color, linewidth=2.2, linestyle=ls, zorder=2)
        for i, (x, y) in enumerate(zip(runs, vals)):
            cold = i < 2
            ax.plot(x, y,
                    marker=marker, markersize=9, color=color,
                    markerfacecolor=PANEL if cold else color,
                    markeredgewidth=2, zorder=4)
            unit = "s" if key == "time_s" else ""
            ax.annotate(f"{y}{unit}", (x, y),
                        textcoords="offset points",
                        xytext=(label_offsets.get(name, 0), 10),
                        ha="center", fontsize=11, fontweight="bold",
                        color=color, zorder=5)

    ax.set_xlim(0.5, 4.5)
    ax.set_xticks(runs)
    ax.set_xticklabels(x_labels, fontsize=13)
    ax.set_ylabel(ylabel)
    ax.set_title(title, fontsize=10)
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
    ct = np.mean(t[:2]); wt = np.mean(t[2:])
    cs = np.mean(s[:2]); ws = np.mean(s[2:])
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
out = "/Users/hanif/mac-llm-cluster/scripts/benchmarks/test1_cold_vs_warm.png"
plt.savefig(out, dpi=150, bbox_inches="tight", facecolor=BG)
print(f"Saved → {out}")
