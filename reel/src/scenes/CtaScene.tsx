import {
  useCurrentFrame,
  useVideoConfig,
  interpolate,
  spring,
} from "remotion";
import { loadFont } from "@remotion/google-fonts/Inter";
import { colors } from "../theme";

const { fontFamily } = loadFont("normal", {
  weights: ["300", "400", "600", "800"],
  subsets: ["latin"],
});

export const CtaScene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const starScale = spring({
    frame,
    fps,
    config: { damping: 8 },
  });

  const titleOpacity = interpolate(frame, [8, 20], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const titleY = interpolate(
    spring({ frame: frame - 8, fps, config: { damping: 200 } }),
    [0, 1],
    [50, 0]
  );

  const urlOpacity = interpolate(frame, [25, 38], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const urlScale = spring({
    frame: frame - 25,
    fps,
    config: { damping: 20, stiffness: 200 },
  });

  const badgeOpacity = interpolate(frame, [45, 55], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const badgeY = interpolate(
    spring({ frame: frame - 45, fps, config: { damping: 200 } }),
    [0, 1],
    [30, 0]
  );

  const pulse = interpolate(frame, [0, 45, 90], [1, 1.05, 1]);

  const orbitAngle = interpolate(frame, [0, 90], [0, 360]);

  return (
    <div
      style={{
        width: "100%",
        height: "100%",
        background: `radial-gradient(ellipse at 50% 50%, rgba(99,102,241,0.15) 0%, ${colors.bg} 70%)`,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        fontFamily,
        overflow: "hidden",
        position: "relative",
      }}
    >
      {/* Orbiting particles */}
      {[0, 1, 2, 3, 4, 5].map((i) => {
        const angle = orbitAngle + i * 60;
        const rad = (angle * Math.PI) / 180;
        const radius = 350;
        const x = 540 + Math.cos(rad) * radius;
        const y = 960 + Math.sin(rad) * radius * 0.5;
        const particleColors = [
          colors.skillBlue,
          colors.coworkPurple,
          colors.successGreen,
          colors.resourceAmber,
          colors.accent,
          colors.gradient3,
        ];
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: x - 6,
              top: y - 6,
              width: 12,
              height: 12,
              borderRadius: 6,
              background: particleColors[i],
              opacity: 0.4,
              boxShadow: `0 0 20px ${particleColors[i]}`,
            }}
          />
        );
      })}

      {/* Star/logo */}
      <div
        style={{
          transform: `scale(${starScale * pulse})`,
          marginBottom: 50,
        }}
      >
        <svg width="120" height="120" viewBox="0 0 120 120">
          <defs>
            <linearGradient
              id="starGrad"
              x1="0%"
              y1="0%"
              x2="100%"
              y2="100%"
            >
              <stop offset="0%" stopColor={colors.gradient1} />
              <stop offset="50%" stopColor={colors.gradient2} />
              <stop offset="100%" stopColor={colors.gradient3} />
            </linearGradient>
          </defs>
          <polygon
            points="60,8 72,45 110,45 79,67 90,105 60,82 30,105 41,67 10,45 48,45"
            fill="url(#starGrad)"
          />
        </svg>
      </div>

      {/* Title */}
      <div
        style={{
          opacity: titleOpacity,
          transform: `translateY(${titleY}px)`,
          textAlign: "center",
        }}
      >
        <div
          style={{
            fontSize: 56,
            fontWeight: 800,
            color: colors.text,
            lineHeight: 1.1,
            marginBottom: 16,
          }}
        >
          Inizia oggi
        </div>
        <div
          style={{
            fontSize: 28,
            fontWeight: 300,
            color: colors.textSecondary,
            lineHeight: 1.4,
          }}
        >
          Gratuito e open source
        </div>
      </div>

      {/* GitHub URL */}
      <div
        style={{
          marginTop: 60,
          opacity: urlOpacity,
          transform: `scale(${Math.min(urlScale, 1)})`,
        }}
      >
        <div
          style={{
            padding: "20px 48px",
            borderRadius: 20,
            background: colors.card,
            border: `2px solid ${colors.cardBorder}`,
            display: "flex",
            alignItems: "center",
            gap: 16,
          }}
        >
          <svg width="32" height="32" viewBox="0 0 24 24" fill={colors.text}>
            <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" />
          </svg>
          <div
            style={{
              fontSize: 24,
              fontWeight: 600,
              color: colors.text,
              letterSpacing: -0.5,
            }}
          >
            github.com/km6rb6rnxh-dot/SkillManager
          </div>
        </div>
      </div>

      {/* Badge */}
      <div
        style={{
          marginTop: 40,
          opacity: badgeOpacity,
          transform: `translateY(${badgeY}px)`,
          display: "flex",
          gap: 16,
        }}
      >
        <div
          style={{
            padding: "10px 24px",
            borderRadius: 12,
            background: `${colors.skillBlue}20`,
            border: `1px solid ${colors.skillBlue}40`,
            fontSize: 18,
            fontWeight: 600,
            color: colors.skillBlue,
          }}
        >
          SwiftUI
        </div>
        <div
          style={{
            padding: "10px 24px",
            borderRadius: 12,
            background: `${colors.coworkPurple}20`,
            border: `1px solid ${colors.coworkPurple}40`,
            fontSize: 18,
            fontWeight: 600,
            color: colors.coworkPurple,
          }}
        >
          macOS 26
        </div>
        <div
          style={{
            padding: "10px 24px",
            borderRadius: 12,
            background: `${colors.successGreen}20`,
            border: `1px solid ${colors.successGreen}40`,
            fontSize: 18,
            fontWeight: 600,
            color: colors.successGreen,
          }}
        >
          MIT
        </div>
      </div>
    </div>
  );
};
