#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float brightness;
    float contrast;
    float saturation;
    float colorization;
    vec4 colorizationColor;
    float daylightAmount;
    float sceneKind;
    float lightingStrength;
    float flagPhase;
    float flagStrength;
    float skyOnly;
} ubuf;
layout(binding = 1) uniform sampler2D source;

float rectangle(vec2 p, vec2 low, vec2 high) {
    return step(low.x, p.x) * step(low.y, p.y) * step(p.x, high.x) * step(p.y, high.y);
}
float circleMask(vec2 p, vec2 center, float radius) {
    return 1.0 - smoothstep(radius - 2.0, radius + 2.0, distance(p, center));
}
// Tight glass shapes, entirely inside the drawn metal frame.
float ovalGlass(vec2 p, vec2 center, vec2 size) {
    return 1.0 - smoothstep(0.70, 1.0, length((p - center) / size));
}
float glassPane(vec2 p, vec2 top, vec2 bottom, float topHalf, float bottomHalf) {
    float t = clamp((p.y - top.y) / (bottom.y - top.y), 0.0, 1.0);
    float center = mix(top.x, bottom.x, t);
    float halfWidth = mix(topHalf, bottomHalf, t);
    return smoothstep(top.y, top.y + 0.45, p.y)
         * (1.0 - smoothstep(bottom.y - 0.45, bottom.y, p.y))
         * (1.0 - smoothstep(halfWidth - 0.35, halfWidth, abs(p.x - center)));
}

void main() {
    // Deform the cloth in this same full-scene texture lookup. A separate
    // Canvas patch resamples the image independently and can create a seam
    // even where its displacement is zero. The pole is never displaced.
    vec2 sceneUV = ubuf.skyOnly > 0.5 ? vec2(qt_TexCoord0.x, 0.0) : qt_TexCoord0;
    vec2 sampleUV = sceneUV;
    if (ubuf.sceneKind > 0.5) {
        vec2 p = sampleUV * vec2(1672.0, 941.0);
        float start = ubuf.sceneKind < 1.5 ? 953.0 : 596.0;
        float edge = ubuf.sceneKind < 1.5 ? 984.0 : 621.0;
        float top = ubuf.sceneKind < 1.5 ? 456.0 : 346.0;
        float along = clamp((p.x - start) / (edge - start), 0.0, 1.0);
        float horizontal = smoothstep(0.0, 0.25, along)
                         * (1.0 - smoothstep(edge + 3.0, start + 54.0, p.x));
        float vertical = smoothstep(top, top + 12.0, p.y)
                       * (1.0 - smoothstep(top + 51.0, top + 66.0, p.y));
        // A visible ripple at laptop scale, with zero displacement at the pole.
        float shift = ubuf.flagStrength * 4.5 * horizontal * vertical * sin(along * 7.0 - ubuf.flagPhase);
        sampleUV.y += shift / 941.0;
    }
    vec4 pixel = texture(source, sampleUV);
    if (ubuf.skyOnly > 0.5) {
        // Average fine paper grain across the sky strip so extending one row
        // cannot turn its individual speckles into vertical streaks.
        pixel = vec4(0.0);
        for (int tap = -4; tap <= 4; ++tap)
            pixel += texture(source, vec2(clamp(sampleUV.x + float(tap) * 2.0 / 1672.0, 0.0, 1.0), 0.0)) / 9.0;
    }
    vec3 color = pixel.rgb;
    float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
    // Isolate the amber emission baked into the pencil art. The green/blue
    // separation deliberately excludes the red bus, telephone box and flags.
    float warm = smoothstep(0.008, 0.06, color.r - color.b)
               * smoothstep(0.005, 0.035, color.g - color.b)
               * smoothstep(0.08, 0.22, luminance);
    float region;
    float lampCore = 0.0;
    if (ubuf.sceneKind < 0.5) {
        vec2 p = sceneUV * vec2(3840.0, 2160.0);
        region = max(rectangle(p, vec2(300.0, 1450.0), vec2(1660.0, 1670.0)),
                     smoothstep(1650.0, 1700.0, p.y));
        lampCore = max(lampCore, circleMask(p, vec2(240.0, 1445.8), 13.0));
        lampCore = max(lampCore, circleMask(p, vec2(880.0, 1453.7), 13.0));
        lampCore = max(lampCore, circleMask(p, vec2(1830.0, 1469.2), 13.0));
        lampCore = max(lampCore, circleMask(p, vec2(2950.0, 1494.8), 13.0));
        lampCore = max(lampCore, circleMask(p, vec2(3580.0, 1502.3), 13.0));
        // Big Ben's face changes from warm night illumination to pale daylight.
        region = max(region, circleMask(p, vec2(1578.0, 1178.0), 28.0));
        region = max(region, lampCore);
    } else {
        // New artwork is already unlit: no warm-pixel suppression is needed.
        region = 0.0;
    }
    float emission = max(warm * region, lampCore * smoothstep(0.1, 0.35, luminance));
    // Retain texture, but replace luminous amber with shaded glass/stone.
    // The original lit pixels return continuously as daylight recedes.
    vec3 unlit = vec3(0.145, 0.185, 0.215) * (0.75 + luminance * 0.35);
    color = mix(color, unlit, clamp(emission * ubuf.daylightAmount, 0.0, 1.0));
    luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(vec3(luminance), color, max(0.0, 1.0 + ubuf.saturation));
    float tintLuminance = max(0.1, dot(ubuf.colorizationColor.rgb, vec3(0.2126, 0.7152, 0.0722)));
    color = mix(color, color * ubuf.colorizationColor.rgb / tintLuminance, ubuf.colorization);
    color = (color - vec3(0.5)) * (1.0 + ubuf.contrast) + vec3(0.5 + ubuf.brightness);
    if (ubuf.sceneKind > 0.5) {
        // Translate light paper into the London scene's atmospheric slate palette.
        // Preserve the luminance ordering and full-resolution pen edges: this is
        // a colour mapping, without blur, resampling, or regenerated linework.
        float grey = dot(pixel.rgb, vec3(0.2126, 0.7152, 0.0722));
        float day = mix(0.30, ubuf.daylightAmount, ubuf.lightingStrength);
        float horizon = smoothstep(0.0, 0.68, sceneUV.y);
        vec3 daySky = mix(vec3(0.29, 0.36, 0.42), vec3(0.50, 0.58, 0.61), horizon);
        vec3 nightSky = mix(vec3(0.045, 0.080, 0.115), vec3(0.19, 0.26, 0.31), horizon);
        // The road falls back into darker slate below the architectural skyline.
        float foreground = smoothstep(0.78, 1.0, sceneUV.y);
        daySky = mix(daySky, vec3(0.33, 0.41, 0.46), foreground * 0.65);
        nightSky = mix(nightSky, vec3(0.09, 0.15, 0.20), foreground * 0.65);
        vec3 substrate = mix(nightSky, daySky, day);
        vec3 ink = mix(vec3(0.025, 0.055, 0.080), vec3(0.10, 0.16, 0.21), day);
        // Keep natural grain faint while giving the architectural strokes contrast.
        float tone = clamp((grey - 0.16) / 0.66, 0.0, 1.0);
        color = mix(ink, substrate, pow(tone, 1.12));
        float tint = ubuf.colorization * ubuf.lightingStrength;
        color = mix(color, color * ubuf.colorizationColor.rgb / tintLuminance, tint);
        // Preserve the small red phone box and coloured flag accents.
        float red = smoothstep(0.035, 0.10, pixel.r - pixel.g)
                  * smoothstep(0.04, 0.12, pixel.r - pixel.b);
        float blue = smoothstep(0.04, 0.12, pixel.b - pixel.r);
        vec3 accent = pixel.rgb * mix(0.50, 0.88, day);
        color = mix(color, accent, max(red, blue) * 0.82);
        color += vec3(ubuf.brightness * 0.07);
        // A few precise lantern glass masks give a soft drawn amber highlight.
        // Building windows stay dark; the drawing does not contain interiors.
        vec2 p = sceneUV * vec2(1672.0, 941.0);
        float lamps = 0.0;
        if (ubuf.sceneKind < 1.5) {
            // Individual glass faces on the five front multi-lantern posts.
            lamps = max(lamps, ovalGlass(p, vec2(58.50, 690.00), vec2(1.80, 2.40)));
            lamps = max(lamps, ovalGlass(p, vec2(50.50, 703.50), vec2(1.80, 2.40)));
            lamps = max(lamps, ovalGlass(p, vec2(58.00, 702.20), vec2(1.40, 1.80)));
            lamps = max(lamps, ovalGlass(p, vec2(66.60, 703.50), vec2(1.80, 2.40)));
            lamps = max(lamps, ovalGlass(p, vec2(738.00, 673.00), vec2(1.50, 2.00)));
            lamps = max(lamps, ovalGlass(p, vec2(728.00, 685.80), vec2(1.60, 2.20)));
            lamps = max(lamps, ovalGlass(p, vec2(737.70, 684.50), vec2(1.60, 2.30)));
            lamps = max(lamps, ovalGlass(p, vec2(747.00, 685.80), vec2(1.50, 2.10)));
            lamps = max(lamps, ovalGlass(p, vec2(896.00, 672.00), vec2(1.40, 2.10)));
            lamps = max(lamps, ovalGlass(p, vec2(886.00, 685.20), vec2(1.50, 2.20)));
            lamps = max(lamps, ovalGlass(p, vec2(896.00, 683.80), vec2(1.70, 2.00)));
            lamps = max(lamps, ovalGlass(p, vec2(906.00, 685.50), vec2(1.60, 2.00)));
            lamps = max(lamps, ovalGlass(p, vec2(1390.00, 708.00), vec2(1.50, 2.10)));
            lamps = max(lamps, ovalGlass(p, vec2(1381.50, 720.50), vec2(1.60, 2.00)));
            lamps = max(lamps, ovalGlass(p, vec2(1390.00, 720.20), vec2(1.70, 2.00)));
            lamps = max(lamps, ovalGlass(p, vec2(1399.00, 721.00), vec2(1.60, 2.20)));
            lamps = max(lamps, ovalGlass(p, vec2(1600.00, 715.80), vec2(1.50, 1.90)));
            lamps = max(lamps, ovalGlass(p, vec2(1591.00, 729.00), vec2(1.60, 2.00)));
            lamps = max(lamps, ovalGlass(p, vec2(1600.00, 728.30), vec2(1.60, 2.00)));
            lamps = max(lamps, ovalGlass(p, vec2(1609.00, 728.50), vec2(1.50, 2.00)));
        } else {
            // Six Windsor panes: follow their taper, not the neighbouring foliage.
            lamps = max(lamps, glassPane(p, vec2(121.00, 661.00), vec2(121.00, 679.00), 10.00, 6.00));
            lamps = max(lamps, glassPane(p, vec2(456.00, 699.00), vec2(456.00, 712.00), 7.00, 4.00));
            lamps = max(lamps, glassPane(p, vec2(724.50, 730.00), vec2(724.50, 739.00), 4.50, 3.00));
            lamps = max(lamps, glassPane(p, vec2(999.00, 755.00), vec2(999.00, 764.00), 4.20, 2.60));
            lamps = max(lamps, glassPane(p, vec2(1291.00, 778.00), vec2(1291.00, 785.00), 3.70, 2.60));
            lamps = max(lamps, glassPane(p, vec2(1490.00, 780.00), vec2(1490.00, 788.00), 4.50, 2.70));
        }
        float night = (1.0 - ubuf.daylightAmount) * ubuf.lightingStrength;
        // Preserve the dark ink frame; light only the paler glass inside it.
        float glass = smoothstep(0.35, 0.72, grey);
        color = mix(color, vec3(0.75, 0.59, 0.35), lamps * night * glass * 0.72);
    }
    fragColor = vec4(clamp(color, 0.0, 1.0), pixel.a) * ubuf.qt_Opacity;
}
