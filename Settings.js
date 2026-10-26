// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Shas Veeramani
function defaults() {
    return {motionEnabled: true, lightingEnabled: true, lightingMode: "automatic", weatherEnabled: false, weatherLocation: ""};
}
function normalize(input) {
    var result = defaults();
    if (!input || typeof input !== "object" || Array.isArray(input)) return result;
    for (var key of ["motionEnabled", "lightingEnabled", "weatherEnabled"])
        if (typeof input[key] === "boolean") result[key] = input[key];
    if (["automatic", "morning", "afternoon", "evening", "night"].indexOf(input.lightingMode) >= 0)
        result.lightingMode = input.lightingMode;
    if (typeof input.weatherLocation === "string")
        result.weatherLocation = input.weatherLocation.replace(/[\u0000-\u001f\u007f]/g, "").trim().slice(0, 120);
    return result;
}
function parse(raw) {
    try { return normalize(JSON.parse(raw)); } catch (_) { return defaults(); }
}
