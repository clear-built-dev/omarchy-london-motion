// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Shas Veeramani
// Fixed local-time lighting, independent of location and network services.
var presets = {
    morning: { brightness: 0.18, contrast: 0.08, saturation: -0.04, colorization: 0.10, color: "#b6cbd5", glow: "#e7c69b", glowAmount: 0.055, dayAmount: 1 },
    afternoon: { brightness: 0.34, contrast: 0.10, saturation: 0.04, colorization: 0.07, color: "#d9d8c2", glow: "#d8e6df", glowAmount: 0.035, dayAmount: 1 },
    evening: { brightness: 0.025, contrast: 0.06, saturation: 0.04, colorization: 0.12, color: "#c99b7a", glow: "#d59c73", glowAmount: 0.08, dayAmount: 0.18 },
    night: { brightness: -0.045, contrast: 0.06, saturation: -0.10, colorization: 0.09, color: "#284766", glow: "#526d9d", glowAmount: 0.025, dayAmount: 0 }
};
var anchors = [[0, "night"], [5, "night"], [7, "morning"], [11, "morning"], [13, "afternoon"], [16, "afternoon"], [18, "evening"], [20, "evening"], [22, "night"], [24, "night"]];

function mix(a, b, t) { return a + (b - a) * t; }
function smooth(a, b, value) {
    var t = Math.max(0, Math.min(1, (value - a) / (b - a)));
    return t * t * (3 - 2 * t);
}
function original() {
    return {label: "original", brightness: 0, contrast: 0, saturation: 0, colorization: 0, color: "#ffffff", glow: "#ffffff", glowAmount: 0, dayAmount: 0};
}
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

// NOAA approximate solar-position equations, evaluated in UTC so the city's
// longitude and the computer's time zone cannot be accidentally counted twice.
// https://gml.noaa.gov/grad/solcalc/solareqns.PDF
function solarPosition(date, latitude, longitude) {
    var year = date.getUTCFullYear();
    var days = year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0) ? 366 : 365;
    var day = Math.floor((Date.UTC(year, date.getUTCMonth(), date.getUTCDate()) - Date.UTC(year, 0, 1)) / 86400000) + 1;
    var hour = date.getUTCHours() + date.getUTCMinutes() / 60 + date.getUTCSeconds() / 3600;
    var gamma = 2 * Math.PI / days * (day - 1 + (hour - 12) / 24);
    var eq = 229.18 * (0.000075 + 0.001868 * Math.cos(gamma) - 0.032077 * Math.sin(gamma)
             - 0.014615 * Math.cos(2 * gamma) - 0.040849 * Math.sin(2 * gamma));
    var dec = 0.006918 - 0.399912 * Math.cos(gamma) + 0.070257 * Math.sin(gamma)
            - 0.006758 * Math.cos(2 * gamma) + 0.000907 * Math.sin(2 * gamma)
            - 0.002697 * Math.cos(3 * gamma) + 0.00148 * Math.sin(3 * gamma);
    var solarMinutes = ((hour * 60 + eq + 4 * longitude) % 1440 + 1440) % 1440;
    var angle = solarMinutes / 4 - 180;
    var rad = Math.PI / 180;
    var sine = Math.sin(latitude * rad) * Math.sin(dec) + Math.cos(latitude * rad) * Math.cos(dec) * Math.cos(angle * rad);
    return {elevation: Math.asin(Math.max(-1, Math.min(1, sine))) / rad, hourAngle: angle};
}
function blend(a, b, t) {
    var out = {};
    for (var key in presets.morning)
        out[key] = key === "color" || key === "glow" ? mixHex(a[key], b[key], t) : mix(a[key], b[key], t);
    return out;
}
function atTime(date, location, override) {
    if (Object.prototype.hasOwnProperty.call(presets, override)) return atHour(0, override);
    if (!location || location.latitude === null || location.longitude === null
            || typeof location.latitude !== "number" || typeof location.longitude !== "number"
            || !isFinite(location.latitude) || !isFinite(location.longitude)
            || Math.abs(location.latitude) > 90 || Math.abs(location.longitude) > 180)
        return atHour(date.getHours() + date.getMinutes() / 60, "");
    var sun = solarPosition(date, location.latitude, location.longitude);
    var rising = sun.hourAngle < 0;
    var result = blend(presets.morning, presets.afternoon, smooth(-60, 20, sun.hourAngle));
    if (!rising) result = blend(result, presets.evening, (1 - smooth(0, 18, sun.elevation)) * smooth(0, 30, sun.hourAngle));
    result = blend(presets.night, result, smooth(-6, 0, sun.elevation));
    result.dayAmount = smooth(-3, 3, sun.elevation);
    result.label = sun.elevation <= -6 ? "night" : sun.elevation < 0 ? (rising ? "dawn" : "dusk") : rising ? "morning" : sun.elevation < 12 ? "evening" : "afternoon";
    result.solarElevation = sun.elevation;
    return result;
}
