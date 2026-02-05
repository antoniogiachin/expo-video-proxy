package expo.modules.video.player

import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.HttpDataSource
import java.lang.ref.WeakReference

/**
 * A DataSource.Factory that wraps DefaultHttpDataSource and injects dynamic headers
 * from the VideoPlayer into each HTTP request.
 *
 * This allows headers to be updated at any time during playback without reloading the source.
 */
@OptIn(UnstableApi::class)
class DynamicHeadersDataSourceFactory(
  private val playerRef: WeakReference<VideoPlayer>,
  private val baseHeaders: Map<String, String>? = null
) : HttpDataSource.Factory {

  private val defaultFactory = DefaultHttpDataSource.Factory()
    .setConnectTimeoutMs(DefaultHttpDataSource.DEFAULT_CONNECT_TIMEOUT_MILLIS)
    .setReadTimeoutMs(DefaultHttpDataSource.DEFAULT_READ_TIMEOUT_MILLIS)
    .setAllowCrossProtocolRedirects(true)

  override fun createDataSource(): HttpDataSource {
    val dataSource = defaultFactory.createDataSource()

    // Combine base headers with dynamic headers from player
    val allHeaders = mutableMapOf<String, String>()

    // Add base headers (from VideoSource.headers)
    baseHeaders?.let { allHeaders.putAll(it) }

    // Add dynamic headers from player
    playerRef.get()?.dynamicRequestHeaders?.let { allHeaders.putAll(it) }

    // Set all headers on the data source
    if (allHeaders.isNotEmpty()) {
      dataSource.setRequestProperty("User-Agent", System.getProperty("http.agent") ?: "ExoPlayer")
      allHeaders.forEach { (key, value) ->
        dataSource.setRequestProperty(key, value)
      }
    }

    return dataSource
  }

  override fun setDefaultRequestProperties(defaultRequestProperties: MutableMap<String, String>): HttpDataSource.Factory {
    defaultFactory.setDefaultRequestProperties(defaultRequestProperties)
    return this
  }
}
