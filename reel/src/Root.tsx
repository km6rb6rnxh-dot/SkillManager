import { Composition } from "remotion";
import { SkillManagerReel } from "./SkillManagerReel";

export const RemotionRoot = () => {
  return (
    <Composition
      id="SkillManagerReel"
      component={SkillManagerReel}
      durationInFrames={540}
      fps={30}
      width={1080}
      height={1920}
    />
  );
};
