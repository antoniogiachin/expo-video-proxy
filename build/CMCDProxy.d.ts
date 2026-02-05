/**
 * CMCD (Common Media Client Data) data structure for generating headers.
 * Based on CTA-5004 specification.
 */
export type CmcdData = {
    /**
     * Session ID - A unique string identifying the current playback session.
     */
    sid?: string;
    /**
     * Content ID - A unique string identifying the current content.
     */
    cid?: string;
    /**
     * Encoded bitrate - The encoded bitrate of the audio/video object being requested (kbps).
     */
    br?: number;
    /**
     * Object duration - The playback duration of the object being requested (milliseconds).
     */
    d?: number;
    /**
     * Object type - The type of object being requested:
     * - 'm' = manifest
     * - 'a' = audio only
     * - 'v' = video only
     * - 'av' = muxed audio/video
     * - 'i' = init segment
     * - 'c' = caption/subtitle
     * - 'k' = encryption key
     * - 'o' = other
     */
    ot?: 'm' | 'a' | 'v' | 'av' | 'i' | 'c' | 'k' | 'o';
    /**
     * Top bitrate - The highest bitrate rendition available (kbps).
     */
    tb?: number;
    /**
     * Buffer length - The buffer length in milliseconds.
     */
    bl?: number;
    /**
     * Deadline - The time remaining until rebuffer (milliseconds).
     */
    dl?: number;
    /**
     * Measured throughput - The throughput between client and server (kbps).
     */
    mtp?: number;
    /**
     * Next object request - Relative path of the next object to be requested.
     */
    nor?: string;
    /**
     * Next range request - Byte range of the next object.
     */
    nrr?: string;
    /**
     * Startup - true if the object is needed urgently due to startup/seek/recovery.
     */
    su?: boolean;
    /**
     * Buffer starvation - true if a rebuffering event occurred.
     */
    bs?: boolean;
    /**
     * Playback rate - 1 = real-time, 2 = double speed, 0 = not playing.
     */
    pr?: number;
    /**
     * Stream format - The streaming format:
     * - 'd' = DASH
     * - 'h' = HLS
     * - 's' = Smooth Streaming
     * - 'o' = other
     */
    sf?: 'd' | 'h' | 's' | 'o';
    /**
     * Stream type - 'v' = VOD, 'l' = live.
     */
    st?: 'v' | 'l';
    /**
     * Version - CMCD version (default is 1).
     */
    v?: number;
    /**
     * Requested maximum throughput - The requested maximum throughput (kbps).
     */
    rtp?: number;
};
/**
 * Formats CMCD data into HTTP headers according to CTA-5004 specification.
 * Returns headers in the four standard CMCD header format:
 * - CMCD-Object: Object-related keys (br, d, ot, tb)
 * - CMCD-Request: Request-related keys (bl, dl, mtp, nor, nrr, su)
 * - CMCD-Session: Session-related keys (cid, pr, sf, sid, st, v)
 * - CMCD-Status: Status-related keys (bs, rtp)
 *
 * @param data The CMCD data to format
 * @returns Record of header name to header value
 */
export declare function formatCmcdHeaders(data: CmcdData): Record<string, string>;
/**
 * Generates a random session ID suitable for CMCD.
 * Returns a UUID v4 format string.
 *
 * @returns A unique session identifier string
 */
export declare function generateSessionId(): string;
/**
 * API for controlling the local HTTP proxy used for dynamic header injection.
 * The proxy intercepts video segment requests and adds custom headers.
 */
export declare const CMCDProxy: {
    /**
     * Starts the local HTTP proxy server.
     * This method is async and resolves when the proxy is ready to accept connections.
     *
     * @returns Promise that resolves when the proxy is running
     * @platform android
     * @platform ios
     */
    start(): Promise<void>;
    /**
     * Stops the local HTTP proxy server.
     *
     * @platform android
     * @platform ios
     */
    stop(): void;
    /**
     * Checks if the proxy server is currently running.
     *
     * @returns true if the proxy is running and accepting connections
     * @platform android
     * @platform ios
     */
    isRunning(): boolean;
    /**
     * Gets the port number the proxy is listening on.
     *
     * @returns The port number, or 0 if the proxy is not running
     * @platform android
     * @platform ios
     */
    getPort(): number;
    /**
     * Gets the base URL for the proxy server.
     *
     * @returns The base URL (e.g., "http://127.0.0.1:8080") or null if not running
     * @platform android
     * @platform ios
     */
    getBaseUrl(): string | null;
    /**
     * Creates a proxy URL for the given original URL.
     * The proxy URL will route through the local proxy server.
     *
     * @param originalUrl The original video URL to proxy
     * @returns The proxy URL, or null if the proxy is not running
     * @platform android
     * @platform ios
     */
    createProxyUrl(originalUrl: string): string | null;
    /**
     * Sets static headers that will be added to all proxied requests.
     * These headers are in addition to any dynamic headers set on the VideoPlayer.
     *
     * @param headers Record of header names to values
     * @platform android
     * @platform ios
     */
    setStaticHeaders(headers: Record<string, string>): void;
};
//# sourceMappingURL=CMCDProxy.d.ts.map