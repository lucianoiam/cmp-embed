// SPDX-FileCopyrightText: 2026 Luciano Iam <oss@lucianoiam.com>
// SPDX-License-Identifier: MIT

package juce_cmp.events

import java.io.OutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Sends JuceValueTree messages from UI to host over stdout (UI → host direction).
 *
 * Protocol: 4-byte size (little-endian) followed by ValueTree binary data.
 * The C++ EventReceiver reads these messages on the host side.
 *
 * Thread-safe: uses synchronized writes.
 *
 * Note: The output stream is set by Library.init() which must be called
 * as the very first thing in main().
 */
object EventSender {
    private var output: OutputStream? = null
    private val lock = Any()

    /** Called by Library.init() to set the output stream. */
    internal fun setOutput(stream: OutputStream) {
        output = stream
    }

    /**
     * Send a JuceValueTree to the host.
     *
     * Protocol: 4-byte size (little-endian) followed by tree bytes.
     */
    fun send(tree: JuceValueTree) {
        val stream = output ?: return

        val treeBytes = tree.toByteArray()
        val header = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN)
        header.putInt(treeBytes.size)

        synchronized(lock) {
            stream.write(header.array())
            stream.write(treeBytes)
            stream.flush()
        }
    }
}
