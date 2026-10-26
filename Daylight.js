// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Shas Veeramani
// Fixed local-time lighting, independent of location and network services.
var presets = {
    morning: { brightness: 0.14, contrast: 0.10, saturation: -0.06, colorization: 0.10, color: "#b6cbd5", glow: "#e7c69b", glowAmount: 0.08 },
    afternoon: { brightness: 0.28, contrast: 0.16, saturation: 0.04, colorization: 0.07, color: "#d9d8c2", glow: "#d8e6df", glowAmount: 0.06 },
    evening: { brightness: 0.025, contrast: 0.06, saturation: 0.04, colorization: 0.12, color: "#c99b7a", glow: "#d59c73", glowAmount: 0.11 },
    night: { brightness: -0.045, contrast: 0.06, saturation: -0.10, colorization: 0.09, color: "#284766", glow: "#526d9d", glowAmount: 0.025 }
};
var anchors = [[0, "night"], [5, "night"], [7, "morning"], [11, "morning"], [13, "afternoon"], [16, "afternoon"], [18, "evening"], [20, "evening"], [22, "night"], [24, "night"]];

function mix(a, b, t) { return a + (b - a) * t; }
function mixHex(a, b, t) {
    var result = "#";
    for (var i = 1; i < 7; i += 2) {
        var channel = Math.round(mix(parseInt(a.slice(i, i + 2), 16), parseInt(b.slice(i, i + 2), 16), t)).toString(16);
        result += channel.length === 1 ? "0" + channel : channel;
    }
    return result;
}
function atHour(hour, override) {
    if (Object.prototype.hasOwnProperty.call(presets, override))
        return Object.assign({ label: override }, presets[override]);
    var h = Number(hour);
    if (!isFinite(h)) h = 0;
    h = ((h % 24) + 24) % 24;
    for (var i = 0; i < anchors.length - 1; i++) {
        var a = anchors[i], b = anchors[i + 1];
        if (h < a[0] || h >= b[0]) continue;
        var t = (h - a[0]) / (b[0] - a[0]);
        t = t * t * (3 - 2 * t);
        var result = { label: a[1] === b[1] ? a[1] : a[1] + " → " + b[1] };
        for (var key in presets[a[1]]) {
            result[key] = key === "color" || key === "glow"
                ? mixHex(presets[a[1]][key], presets[b[1]][key], t)
                : mix(presets[a[1]][key], presets[b[1]][key], t);
        }
        return result;
    }
    return Object.assign({ label: "night" }, presets.night);
}
