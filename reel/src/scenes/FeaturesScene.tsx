import {
  useCurrentFrame,
  useVideoConfig,
  interpolate,
  spring,
} from "remotion";
import { loadFont } from "@remotion/google-fonts/Inter";
import { colors } from "../theme";

const { fontFamily } = loadFont("normal", {
  weights: ["400", "600", "700"],
  subsets: ["latin"],
});

const features = [
  {
    icon: "M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z",
    title: "Cerca",
    desc: "GitHub Search integrato",
    color: colors.skillBlue,
  },
  {
    icon: "M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4",
    title: "Installa",
    desc: "Un click, due ambienti",
    color: colors.coworkPurple,
  },
  {
    icon: "M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15",
    title: "Aggiorna",
    desc: "Controlla nuove versioni",
    color: colors.successGreen,
  },
  {
    icon: "M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z",
    title: "Temi",
    desc: "Light, Dark, System",
    color: colors.resourceAmber,
  },
  {
    icon: "M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z",
    title: "Onboarding",
    desc: "Tutorial guidato",
    color: colors.accent,
  },
  {
    icon: "M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4",
    title: "Open Source",
    desc: "MIT License su GitHub",
    color: colors.warningOrange,
  },
];

export const FeaturesScene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const labelOpacity = interpolate(frame, [0, 12], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <div
      style={{
        width: "100%",
        height: "100%",
        background: colors.bg,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        fontFamily,
        overflow: "hidden",
        padding: "120px 50px 50px",
      }}
    >
      <div
        style={{
          opacity: labelOpacity,
          fontSize: 20,
          fontWeight: 600,
          color: colors.successGreen,
          letterSpacing: 3,
          textTransform: "uppercase",
          marginBottom: 20,
        }}
      >
        Funzionalità
      </div>

      <div
        style={{
          fontSize: 46,
          fontWeight: 700,
          color: colors.text,
          textAlign: "center",
          opacity: labelOpacity,
          marginBottom: 60,
          lineHeight: 1.2,
        }}
      >
        Tutto ciò che serve
      </div>

      {/* Features grid - 2x3 */}
      <div
        style={{
          display: "flex",
          flexWrap: "wrap",
          gap: 24,
          width: 860,
          justifyContent: "center",
        }}
      >
        {features.map((feature, i) => {
          const delay = 12 + i * 6;
          const scale = spring({
            frame: frame - delay,
            fps,
            config: { damping: 12 },
          });
          const opacity = interpolate(frame, [delay, delay + 8], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          });

          return (
            <div
              key={feature.title}
              style={{
                width: 400,
                opacity,
                transform: `scale(${Math.min(scale, 1)})`,
                background: colors.card,
                borderRadius: 20,
                border: `1px solid ${colors.cardBorder}`,
                padding: "30px 28px",
                display: "flex",
                alignItems: "flex-start",
                gap: 18,
              }}
            >
              <div
                style={{
                  width: 52,
                  height: 52,
                  minWidth: 52,
                  borderRadius: 14,
                  background: `${feature.color}18`,
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                }}
              >
                <svg
                  width="26"
                  height="26"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke={feature.color}
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <path d={feature.icon} />
                </svg>
              </div>
              <div>
                <div
                  style={{
                    fontSize: 22,
                    fontWeight: 700,
                    color: colors.text,
                    marginBottom: 4,
                  }}
                >
                  {feature.title}
                </div>
                <div
                  style={{
                    fontSize: 17,
                    color: colors.textSecondary,
                  }}
                >
                  {feature.desc}
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};
