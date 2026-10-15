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

export const ThemeScene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const labelOpacity = interpolate(frame, [0, 12], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const flipProgress = interpolate(frame, [30, 55], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const showingDark = flipProgress < 0.5;

  const rotateY = showingDark
    ? interpolate(flipProgress, [0, 0.5], [0, 90], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      })
    : interpolate(flipProgress, [0.5, 1], [-90, 0], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      });

  const lightCardOpacity = showingDark ? 0 : 1;
  const darkCardOpacity = showingDark ? 1 : 0;

  const cardScale = spring({
    frame: frame - 10,
    fps,
    config: { damping: 200 },
  });

  const shimmer = interpolate(frame, [55, 100], [-200, 1200], {
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
          color: colors.resourceAmber,
          letterSpacing: 3,
          textTransform: "uppercase",
          marginBottom: 20,
        }}
      >
        Temi
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
        Light & Dark
      </div>

      {/* Theme cards container */}
      <div
        style={{
          width: 800,
          height: 900,
          perspective: "1200px",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          transform: `scale(${cardScale})`,
        }}
      >
        {/* Dark theme card */}
        <div
          style={{
            width: 750,
            height: 850,
            position: "absolute",
            borderRadius: 28,
            background: "#1A1A24",
            border: "1px solid #2E2E3E",
            padding: "40px 35px",
            opacity: darkCardOpacity,
            transform: `rotateY(${showingDark ? 0 : rotateY}deg)`,
            boxShadow: "0 30px 80px rgba(0,0,0,0.5)",
            overflow: "hidden",
          }}
        >
          <MockApp dark />
          <div
            style={{
              position: "absolute",
              bottom: 30,
              left: 0,
              right: 0,
              textAlign: "center",
              fontSize: 22,
              fontWeight: 600,
              color: "#9CA3AF",
            }}
          >
            Dark Mode
          </div>
        </div>

        {/* Light theme card */}
        <div
          style={{
            width: 750,
            height: 850,
            position: "absolute",
            borderRadius: 28,
            background: "#F8F9FA",
            border: "1px solid #E5E7EB",
            padding: "40px 35px",
            opacity: lightCardOpacity,
            transform: `rotateY(${showingDark ? rotateY : 0}deg)`,
            boxShadow: "0 30px 80px rgba(0,0,0,0.2)",
            overflow: "hidden",
          }}
        >
          <MockApp dark={false} />
          <div
            style={{
              position: "absolute",
              bottom: 30,
              left: 0,
              right: 0,
              textAlign: "center",
              fontSize: 22,
              fontWeight: 600,
              color: "#6B7280",
            }}
          >
            Light Mode
          </div>
          {/* Shimmer effect */}
          <div
            style={{
              position: "absolute",
              top: 0,
              left: shimmer,
              width: 120,
              height: "100%",
              background:
                "linear-gradient(90deg, transparent, rgba(255,255,255,0.3), transparent)",
              transform: "skewX(-15deg)",
            }}
          />
        </div>
      </div>
    </div>
  );
};

const MockApp = ({ dark }: { dark: boolean }) => {
  const bg = dark ? "#22222E" : "#FFFFFF";
  const text = dark ? "#FFFFFF" : "#1F2937";
  const textSec = dark ? "#9CA3AF" : "#6B7280";
  const border = dark ? "#2E2E3E" : "#E5E7EB";
  const sidebar = dark ? "#1A1A24" : "#F3F4F6";

  return (
    <div style={{ display: "flex", height: 720, gap: 0, borderRadius: 16, overflow: "hidden", border: `1px solid ${border}` }}>
      {/* Sidebar */}
      <div
        style={{
          width: 220,
          background: sidebar,
          padding: "20px 14px",
          borderRight: `1px solid ${border}`,
          display: "flex",
          flexDirection: "column",
          gap: 6,
        }}
      >
        <div style={{ fontSize: 16, fontWeight: 700, color: text, marginBottom: 12 }}>
          Skills
        </div>
        {["remotion-video", "react-best", "deploy-aws"].map((name, i) => (
          <div
            key={name}
            style={{
              padding: "10px 12px",
              borderRadius: 10,
              background: i === 0 ? `${colors.skillBlue}20` : "transparent",
              fontSize: 13,
              color: i === 0 ? colors.skillBlue : textSec,
              fontWeight: i === 0 ? 600 : 400,
            }}
          >
            {name}
          </div>
        ))}
      </div>
      {/* Main content */}
      <div style={{ flex: 1, padding: "20px 18px" }}>
        <div style={{ fontSize: 20, fontWeight: 700, color: text, marginBottom: 8 }}>
          remotion-video
        </div>
        <div style={{ fontSize: 12, color: textSec, marginBottom: 18 }}>
          affaan-m/ecc
        </div>
        <div style={{ display: "flex", gap: 8, marginBottom: 20 }}>
          <div
            style={{
              padding: "6px 14px",
              borderRadius: 8,
              background: colors.skillBlue,
              fontSize: 12,
              fontWeight: 600,
              color: "white",
            }}
          >
            Claude Code
          </div>
          <div
            style={{
              padding: "6px 14px",
              borderRadius: 8,
              background: colors.coworkPurple,
              fontSize: 12,
              fontWeight: 600,
              color: "white",
            }}
          >
            Cowork
          </div>
        </div>
        {[1, 2, 3].map((line) => (
          <div
            key={line}
            style={{
              height: 10,
              width: `${90 - line * 15}%`,
              borderRadius: 5,
              background: border,
              marginBottom: 10,
            }}
          />
        ))}
      </div>
    </div>
  );
};
