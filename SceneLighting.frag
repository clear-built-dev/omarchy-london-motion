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
float lanternMask(vec2 p, vec2 center, vec2 size) {
    return 1.0 - smoothstep(0.65, 1.3, length((p - center) / size));
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
            lamps = max(lamps, lanternMask(p, vec2(57.0, 715.0), vec2(4.5, 6.5)));
            lamps = max(lamps, lanternMask(p, vec2(736.0, 680.0), vec2(5.0, 7.0)));
            lamps = max(lamps, lanternMask(p, vec2(895.0, 682.0), vec2(5.0, 7.0)));
            lamps = max(lamps, lanternMask(p, vec2(1390.0, 717.0), vec2(5.0, 7.0)));
            lamps = max(lamps, lanternMask(p, vec2(1600.0, 719.0), vec2(4.5, 6.5)));
        } else {
            lamps = max(lamps, lanternMask(p, vec2(118.0, 667.0), vec2(7.0, 10.0)));
            lamps = max(lamps, lanternMask(p, vec2(457.0, 701.0), vec2(6.0, 8.0)));
            lamps = max(lamps, lanternMask(p, vec2(724.0, 730.0), vec2(5.0, 7.0)));
            lamps = max(lamps, lanternMask(p, vec2(985.0, 747.0), vec2(4.5, 6.0)));
            lamps = max(lamps, lanternMask(p, vec2(1237.0, 769.0), vec2(4.0, 5.5)));
            lamps = max(lamps, lanternMask(p, vec2(1490.0, 776.0), vec2(4.0, 5.5)));
        }
        float night = (1.0 - ubuf.daylightAmount) * ubuf.lightingStrength;
        // Preserve the dark ink frame; light only the paler glass inside it.
        float glass = smoothstep(0.16, 0.55, grey);
        color = mix(color, vec3(0.75, 0.59, 0.35), lamps * night * glass * 0.72);
    }
    fragColor = vec4(clamp(color, 0.0, 1.0), pixel.a) * ubuf.qt_Opacity;
}
