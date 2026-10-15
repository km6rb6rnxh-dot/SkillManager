import {
  useCurrentFrame,
  useVideoConfig,
  interpolate,
  spring,
  Sequence,
} from "remotion";
import { loadFont } from "@remotion/google-fonts/Inter";
import { loadFont as loadMono } from "@remotion/google-fonts/JetBrainsMono";
import { colors } from "../theme";

const { fontFamily } = loadFont("normal", {
  weights: ["400", "600", "700"],
  subsets: ["latin"],
});
const { fontFamily: monoFamily } = loadMono("normal", {
  weights: ["400"],
  subsets: ["latin"],
});

const searchQuery = "remotion video";
const results = [
  {
    name: "remotion-video-creation",
    type: "Skill",
    author: "affaan-m/ecc",
    installs: "9.2K",
    color: colors.skillBlue,
  },
  {
    name: "react-video-toolkit",
    type: "Resource",
    author: "video-labs",
    installs: "3.1K",
    color: colors.resourceAmber,
  },
  {
    name: "motion-graphics-utils",
    type: "Skill",
    author: "design-tools",
    installs: "5.7K",
    color: colors.skillBlue,
  },
];

export const SearchScene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const labelOpacity = interpolate(frame, [0, 12], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const charsShown = Math.min(
    searchQuery.length,
    Math.floor(interpolate(frame, [8, 40], [0, searchQuery.length], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    }))
  );
  const typedText = searchQuery.slice(0, charsShown);
  const cursorVisible = Math.floor(frame / 8) % 2 === 0;

  const searchBarScale = spring({ frame, fps, config: { damping: 200 } });

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
      {/* Section label */}
      <div
        style={{
          opacity: labelOpacity,
          fontSize: 20,
          fontWeight: 600,
          color: colors.skillBlue,
          letterSpacing: 3,
          textTransform: "uppercase",
          marginBottom: 20,
        }}
      >
        Cerca Skill
      </div>

      <div
        style={{
          fontSize: 46,
          fontWeight: 700,
          color: colors.text,
          textAlign: "center",
          opacity: labelOpacity,
          marginBottom: 50,
          lineHeight: 1.2,
        }}
      >
        Trova e installa
        <br />
        in un click
      </div>

      {/* Search bar */}
      <div
        style={{
          width: 900,
          transform: `scale(${searchBarScale})`,
          background: colors.card,
          borderRadius: 20,
          border: `2px solid ${colors.cardBorder}`,
          padding: "24px 30px",
          display: "flex",
          alignItems: "center",
          gap: 16,
          marginBottom: 40,
        }}
      >
        <svg width="28" height="28" viewBox="0 0 24 24" fill="none">
          <circle
            cx="11"
            cy="11"
            r="7"
            stroke={colors.textSecondary}
            strokeWidth="2"
          />
          <path
            d="M16 16L20 20"
            stroke={colors.textSecondary}
            strokeWidth="2"
            strokeLinecap="round"
          />
        </svg>
        <div
          style={{
            fontSize: 28,
            fontFamily: monoFamily,
            color: colors.text,
          }}
        >
          {typedText}
          {cursorVisible && (
            <span style={{ color: colors.skillBlue }}>|</span>
          )}
        </div>
      </div>

      {/* Results */}
      {results.map((result, i) => {
        const delay = 45 + i * 10;
        const resultScale = spring({
          frame: frame - delay,
          fps,
          config: { damping: 20, stiffness: 200 },
        });
        const resultOpacity = interpolate(frame, [delay, delay + 8], [0, 1], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        });
        const resultX = interpolate(
          spring({ frame: frame - delay, fps, config: { damping: 200 } }),
          [0, 1],
          [60, 0]
        );

        return (
          <div
            key={result.name}
            style={{
              width: 900,
              opacity: resultOpacity,
              transform: `translateX(${resultX}px) scale(${Math.min(resultScale, 1)})`,
              background: colors.bgLight,
              borderRadius: 16,
              border: `1px solid ${colors.cardBorder}`,
              padding: "22px 28px",
              marginBottom: 14,
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
            }}
          >
            <div style={{ display: "flex", alignItems: "center", gap: 16 }}>
              <div
                style={{
                  width: 14,
                  height: 14,
                  borderRadius: 7,
                  background: result.color,
                  boxShadow: `0 0 12px ${result.color}66`,
                }}
              />
              <div>
                <div
                  style={{
                    fontSize: 24,
                    fontWeight: 600,
                    color: colors.text,
                  }}
                >
                  {result.name}
                </div>
                <div
                  style={{
                    fontSize: 18,
                    color: colors.textSecondary,
                    marginTop: 2,
                  }}
                >
                  {result.author}
                </div>
              </div>
            </div>
            <div style={{ display: "flex", alignItems: "center", gap: 20 }}>
              <div
                style={{
                  fontSize: 16,
                  fontWeight: 600,
                  color: result.color,
                  padding: "5px 14px",
                  borderRadius: 8,
                  background: `${result.color}18`,
                }}
              >
                {result.type}
              </div>
              <div
                style={{ fontSize: 18, color: colors.textSecondary }}
              >
                {result.installs}
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
};
