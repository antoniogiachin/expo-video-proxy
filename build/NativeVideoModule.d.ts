import type { VideoPlayer } from './VideoPlayer.types';
import type { VideoThumbnail } from './VideoThumbnail';
type ExpoVideoModule = {
    VideoPlayer: typeof VideoPlayer;
    VideoThumbnail: typeof VideoThumbnail;
    isPictureInPictureSupported(): boolean;
    setVideoCacheSizeAsync(sizeBytes: number): Promise<void>;
    clearVideoCacheAsync(): Promise<void>;
    getCurrentVideoCacheSize(): number;
    startCMCDProxy(): Promise<void>;
    stopCMCDProxy(): void;
    isCMCDProxyRunning(): boolean;
    getCMCDProxyPort(): number;
    setCMCDProxyStaticHeaders(headers: Record<string, string>): void;
};
declare const _default: ExpoVideoModule;
export default _default;
//# sourceMappingURL=NativeVideoModule.d.ts.map