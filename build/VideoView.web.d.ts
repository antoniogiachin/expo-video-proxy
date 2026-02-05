import React from 'react';
import VideoPlayer from './VideoPlayer.web';
import type { VideoViewProps } from './VideoView.types';
type VideoViewHandle = {
    enterFullscreen: () => Promise<void>;
    exitFullscreen: () => Promise<void>;
    startPictureInPicture: () => Promise<void>;
    stopPictureInPicture: () => Promise<void>;
    nativeRef: React.RefObject<HTMLVideoElement | null>;
};
export declare function isPictureInPictureSupported(): boolean;
export declare const VideoView: React.ForwardRefExoticComponent<{
    player?: VideoPlayer;
} & VideoViewProps & React.RefAttributes<VideoViewHandle>>;
export default VideoView;
//# sourceMappingURL=VideoView.web.d.ts.map