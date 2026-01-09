// SPDX-FileCopyrightText: 2026 Luciano Iam <oss@lucianoiam.com>
// SPDX-License-Identifier: MIT

package juce_cmp

import juce.ValueTree
import java.io.FileDescriptor
import java.io.FileOutputStream
import java.io.OutputStream
import java.io.PrintStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Sends binary messages from UI to host over stdout.
 *
 * The JVM and libraries (Compose, JNA, etc.) write text to System.out.
 * To prevent this from corrupting our binary protocol, we:
 * 1. Capture the raw stdout file descriptor (fd 1) FIRST, before any library loads
 * 2. Redirect System.out to System.err so library noise goes to stderr
 * 3. Use the captured raw fd for binary IPC
 *
 * This must be initialized as early as possible in main(), before any
 * other code runs that might write to stdout.
 *
 * Thread-safe: uses synchronized writes.
 */
object UISender {
    private var output: OutputStream? = null
    private val lock = Any()
    private var initialized = false
    
    /**
     * Initialize stdout capture for binary IPC.
     * 
     * MUST be called as the very first thing in main(), before any
     * library initialization or other code that might print to stdout.
     * 
     * After this call:
     * - System.out is redirected to stderr (library output goes there)
     * - Binary messages go to the original stdout (fd 1)
     */
    fun initialize() {
        if (initialized) return
        initialized = true
        
        // Capture the raw stdout before anyone else can pollute it
        // FileDescriptor.out is the JVM's reference to fd 1
        output = FileOutputStream(FileDescriptor.out)
        
        // Redirect System.out to stderr so library noise doesn't corrupt our protocol
        // All println(), library warnings, etc. will now go to stderr
        System.setOut(PrintStream(FileOutputStream(FileDescriptor.err), true))
    }
    
    /**
     * Send a ValueTree to the host.
     * 
     * Protocol: 4-byte size (little-endian) followed by tree bytes.
     */
    fun send(tree: ValueTree) {
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
