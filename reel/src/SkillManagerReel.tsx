import {
  Audio,
  Sequence,
  interpolate,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { slide } from "@remotion/transitions/slide";
import { fade } from "@remotion/transitions/fade";
import { wipe } from "@remotion/transitions/wipe";
import { HeroScene } from "./scenes/HeroScene";
import { SearchScene } from "./scenes/SearchScene";
import { InstallScene } from "./scenes/InstallScene";
import { ThemeScene } from "./scenes/ThemeScene";
import { FeaturesScene } from "./scenes/FeaturesScene";
import { CtaScene } from "./scenes/CtaScene";

export const SkillManagerReel = () => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  return (
    <>
      {/* Background ambient pad — full duration, with fade in/out */}
      <Audio
        src={staticFile("ambient.wav")}
        volume={(f) => {
          const fadeInEnd = 1.5 * fps;
          const fadeOutStart = durationInFrames - 2 * fps;
          const volIn = interpolate(f, [0, fadeInEnd], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          });
          const volOut = interpolate(f, [fadeOutStart, durationInFrames], [1, 0], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          });
          return Math.min(volIn, volOut) * 0.25;
        }}
      />

      {/* Hero scene: pop when icon appears */}
      <Sequence from={0} durationInFrames={1 * fps} premountFor={fps}>
        <Audio src={staticFile("pop.wav")} volume={0.6} />
      </Sequence>

      {/* Transition 1: whoosh at ~frame 90 (hero -> search) */}
      <Sequence from={Math.floor(3 * fps)} durationInFrames={fps} premountFor={fps}>
        <Audio src={staticFile("whoosh.wav")} volume={0.5} />
      </Sequence>

      {/* Search scene: typing clicks */}
      {Array.from({ length: 14 }).map((_, i) => {
        const searchStart = 105 - 15; // scene 2 starts after transition overlap
        const typeFrame = searchStart + 8 + i * Math.floor(32 / 14);
        return (
          <Sequence
            key={`type-${i}`}
            from={typeFrame}
            durationInFrames={Math.floor(0.1 * fps)}
            premountFor={fps}
          >
            <Audio
              src={staticFile("type.wav")}
              volume={0.3 + Math.random() * 0.15}
            />
          </Sequence>
        );
      })}

      {/* Search results pop sounds */}
      {[0, 1, 2].map((i) => {
        const searchStart = 90;
        const popFrame = searchStart + 45 + i * 10;
        return (
          <Sequence
            key={`result-pop-${i}`}
            from={popFrame}
            durationInFrames={Math.floor(0.3 * fps)}
            premountFor={fps}
          >
            <Audio src={staticFile("pop.wav")} volume={0.35} />
          </Sequence>
        );
      })}

      {/* Transition 2: whoosh (search -> install) */}
      <Sequence from={Math.floor(6.3 * fps)} durationInFrames={fps} premountFor={fps}>
        <Audio src={staticFile("whoosh.wav")} volume={0.45} />
      </Sequence>

      {/* Install scene: toggle clicks */}
      <Sequence from={Math.floor(7.5 * fps)} durationInFrames={Math.floor(0.3 * fps)} premountFor={fps}>
        <Audio src={staticFile("pop.wav")} volume={0.5} />
      </Sequence>
      <Sequence from={Math.floor(8 * fps)} durationInFrames={Math.floor(0.3 * fps)} premountFor={fps}>
        <Audio src={staticFile("pop.wav")} volume={0.5} />
      </Sequence>

      {/* Install success chime */}
      <Sequence from={Math.floor(9 * fps)} durationInFrames={Math.floor(1 * fps)} premountFor={fps}>
        <Audio src={staticFile("success.wav")} volume={0.55} />
      </Sequence>

      {/* Transition 3: whoosh (install -> theme) */}
      <Sequence from={Math.floor(9.6 * fps)} durationInFrames={fps} premountFor={fps}>
        <Audio src={staticFile("whoosh.wav")} volume={0.4} />
      </Sequence>

      {/* Theme flip sound */}
      <Sequence from={Math.floor(11 * fps)} durationInFrames={Math.floor(0.5 * fps)} premountFor={fps}>
        <Audio src={staticFile("flip.wav")} volume={0.5} />
      </Sequence>

      {/* Transition 4: whoosh (theme -> features) */}
      <Sequence from={Math.floor(12.8 * fps)} durationInFrames={fps} premountFor={fps}>
        <Audio src={staticFile("whoosh.wav")} volume={0.4} />
      </Sequence>

      {/* Features scene: staggered pops */}
      {[0, 1, 2, 3, 4, 5].map((i) => {
        const featStart = Math.floor(13 * fps);
        const popFrame = featStart + 12 + i * 6;
        return (
          <Sequence
            key={`feat-pop-${i}`}
            from={popFrame}
            durationInFrames={Math.floor(0.3 * fps)}
            premountFor={fps}
          >
            <Audio src={staticFile("pop.wav")} volume={0.3} />
          </Sequence>
        );
      })}

      {/* Transition 5: whoosh (features -> cta) */}
      <Sequence from={Math.floor(15.5 * fps)} durationInFrames={fps} premountFor={fps}>
        <Audio src={staticFile("whoosh.wav")} volume={0.45} />
      </Sequence>

      {/* CTA: final success chime */}
      <Sequence from={Math.floor(16.3 * fps)} durationInFrames={Math.floor(1 * fps)} premountFor={fps}>
        <Audio src={staticFile("success.wav")} volume={0.5} />
      </Sequence>

      {/* Video scenes with transitions */}
      <TransitionSeries>
        <TransitionSeries.Sequence durationInFrames={105}>
          <HeroScene />
        </TransitionSeries.Sequence>

        <TransitionSeries.Transition
          presentation={slide({ direction: "from-bottom" })}
          timing={linearTiming({ durationInFrames: 15 })}
        />

        <TransitionSeries.Sequence durationInFrames={105}>
          <SearchScene />
        </TransitionSeries.Sequence>

        <TransitionSeries.Transition
          presentation={fade()}
          timing={linearTiming({ durationInFrames: 12 })}
        />

        <TransitionSeries.Sequence durationInFrames={100}>
          <InstallScene />
        </TransitionSeries.Sequence>

        <TransitionSeries.Transition
          presentation={wipe()}
          timing={linearTiming({ durationInFrames: 12 })}
        />

        <TransitionSeries.Sequence durationInFrames={100}>
          <ThemeScene />
        </TransitionSeries.Sequence>

        <TransitionSeries.Transition
          presentation={slide({ direction: "from-left" })}
          timing={linearTiming({ durationInFrames: 12 })}
        />

        <TransitionSeries.Sequence durationInFrames={90}>
          <FeaturesScene />
        </TransitionSeries.Sequence>

        <TransitionSeries.Transition
          presentation={fade()}
          timing={linearTiming({ durationInFrames: 15 })}
        />

        <TransitionSeries.Sequence durationInFrames={90}>
          <CtaScene />
        </TransitionSeries.Sequence>
      </TransitionSeries>
    </>
  );
};
