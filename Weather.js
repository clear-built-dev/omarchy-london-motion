// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Shas Veeramani
// Weather codes follow the wttr.in JSON response used by Omarchy's weather panel.
function locationQuery(raw) {
    try {
        var place = JSON.parse(raw || "{}");
        if (!place || typeof place !== "object") return "";
        if (place.latitude !== null && place.longitude !== null && place.latitude !== undefined && place.longitude !== undefined
                && String(place.latitude).trim() !== "" && String(place.longitude).trim() !== ""
                && isFinite(Number(place.latitude)) && isFinite(Number(place.longitude))
                && Math.abs(Number(place.latitude)) <= 90 && Math.abs(Number(place.longitude)) <= 180)
            return encodeURIComponent(Number(place.latitude) + "," + Number(place.longitude));
        return typeof place.name === "string" ? encodeURIComponent(place.name.trim()) : "";
    } catch (_) { return ""; }
}
function isFresh(fetchedAt, now) {
    var age = now - fetchedAt;
    return fetchedAt > 0 && age >= 0 && age < 60 * 60 * 1000;
}
function conditionForCode(code) {
    code = Number(code);
    if (code === 113) return "clear";
    if ([116,119,122].indexOf(code) >= 0) return "cloudy";
    if ([143,248,260].indexOf(code) >= 0) return "fog";
    if ([200,386,389,392,395].indexOf(code) >= 0) return "storm";
    if ([179,182,185,227,230,281,284,311,314,317,320,323,326,329,332,335,338,350,362,365,368,371,374,377].indexOf(code) >= 0) return "snow";
    if ([176,263,266,293,296,299,302,305,308,353,356,359].indexOf(code) >= 0) return "rain";
    return "none";
}
function parse(raw) {
    try {
        var data = JSON.parse(raw);
        if (data && data.data) data = data.data;
        var current = data && data.current_condition && data.current_condition[0];
        if (!current || current.weatherCode === undefined || current.weatherCode === null || current.weatherCode === "") return null;
        var condition = conditionForCode(current.weatherCode);
        if (condition === "none") return null;
        var area = data.nearest_area && data.nearest_area[0];
        var latitude = area && typeof area.latitude !== "undefined" && String(area.latitude).trim() !== "" ? Number(area.latitude) : NaN;
        var longitude = area && typeof area.longitude !== "undefined" && String(area.longitude).trim() !== "" ? Number(area.longitude) : NaN;
        return { condition: condition, code: Number(current.weatherCode), wind: Math.max(0, Math.min(150, Number(current.windspeedKmph) || 0)),
            latitude: isFinite(latitude) && Math.abs(latitude) <= 90 ? latitude : null,
            longitude: isFinite(longitude) && Math.abs(longitude) <= 180 ? longitude : null,
            location: area && area.areaName && area.areaName[0] ? String(area.areaName[0].value || "") : "",
            observation: String(current.localObsDateTime || current.observation_time || "") };
    } catch (_) { return null; }
}
function look(condition) {
    var looks = {
        none:   { brightness: 0, contrast: 0, saturation: 0, cloud: 0, fog: 0, rain: 0, snow: 0 },
        clear:  { brightness: 0.015, contrast: 0.015, saturation: 0.02, cloud: 0, fog: 0, rain: 0, snow: 0 },
        cloudy: { brightness: -0.045, contrast: -0.025, saturation: -0.15, cloud: 0.10, fog: 0, rain: 0, snow: 0 },
        rain:   { brightness: -0.07, contrast: -0.025, saturation: -0.22, cloud: 0.15, fog: 0.025, rain: 0.12, snow: 0 },
        fog:    { brightness: 0.025, contrast: -0.18, saturation: -0.25, cloud: 0.04, fog: 0.23, rain: 0, snow: 0 },
        snow:   { brightness: 0.035, contrast: -0.07, saturation: -0.20, cloud: 0.08, fog: 0.055, rain: 0, snow: 0.23 },
        storm:  { brightness: -0.11, contrast: 0.03, saturation: -0.30, cloud: 0.23, fog: 0.035, rain: 0.18, snow: 0 }
    };
    return looks[condition] || looks.none;
}
