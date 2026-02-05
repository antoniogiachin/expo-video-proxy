package expo.modules.video.player

import android.net.Uri
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.HttpDataSource
import androidx.media3.datasource.TransferListener
import java.lang.ref.WeakReference

/**
 * A DataSource wrapper that injects dynamic headers from the VideoPlayer
 * into each HTTP request at open() time.
 *
 * This allows headers to be truly dynamic - they are fetched fresh for each segment request.
 */
@OptIn(UnstableApi::class)
class DynamicHeadersDataSource(
  private val wrapped: HttpDataSource,
  private val playerRef: WeakReference<VideoPlayer>
) : DataSource {

  override fun addTransferListener(transferListener: TransferListener) {
    wrapped.addTransferListener(transferListener)
  }

  override fun open(dataSpec: DataSpec): Long {
    // Get current dynamic headers from player and add them to this request
    playerRef.get()?.dynamicRequestHeaders?.forEach { (key, value) ->
      wrapped.setRequestProperty(key, value)
    }
    return wrapped.open(dataSpec)
  }

  override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
    return wrapped.read(buffer, offset, length)
  }

  override fun getUri(): Uri? {
    return wrapped.uri
  }

  override fun getResponseHeaders(): Map<String, List<String>> {
    return wrapped.responseHeaders
  }

  override fun close() {
    wrapped.close()
  }

  /**
   * Factory for creating DynamicHeadersDataSource instances.
   */
  class Factory(
    private val wrappedFactory: HttpDataSource.Factory,
    private val playerRef: WeakReference<VideoPlayer>
  ) : DataSource.Factory {

    override fun createDataSource(): DataSource {
      val wrapped = wrappedFactory.createDataSource()
      return DynamicHeadersDataSource(wrapped, playerRef)
    }
  }
}
