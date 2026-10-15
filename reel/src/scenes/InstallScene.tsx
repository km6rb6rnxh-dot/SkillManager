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

export const InstallScene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const labelOpacity = interpolate(frame, [0, 12], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const cardScale = spring({
    frame: frame - 10,
    fps,
    config: { damping: 20, stiffness: 200 },
  });
  const cardOpacity = interpolate(frame, [10, 22], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const claudeToggleProgress = spring({
    frame: frame - 35,
    fps,
    config: { damping: 15 },
  });
  const coworkToggleProgress = spring({
    frame: frame - 50,
    fps,
    config: { damping: 15 },
  });

  const checkScale = spring({
    frame: frame - 70,
    fps,
    config: { damping: 8 },
  });
  const checkOpacity = interpolate(frame, [70, 78], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const successBannerY = interpolate(
    spring({ frame: frame - 75, fps, config: { damping: 200 } }),
    [0, 1],
    [60, 0]
  );
  const successOpacity = interpolate(frame, [75, 85], [0, 1], {
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
          color: colors.coworkPurple,
          letterSpacing: 3,
          textTransform: "uppercase",
          marginBottom: 20,
        }}
      >
        Installa
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
        Scegli dove installare
      </div>

      {/* Install card */}
      <div
        style={{
          width: 850,
          opacity: cardOpacity,
          transform: `scale(${Math.min(cardScale, 1)})`,
          background: colors.card,
          borderRadius: 24,
          border: `1px solid ${colors.cardBorder}`,
          padding: "40px 50px",
        }}
      >
        {/* Skill info */}
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 18,
            marginBottom: 40,
          }}
        >
          <div
            style={{
              width: 60,
              height: 60,
              borderRadius: 16,
              background: `linear-gradient(135deg, ${colors.skillBlue}, ${colors.coworkPurple})`,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            <svg width="30" height="30" viewBox="0 0 24 24" fill="white">
              <path d="M12 2L2 7L12 12L22 7L12 2Z" />
              <path d="M2 17L12 22L22 17" fill="none" stroke="white" strokeWidth="2" />
              <path d="M2 12L12 17L22 12" fill="none" stroke="white" strokeWidth="2" />
            </svg>
          </div>
          <div>
            <div style={{ fontSize: 28, fontWeight: 700, color: colors.text }}>
              remotion-video-creation
            </div>
            <div style={{ fontSize: 18, color: colors.textSecondary }}>
              affaan-m/ecc
            </div>
          </div>
        </div>

        {/* Toggle: Claude Code */}
        <ToggleRow
          label="Claude Code"
          color={colors.skillBlue}
          progress={claudeToggleProgress}
        />

        {/* Toggle: Cowork */}
        <div style={{ marginTop: 20 }}>
          <ToggleRow
            label="Cowork"
            color={colors.coworkPurple}
            progress={coworkToggleProgress}
          />
        </div>

        {/* Install button */}
        <div
          style={{
            marginTop: 40,
            display: "flex",
            justifyContent: "center",
          }}
        >
          <div
            style={{
              padding: "18px 80px",
              borderRadius: 16,
              background:
                checkScale > 0.5
                  ? colors.successGreen
                  : `linear-gradient(135deg, ${colors.gradient1}, ${colors.gradient2})`,
              fontSize: 24,
              fontWeight: 700,
              color: "white",
              display: "flex",
              alignItems: "center",
              gap: 12,
            }}
          >
            {checkScale > 0.5 ? (
              <>
                <svg
                  width="28"
                  height="28"
                  viewBox="0 0 24 24"
                  fill="none"
                  style={{ transform: `scale(${Math.min(checkScale, 1)})` }}
                >
                  <path
                    d="M5 13L9 17L19 7"
                    stroke="white"
                    strokeWidth="3"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </svg>
                Installata!
              </>
            ) : (
              "Installa"
            )}
          </div>
        </div>
      </div>

      {/* Success message */}
      <div
        style={{
          marginTop: 40,
          opacity: successOpacity,
          transform: `translateY(${successBannerY}px)`,
          fontSize: 22,
          color: colors.successGreen,
          fontWeight: 600,
          display: "flex",
          alignItems: "center",
          gap: 10,
        }}
      >
        <div
          style={{
            width: 10,
            height: 10,
            borderRadius: 5,
            background: colors.successGreen,
          }}
        />
        Skill attiva su entrambi gli ambienti
      </div>
    </div>
  );
};

const ToggleRow = ({
  label,
  color,
  progress,
}: {
  label: string;
  color: string;
  progress: number;
}) => {
  const isOn = progress > 0.5;
  const trackBg = isOn ? color : colors.bgLight;
  const knobX = interpolate(progress, [0, 1], [2, 38]);

  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        padding: "16px 0",
      }}
    >
      <div style={{ fontSize: 26, fontWeight: 600, color: colors.text }}>
        {label}
      </div>
      <div
        style={{
          width: 72,
          height: 38,
          borderRadius: 19,
          background: trackBg,
          border: isOn ? "none" : `2px solid ${colors.cardBorder}`,
          position: "relative",
          transition: "none",
        }}
      >
        <div
          style={{
            width: 30,
            height: 30,
            borderRadius: 15,
            background: "white",
            position: "absolute",
            top: isOn ? 4 : 2,
            left: knobX,
            boxShadow: "0 2px 6px rgba(0,0,0,0.3)",
          }}
        />
      </div>
    </div>
  );
};
