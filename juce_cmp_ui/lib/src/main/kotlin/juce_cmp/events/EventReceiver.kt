// SPDX-FileCopyrightText: 2026 Luciano Iam <oss@lucianoiam.com>
// SPDX-License-Identifier: MIT

package juce_cmp.events

import java.io.InputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import juce_cmp.input.InputEvent
import juce_cmp.input.EventType

/**
 * Receives binary events from the host process via stdin pipe.
 *
 * IPC Protocol: 16-byte fixed-size events (see juce_cmp/ipc_protocol.h).
 * GENERIC events (type 5) are followed by variable-length JuceValueTree payload.
 * This runs on a background thread and delivers events via callback.
 *
 * Note: This is the Kotlin-side EventReceiver (host → UI direction).
 * The C++ EventReceiver in juce_cmp handles the opposite direction (UI → host).
 */
class EventReceiver(
    private val input: InputStream = System.`in`,
    private val onInputEvent: (InputEvent) -> Unit,
    private val onJuceEvent: ((JuceValueTree) -> Unit)? = null
) {
    @Volatile
    private var running = false
    private var thread: Thread? = null

    /** Returns true if the receiver is still running (stdin not closed) */
    val isRunning: Boolean get() = running

    fun start() {
        if (running) return
        running = true
        thread = Thread({
            val buffer = ByteArray(16)
            val byteBuffer = ByteBuffer.wrap(buffer).order(ByteOrder.LITTLE_ENDIAN)

            while (running) {
                try {
                    // Read exactly 16 bytes (one event header)
                    var bytesRead = 0
                    while (bytesRead < 16 && running) {
                        val n = input.read(buffer, bytesRead, 16 - bytesRead)
                        if (n < 0) {
                            // EOF - parent closed pipe, exit immediately
                            running = false
                            // Force JVM exit - other threads may keep it alive
                            kotlin.system.exitProcess(0)
                        }
                        bytesRead += n
                    }

                    if (bytesRead == 16) {
                        byteBuffer.rewind()
                        val event = InputEvent(
                            type = byteBuffer.get().toInt() and 0xFF,
                            action = byteBuffer.get().toInt() and 0xFF,
                            button = byteBuffer.get().toInt() and 0xFF,
                            modifiers = byteBuffer.get().toInt() and 0xFF,
                            x = byteBuffer.short.toInt(),
                            y = byteBuffer.short.toInt(),
                            data1 = byteBuffer.short.toInt(),
                            data2 = byteBuffer.short.toInt(),
                            timestamp = byteBuffer.int.toLong() and 0xFFFFFFFFL
                        )

                        if (event.type == EventType.GENERIC && onJuceEvent != null) {
                            // Read variable-length payload
                            val payloadLength = event.payloadLength
                            if (payloadLength > 0) {
                                val payload = ByteArray(payloadLength)
                                var payloadRead = 0
                                while (payloadRead < payloadLength && running) {
                                    val n = input.read(payload, payloadRead, payloadLength - payloadRead)
                                    if (n < 0) {
                                        running = false
                                        kotlin.system.exitProcess(0)
                                    }
                                    payloadRead += n
                                }

                                if (payloadRead == payloadLength) {
                                    // Parse JuceValueTree from payload
                                    val tree = JuceValueTree.fromByteArray(payload)
                                    onJuceEvent.invoke(tree)
                                }
                            }
                        } else {
                            onInputEvent(event)
                        }
                    }
                } catch (e: Exception) {
                    if (running) {
                        System.err.println("[Input] Error reading event: ${e.message}")
                    }
                }
            }
        }, "EventReceiver")
        thread?.isDaemon = true
        thread?.start()
    }

    fun stop() {
        running = false
        thread?.interrupt()
        thread = null
    }
}
