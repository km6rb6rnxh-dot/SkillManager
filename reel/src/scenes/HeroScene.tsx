import {
  useCurrentFrame,
  useVideoConfig,
  interpolate,
  spring,
  Sequence,
} from "remotion";
import { loadFont } from "@remotion/google-fonts/Inter";
import { colors } from "../theme";

const { fontFamily } = loadFont("normal", {
  weights: ["300", "400", "600", "800"],
  subsets: ["latin"],
});

export const HeroScene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const iconScale = spring({ frame, fps, config: { damping: 8 } });
  const iconRotate = interpolate(
    spring({ frame, fps, config: { damping: 12 } }),
    [0, 1],
    [-180, 0]
  );

  const titleY = interpolate(
    spring({ frame: frame - 12, fps, config: { damping: 200 } }),
    [0, 1],
    [80, 0]
  );
  const titleOpacity = interpolate(frame, [12, 28], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const subtitleY = interpolate(
    spring({ frame: frame - 24, fps, config: { damping: 200 } }),
    [0, 1],
    [60, 0]
  );
  const subtitleOpacity = interpolate(frame, [24, 40], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const taglineOpacity = interpolate(frame, [45, 60], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const taglineY = interpolate(
    spring({ frame: frame - 45, fps, config: { damping: 200 } }),
    [0, 1],
    [40, 0]
  );

  const glowPulse = interpolate(frame, [0, 60, 105], [0.3, 0.7, 0.3]);

  return (
    <div
      style={{
        width: "100%",
        height: "100%",
        backgroundColor: colors.bg,
        backgroundImage: `radial-gradient(ellipse at 50% 40%, rgba(99,102,241,${glowPulse * 0.3}) 0%, transparent 70%)`,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        fontFamily,
        overflow: "hidden",
      }}
    >
      {/* App Icon */}
      <div
        style={{
          width: 180,
          height: 180,
          borderRadius: 40,
          background: `linear-gradient(135deg, ${colors.gradient1}, ${colors.gradient2})`,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          transform: `scale(${iconScale}) rotate(${iconRotate}deg)`,
          boxShadow: `0 20px 60px rgba(99,102,241,0.4)`,
        }}
      >
        <svg width="100" height="100" viewBox="0 0 100 100">
          <path
            d="M50 15 L85 35 L85 65 L50 85 L15 65 L15 35 Z"
            fill="none"
            stroke="white"
            strokeWidth="4"
            strokeLinejoin="round"
          />
          <path
            d="M50 35 L67 45 L67 60 L50 70 L33 60 L33 45 Z"
            fill="white"
            opacity="0.9"
          />
          <circle cx="50" cy="52" r="8" fill={colors.gradient1} />
        </svg>
      </div>

      {/* Title */}
      <div
        style={{
          marginTop: 60,
          transform: `translateY(${titleY}px)`,
          opacity: titleOpacity,
          textAlign: "center",
        }}
      >
        <div
          style={{
            fontSize: 72,
            fontWeight: 800,
            color: colors.text,
            letterSpacing: -2,
            lineHeight: 1,
          }}
        >
          Skill
        </div>
        <div
          style={{
            fontSize: 72,
            fontWeight: 800,
            background: `linear-gradient(135deg, ${colors.gradient1}, ${colors.gradient2}, ${colors.gradient3})`,
            WebkitBackgroundClip: "text",
            WebkitTextFillColor: "transparent",
            letterSpacing: -2,
            lineHeight: 1.1,
          }}
        >
          Manager
        </div>
      </div>

      {/* Subtitle */}
      <div
        style={{
          marginTop: 40,
          transform: `translateY(${subtitleY}px)`,
          opacity: subtitleOpacity,
          fontSize: 32,
          fontWeight: 300,
          color: colors.textSecondary,
          textAlign: "center",
          maxWidth: 700,
          lineHeight: 1.4,
          padding: "0 60px",
        }}
      >
        Gestisci le skill di Claude
        <br />
        senza usare il terminale
      </div>

      {/* Tagline badge */}
      <div
        style={{
          marginTop: 50,
          opacity: taglineOpacity,
          transform: `translateY(${taglineY}px)`,
        }}
      >
        <div
          style={{
            padding: "14px 36px",
            borderRadius: 50,
            background: `linear-gradient(135deg, ${colors.gradient1}22, ${colors.gradient2}22)`,
            border: `1px solid ${colors.gradient1}44`,
            fontSize: 22,
            fontWeight: 600,
            color: colors.skillBlue,
            letterSpacing: 1,
          }}
        >
          macOS Native App
        </div>
      </div>
    </div>
  );
};
